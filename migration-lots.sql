-- =====================================================================
-- Lots et « Marquer réservé »
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
--
-- 1. Réservé hors boutique : un acheteur a pris rendez-vous ailleurs
--    (Marketplace, DBA…). Le meuble quitte la boutique ; ensuite le
--    vendeur note « Vendu », ou annule la réservation si l'acheteur se
--    rétracte et le meuble revient dans la boutique.
-- 2. Lots : plusieurs meubles déjà en vente, vendus ensemble avec une
--    remise (lit 400 kr + matelas 300 kr, −20 % : 560 kr). Les meubles
--    restent aussi en vente un par un ; le lot quitte la boutique dès que
--    l'un d'eux est réservé ou vendu.
--
-- À lancer APRÈS migration-reservation.sql et migration-panier.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Réservé hors boutique
-- ---------------------------------------------------------------------

-- Combien d'exemplaires sont promis ailleurs (0 ou 1 pour un meuble seul).
alter table public.items
  add column if not exists reserved_qty int not null default 0;

alter table public.items drop constraint if exists items_reserved_qty_check;
alter table public.items
  add constraint items_reserved_qty_check check (reserved_qty between 0 and 20);


-- ---------------------------------------------------------------------
-- 2. Lots
-- ---------------------------------------------------------------------
-- items : les meubles du lot et combien de chacun,
--         [{ "id": …, "count": 1 }, { "id": …, "count": 2 }].
-- discount : la remise en %, sur la somme des prix affichés.
create table if not exists public.bundles (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title      text not null check (char_length(btrim(title)) between 1 and 160),
  items      jsonb not null default '[]'::jsonb
             check (case when jsonb_typeof(items) = 'array'
                         then jsonb_array_length(items) between 1 and 12
                         else false end),
  discount   int not null default 0 check (discount between 0 and 90)
);

-- Tout le monde voit les lots, seul le compte vendeur connecté les change.
alter table public.bundles enable row level security;

drop policy if exists "lots visibles par tous" on public.bundles;
create policy "lots visibles par tous" on public.bundles
  for select to anon, authenticated using (true);

drop policy if exists "lots gérés par le vendeur" on public.bundles;
create policy "lots gérés par le vendeur" on public.bundles
  for all to authenticated using (true) with check (true);

grant select on public.bundles to anon, authenticated;
grant insert, update, delete on public.bundles to authenticated;


-- Un rendez-vous pris pour un lot : chaque meuble garde sa ligne (reliées
-- par cart_id), avec le lot et sa remise recopiés tels qu'ils étaient. Le
-- vendeur retrouve ainsi le prix du lot même s'il le modifie ou le
-- supprime ensuite.
alter table public.bookings
  add column if not exists bundle_id uuid;
alter table public.bookings
  add column if not exists bundle_title text;
alter table public.bookings
  add column if not exists bundle_discount int;

-- L'acheteur n'envoie que le numéro du lot : le titre et la remise sont
-- lus dans la base (fill_booking_bundle), personne ne peut s'inventer
-- une remise.
grant insert (bundle_id) on public.bookings to anon, authenticated;

create or replace function public.fill_booking_bundle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bu public.bundles;
begin
  new.bundle_title := null;
  new.bundle_discount := null;

  if new.bundle_id is null then
    return new;
  end if;

  select * into bu from bundles where id = new.bundle_id;

  -- Lot supprimé entre-temps, ou meuble qui n'en fait pas partie.
  if not found or not exists (
       select 1 from jsonb_array_elements(bu.items) e
        where e ->> 'id' = new.item_id::text) then
    raise exception 'bundle_gone' using hint = 'Ce lot n''existe plus.';
  end if;

  new.bundle_title := bu.title;
  new.bundle_discount := bu.discount;
  return new;
end;
$$;

drop trigger if exists fill_booking_bundle on public.bookings;
create trigger fill_booking_bundle
  before insert on public.bookings
  for each row execute function public.fill_booking_bundle();


-- ---------------------------------------------------------------------
-- La vérification « meuble encore libre » (migration-reservation.sql)
-- compte maintenant aussi les exemplaires réservés hors boutique.
-- ---------------------------------------------------------------------
create or replace function public.check_item_free()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it       jsonb;
  total    int;
  sold     int;
  held     int;
  reserved int;
  wanted   int := coalesce((to_jsonb(new) ->> 'quantity')::int, 1);
begin
  -- Un rendez-vous commence toujours sans résultat.
  new.outcome := null;
  new.sale_price := null;

  if new.item_id is null then
    return new;
  end if;

  -- Verrouille le meuble : deux réservations simultanées passent l'une
  -- après l'autre, la seconde voit la première.
  select to_jsonb(i) into it
    from items i
   where i.id::text = new.item_id::text
     for update;

  if it is null then
    return new;
  end if;

  total    := greatest(1, coalesce((it ->> 'quantity')::int, 1));
  sold     := case when it ->> 'status' = 'sold' then total
                   else least(total, coalesce((it ->> 'sold_qty')::int, 0)) end;
  reserved := greatest(0, coalesce((it ->> 'reserved_qty')::int, 0));

  select coalesce(sum(coalesce((to_jsonb(b) ->> 'quantity')::int, 1)), 0) into held
    from bookings b
   where b.item_id::text = new.item_id::text
     and coalesce(b.status, '') <> 'declined'
     and b.outcome is null;

  if wanted > total - sold - held - reserved then
    raise exception 'item_taken' using hint = 'Ce meuble est déjà réservé ou vendu.';
  end if;

  return new;
end;
$$;

-- Le site voit tout de suite les nouvelles colonnes et la nouvelle table.
notify pgrst, 'reload schema';
