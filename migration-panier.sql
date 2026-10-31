-- =====================================================================
-- Panier et demandes de contact
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
--
-- 1. Panier : l'acheteur met plusieurs meubles de côté puis prend UN
--    rendez-vous pour tous. Chaque meuble garde sa propre ligne dans
--    bookings (vendu / invendu se notent meuble par meuble), reliées par
--    le même cart_id et le même créneau.
-- 2. Contact : l'acheteur laisse son prénom, son numéro et un message
--    (sur un meuble, sur son panier ou en général) pour être rappelé.
--    Rien n'est réservé. Seul le compte vendeur connecté les lit.
--
-- À lancer APRÈS migration-reservation.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Plusieurs meubles au même rendez-vous
-- ---------------------------------------------------------------------

-- Les lignes d'un même panier partagent ce numéro (vide pour un meuble
-- réservé seul).
alter table public.bookings
  add column if not exists cart_id uuid;

create index if not exists bookings_cart_id_idx on public.bookings (cart_id);

-- Les acheteurs réservent sans compte : ils doivent pouvoir le remplir.
grant insert (cart_id) on public.bookings to anon, authenticated;


-- Un créneau ne reçoit toujours qu'un seul acheteur. Jusqu'ici c'était un
-- index unique sur (day, slot), qui refuserait aussi les autres meubles
-- du même panier. On le remplace par une vérification qui laisse passer
-- les lignes d'un même panier et refuse tout le reste, avec le même code
-- d'erreur (23505) : le site dit toujours « quelqu'un vient de prendre ce
-- créneau ».
do $$
declare
  r record;
begin
  for r in
    select i.indexrelid::regclass as idx, c.conname
      from pg_index i
      left join pg_constraint c on c.conindid = i.indexrelid and c.conrelid = i.indrelid
     where i.indrelid = 'public.bookings'::regclass
       and i.indisunique
       and not i.indisprimary
       and i.indexprs is null
       and (select array_agg(a.attname::text order by a.attname::text)
              from unnest(i.indkey) k
              join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k)
           = array['day', 'slot']
  loop
    if r.conname is not null then
      execute format('alter table public.bookings drop constraint %I', r.conname);
    else
      execute format('drop index %s', r.idx);
    end if;
  end loop;
end $$;

create or replace function public.check_slot_free()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.day is null or new.slot is null then
    return new;
  end if;

  -- Un refus libère le créneau ; une modification qui ne touche ni le
  -- statut ni l'heure ne change rien.
  if tg_op = 'UPDATE' and (
       coalesce(new.status, '') = 'declined'
       or (new.day = old.day and new.slot = old.slot
           and coalesce(old.status, '') <> 'declined')) then
    return new;
  end if;

  -- Deux acheteurs sur le même créneau à la même seconde passent l'un
  -- après l'autre : le second voit le premier.
  perform pg_advisory_xact_lock(hashtext('meubles creneau ' || new.day::text || ' ' || new.slot::text));

  if exists (
    select 1
      from bookings b
     where b.day = new.day
       and b.slot = new.slot
       and b.id is distinct from new.id
       and coalesce(b.status, '') <> 'declined'
       and (new.cart_id is null or b.cart_id is distinct from new.cart_id)
  ) then
    raise exception 'slot_taken'
      using errcode = 'unique_violation', hint = 'Ce créneau est déjà pris.';
  end if;

  return new;
end;
$$;

drop trigger if exists check_slot_free on public.bookings;
create trigger check_slot_free
  before insert or update of status, day, slot on public.bookings
  for each row execute function public.check_slot_free();


-- ---------------------------------------------------------------------
-- 2. Demandes de contact (« rappelez-moi »)
-- ---------------------------------------------------------------------
-- items : les meubles dont parle l'acheteur, recopiés tels qu'ils étaient
-- (titre, prix, nombre) : [{ "id", "title", "price", "quantity" }].
-- status : 'new' à l'arrivée, 'seen' une fois lu, 'done' une fois traité.
create table if not exists public.contact_requests (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  first_name text not null check (char_length(btrim(first_name)) between 1 and 60),
  phone      text not null check (char_length(phone) between 4 and 30),
  message    text check (char_length(message) <= 1000),
  items      jsonb not null default '[]'::jsonb
             check (case when jsonb_typeof(items) = 'array'
                         then jsonb_array_length(items) <= 30 and octet_length(items::text) <= 8000
                         else false end),
  status     text not null default 'new' check (status in ('new', 'seen', 'done'))
);

create index if not exists contact_requests_created_at_idx on public.contact_requests (created_at desc);

-- Les acheteurs (sans compte) peuvent seulement en envoyer ; seul le
-- compte vendeur connecté peut les lire, les marquer et les effacer.
alter table public.contact_requests enable row level security;

drop policy if exists "messages envoyés par tous" on public.contact_requests;
create policy "messages envoyés par tous" on public.contact_requests
  for insert to anon, authenticated with check (status = 'new');

drop policy if exists "messages lus par le vendeur" on public.contact_requests;
create policy "messages lus par le vendeur" on public.contact_requests
  for select to authenticated using (true);

drop policy if exists "messages marqués par le vendeur" on public.contact_requests;
create policy "messages marqués par le vendeur" on public.contact_requests
  for update to authenticated using (true) with check (true);

drop policy if exists "messages effacés par le vendeur" on public.contact_requests;
create policy "messages effacés par le vendeur" on public.contact_requests
  for delete to authenticated using (true);

revoke all on public.contact_requests from anon, authenticated;
grant insert (first_name, phone, message, items) on public.contact_requests to anon, authenticated;
grant select, delete on public.contact_requests to authenticated;
grant update (status) on public.contact_requests to authenticated;

-- Alerte en direct dans l'espace vendeur ouvert, comme pour les rendez-vous.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime'
                        and schemaname = 'public' and tablename = 'contact_requests') then
    alter publication supabase_realtime add table public.contact_requests;
  end if;
end $$;

-- Le site voit tout de suite la nouvelle colonne et la nouvelle table.
notify pgrst, 'reload schema';
