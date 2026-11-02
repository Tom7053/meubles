-- =====================================================================
-- Autres sites : la liste des boutons « + Facebook Marketplace »,
-- « + DBA »… sous « Liens vers les autres sites » d'une annonce,
-- modifiable dans l'onglet Réglages.
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque (ta liste reste comme elle est).
-- =====================================================================

-- On part de la liste d'avant ; tu ajoutes ou retires ensuite les sites
-- dans Réglages.
alter table public.settings
  add column if not exists link_sites text[] not null
  default array['Facebook Marketplace', 'DBA', 'Leboncoin', 'Vinted'];

-- Le site voit tout de suite la nouvelle colonne.
notify pgrst, 'reload schema';
