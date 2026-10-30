-- =====================================================================
-- Prix de vente réel (après négociation)
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
-- =====================================================================

-- Un prix en couronnes par exemplaire vendu, dans l'ordre des ventes
-- (ex. [400] pour un bureau affiché 450 kr et vendu 400, [350, 350] pour
-- deux lits). Un exemplaire vendu sans prix noté compte au prix affiché.
alter table public.items
  add column if not exists sale_prices jsonb not null default '[]'::jsonb;

alter table public.items drop constraint if exists items_sale_prices_check;
alter table public.items
  add constraint items_sale_prices_check check (jsonb_typeof(sale_prices) = 'array');

-- Le site voit tout de suite la nouvelle colonne.
notify pgrst, 'reload schema';
