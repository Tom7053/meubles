-- =====================================================================
-- Langues : boutique et espace vendeur (onglet Réglages)
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- On peut le relancer sans risque.
-- =====================================================================

-- La langue de la boutique, celle que lisent tous les acheteurs :
-- 'en' (anglais, comme avant) ou 'fr' (français).
alter table public.settings
  add column if not exists shop_lang text not null default 'en';

-- La langue de l'espace vendeur : 'fr' (comme avant) ou 'en'. Gardée ici
-- pour te suivre sur ton téléphone comme sur ton ordinateur.
alter table public.settings
  add column if not exists admin_lang text not null default 'fr';

alter table public.settings drop constraint if exists settings_shop_lang_check;
alter table public.settings
  add constraint settings_shop_lang_check check (shop_lang in ('en', 'fr'));

alter table public.settings drop constraint if exists settings_admin_lang_check;
alter table public.settings
  add constraint settings_admin_lang_check check (admin_lang in ('en', 'fr'));

-- Le site voit tout de suite les nouvelles colonnes.
notify pgrst, 'reload schema';
