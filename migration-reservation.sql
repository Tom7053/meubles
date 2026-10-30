-- =====================================================================
-- Un meuble réservé quitte la boutique
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
--
-- Dès qu'un acheteur prend rendez-vous pour un meuble, celui-ci
-- disparaît de la boutique : personne d'autre ne peut le réserver. Après
-- le rendez-vous, le vendeur note dans l'onglet Rendez-vous :
--   « Vendu »   → la vente est comptée, le meuble reste retiré ;
--   « Invendu » → le meuble réapparaît dans la boutique.
-- Refuser ou supprimer le rendez-vous le remet aussi en vente.
-- Pour un meuble en plusieurs exemplaires, seuls ceux réservés sont
-- retirés (2 lits, 1 réservé : il en reste 1 dans la boutique).
-- =====================================================================

-- Ce que le vendeur a noté après le rendez-vous : 'sold', 'unsold', ou
-- rien tant que ce n'est pas fait (le meuble reste alors retenu).
alter table public.bookings
  add column if not exists outcome text;

alter table public.bookings drop constraint if exists bookings_outcome_check;
alter table public.bookings
  add constraint bookings_outcome_check
  check (outcome is null or outcome in ('sold', 'unsold'));

-- Montant encaissé à ce rendez-vous, en kr (tous exemplaires compris).
alter table public.bookings
  add column if not exists sale_price numeric;

-- Seul le compte vendeur connecté note vendu / invendu.
grant update (outcome, sale_price) on public.bookings to authenticated;


-- ---------------------------------------------------------------------
-- Exemplaires retenus par un rendez-vous en cours, par meuble.
-- Les acheteurs ne peuvent pas lire les rendez-vous (prénoms, numéros) :
-- cette vue ne leur donne que ces totaux, comme busy_slots pour les
-- créneaux. to_jsonb(b) marche même avant migration-quantite.sql.
-- ---------------------------------------------------------------------
create or replace view public.booked_items as
  select b.item_id,
         sum(coalesce((to_jsonb(b) ->> 'quantity')::int, 1))::int as qty
    from public.bookings b
   where b.item_id is not null
     and coalesce(b.status, '') <> 'declined'
     and b.outcome is null
   group by b.item_id;

grant select on public.booked_items to anon, authenticated;


-- ---------------------------------------------------------------------
-- Deux acheteurs qui réservent le même meuble à la même seconde : le
-- second est refusé (le site lui dit que quelqu'un vient de le prendre).
-- ---------------------------------------------------------------------
create or replace function public.check_item_free()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it     jsonb;
  total  int;
  sold   int;
  held   int;
  wanted int := coalesce((to_jsonb(new) ->> 'quantity')::int, 1);
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

  total := greatest(1, coalesce((it ->> 'quantity')::int, 1));
  sold  := case when it ->> 'status' = 'sold' then total
                else least(total, coalesce((it ->> 'sold_qty')::int, 0)) end;

  select coalesce(sum(coalesce((to_jsonb(b) ->> 'quantity')::int, 1)), 0) into held
    from bookings b
   where b.item_id::text = new.item_id::text
     and coalesce(b.status, '') <> 'declined'
     and b.outcome is null;

  if wanted > total - sold - held then
    raise exception 'item_taken' using hint = 'Ce meuble est déjà réservé ou vendu.';
  end if;

  return new;
end;
$$;

drop trigger if exists check_item_free on public.bookings;
create trigger check_item_free
  before insert on public.bookings
  for each row execute function public.check_item_free();

-- Le site voit tout de suite les nouvelles colonnes et la vue.
notify pgrst, 'reload schema';
