-- =====================================================================
-- Statistiques : visites du site, scans du QR code, meubles les plus vus
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
-- =====================================================================

-- Une ligne par visite de la boutique et par meuble regardé. Rien de
-- personnel : `session` est un numéro tiré au hasard, oublié quand le
-- visiteur ferme l'onglet ; `source` est le site d'où il vient
-- (facebook.com…), `mobile` s'il est sur téléphone. `qr` est une
-- estimation : arrivé sur téléphone, sans lien d'origine, sur l'adresse
-- exacte imprimée sur l'affiche.
--
-- item_id prend le même type que items.id (uuid ou nombre selon comment
-- la table a été créée), d'où le bloc « do ».
do $$
declare
  id_type text;
begin
  select format_type(a.atttypid, a.atttypmod) into id_type
    from pg_attribute a
   where a.attrelid = 'public.items'::regclass and a.attname = 'id';

  execute format($sql$
    create table if not exists public.visits (
      id         uuid primary key default gen_random_uuid(),
      created_at timestamptz not null default now(),
      kind       text not null check (kind in ('visit', 'item_seen', 'item_photos', 'item_book')),
      session    text not null check (char_length(session) between 8 and 40),
      item_id    %s references public.items (id) on delete cascade,
      source     text check (char_length(source) <= 80),
      qr         boolean,
      mobile     boolean
    )$sql$, id_type);
end $$;

create index if not exists visits_item_id_idx on public.visits (item_id);

-- Les visiteurs (sans compte) peuvent seulement ajouter des lignes ; seul
-- le compte vendeur connecté peut les lire, et les effacer : quand le
-- vendeur se connecte, le site efface sa propre visite de la boutique.
alter table public.visits enable row level security;

drop policy if exists "visites ajoutées par tous" on public.visits;
create policy "visites ajoutées par tous" on public.visits
  for insert to anon, authenticated with check (true);

drop policy if exists "visites lues par le vendeur" on public.visits;
create policy "visites lues par le vendeur" on public.visits
  for select to authenticated using (true);

drop policy if exists "visites effacées par le vendeur" on public.visits;
create policy "visites effacées par le vendeur" on public.visits
  for delete to authenticated using (true);

grant insert on public.visits to anon, authenticated;
grant select, delete on public.visits to authenticated;

-- Les totaux, calculés dans la base (le site ne reçoit pas les lignes une
-- par une). Jours à l'heure du Danemark.
create or replace function public.seller_stats()
returns json
language sql
stable
security invoker
set search_path = public
as $$
  with v as (
    select *, (created_at at time zone 'Europe/Copenhagen')::date = (now() at time zone 'Europe/Copenhagen')::date as today
      from visits
     where kind = 'visit'
  )
  select json_build_object(
    'since',        (select min(created_at) from visits),
    'visits',       (select count(*) from v),
    'visits_today', (select count(*) from v where today),
    'qr',           (select count(*) from v where qr),
    'qr_today',     (select count(*) from v where qr and today),
    -- d'où viennent les visites : 'qr', un site (facebook.com…), ou
    -- 'phone' / 'computer' quand il n'y a pas de lien d'origine
    'sources', (select coalesce(json_agg(s order by s.n desc), '[]'::json) from (
                  select case when qr then 'qr'
                              when source is not null then source
                              when mobile then 'phone'
                              else 'computer' end as source,
                         count(*) as n
                    from v
                   group by 1) s),
    -- par meuble : affiché à l'écran, et visiteurs qui ont ouvert ses
    -- photos ou commencé une réservation
    'items', (select coalesce(json_agg(i), '[]'::json) from (
                select item_id,
                       count(*) filter (where kind = 'item_seen') as seen,
                       count(distinct session) filter (where kind in ('item_photos', 'item_book')) as interested
                  from visits
                 where item_id is not null
                 group by item_id) i)
  );
$$;

revoke all on function public.seller_stats() from public, anon;
grant execute on function public.seller_stats() to authenticated;

-- Le site voit tout de suite la nouvelle table et la fonction.
notify pgrst, 'reload schema';
