-- =====================================================================
-- Plusieurs photos par meuble, et choix de la description gardés
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
-- =====================================================================

-- La première photo (la couverture) reste dans items.image : c'est la
-- seule qui vient avec la liste. Les autres sont rangées à part et ne se
-- chargent que quand un acheteur ouvre la galerie de ce meuble, sinon un
-- téléphone devrait télécharger toutes les photos de tous les meubles.
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
    create table if not exists public.item_photos (
      item_id     %s primary key references public.items (id) on delete cascade,
      photos      jsonb not null default '[]'::jsonb,
      -- Lu par la boutique pour afficher « 4 photos » sans tout charger.
      photo_count int generated always as (jsonb_array_length(photos)) stored
    )$sql$, id_type);
end $$;

-- Tout le monde voit les photos, seul le compte vendeur connecté les change.
alter table public.item_photos enable row level security;

drop policy if exists "photos visibles par tous" on public.item_photos;
create policy "photos visibles par tous" on public.item_photos
  for select to anon, authenticated using (true);

drop policy if exists "photos gérées par le vendeur" on public.item_photos;
create policy "photos gérées par le vendeur" on public.item_photos
  for all to authenticated using (true) with check (true);

grant select on public.item_photos to anon, authenticated;
grant insert, update, delete on public.item_photos to authenticated;

-- Ce qui a été coché pour écrire la description (type, matière, défauts…),
-- pour le retrouver en rouvrant l'annonce.
alter table public.items
  add column if not exists details jsonb;

-- Le site voit tout de suite la nouvelle table et la nouvelle colonne.
notify pgrst, 'reload schema';
