-- =====================================================================
-- Plusieurs exemplaires d'un même meuble (ex. 2 lits identiques)
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
-- =====================================================================

-- Combien d'exemplaires sont mis en vente, et combien sont déjà partis.
-- Le meuble disparaît de la boutique quand tout est vendu.
alter table public.items
  add column if not exists quantity int not null default 1;
alter table public.items
  add column if not exists sold_qty int not null default 0;

alter table public.items drop constraint if exists items_quantity_check;
alter table public.items
  add constraint items_quantity_check
  check (quantity >= 1 and sold_qty >= 0 and sold_qty <= quantity);

-- Combien d'exemplaires l'acheteur veut prendre à ce rendez-vous.
alter table public.bookings
  add column if not exists quantity int not null default 1;

alter table public.bookings drop constraint if exists bookings_quantity_check;
alter table public.bookings
  add constraint bookings_quantity_check
  check (quantity between 1 and 20);

-- Les acheteurs réservent sans compte : ils doivent pouvoir remplir la
-- nouvelle colonne. Sans effet si c'était déjà permis.
grant insert (quantity) on public.bookings to anon, authenticated;
