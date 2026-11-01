-- =====================================================================
--  VÉRIFIER CE QUI EST INSTALLÉ DANS SUPABASE
--  SQL Editor → New query → coller tout → Run.
--  Ne modifie rien : ça lit seulement. Chaque ligne dit OK, ou quoi lancer.
-- =====================================================================
with f as (
  select
    pg_get_functiondef(to_regprocedure('public.notify_send_push(text,text,text)')) as push_def,
    pg_get_functiondef(to_regprocedure('public.notify_send_resend(text,text)'))    as resend_def,
    pg_get_functiondef(to_regprocedure('public.notify_send_brevo(text,text)'))     as brevo_def,
    to_regprocedure('public.booking_alert(jsonb)') is not null                     as notif_new,
    (select p.proname::text
       from pg_trigger t join pg_proc p on p.oid = t.tgfoid
      where t.tgname = 'on_new_booking_email'
        and t.tgrelid = 'public.bookings'::regclass)                                as email_fn,
    exists (select 1 from pg_trigger
             where tgname = 'on_new_booking_push'
               and tgrelid = 'public.bookings'::regclass)                           as push_on,
    exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
             where t.tgname = 'on_new_contact_push'
               and c.relname = 'contact_requests')                                  as push_msg_on,
    exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
             where t.tgname = 'on_new_contact_email'
               and c.relname = 'contact_requests')                                  as email_msg_on,
    exists (select 1 from vault.secrets where name = 'resend_key')                  as resend_key,
    exists (select 1 from vault.secrets where name = 'brevo_key')                   as brevo_key
)
select etape, etat
from f
cross join lateral (values
  (1, 'Paiement Cash / Revolut',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'bookings'
                           and column_name = 'payment')
           then 'OK' else 'MANQUE → lance migration-paiement.sql' end),

  (2, 'Plusieurs exemplaires',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'items'
                           and column_name = 'sold_qty')
           then 'OK' else 'MANQUE → lance migration-quantite.sql' end),

  (3, 'Plusieurs photos',
      case when to_regclass('public.item_photos') is not null
           then 'OK' else 'MANQUE → lance migration-photos.sql' end),

  (4, 'Onglet Stats',
      case when to_regprocedure('public.seller_stats()') is not null
           then 'OK' else 'MANQUE → lance migration-stats.sql' end),

  (5, 'Prix de vente négocié',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'items'
                           and column_name = 'sale_prices')
           then 'OK' else 'MANQUE → lance migration-prix-vente.sql' end),

  (6, 'Réservation (meuble retiré de la boutique)',
      case when to_regclass('public.booked_items') is not null
           then 'OK' else 'MANQUE → lance migration-reservation.sql' end),

  (7, 'Panier : colonne cart_id',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'bookings'
                           and column_name = 'cart_id')
           then 'OK' else 'MANQUE → lance migration-panier.sql' end),

  (8, 'Panier : plusieurs meubles au même créneau',
      case when exists (select 1 from pg_trigger
                         where tgname = 'check_slot_free'
                           and tgrelid = 'public.bookings'::regclass)
            and not exists (
                  select 1 from pg_index i
                   where i.indrelid = 'public.bookings'::regclass
                     and i.indisunique and not i.indisprimary and i.indexprs is null
                     and (select array_agg(a.attname::text order by a.attname::text)
                            from unnest(i.indkey) k
                            join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k)
                         = array['day', 'slot'])
           then 'OK' else 'MANQUE → lance migration-panier.sql' end),

  (9, 'Messages « Contact me »',
      case when to_regclass('public.contact_requests') is not null
           then 'OK' else 'MANQUE → lance migration-panier.sql' end),

  (10, 'Messages : alerte en direct dans l''onglet',
      case when exists (select 1 from pg_publication_tables
                         where pubname = 'supabase_realtime' and schemaname = 'public'
                           and tablename = 'contact_requests')
           then 'OK' else 'MANQUE → lance migration-panier.sql' end),

  (10.5, 'Langues (onglet Réglages)',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'settings'
                           and column_name = 'shop_lang')
            and exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'settings'
                           and column_name = 'admin_lang')
           -- lu par to_jsonb : la requête marche aussi avant la migration
           then 'OK — boutique : ' || coalesce((select to_jsonb(s) ->> 'shop_lang' from public.settings s where s.id = 1), '?')
                || ', espace vendeur : ' || coalesce((select to_jsonb(s) ->> 'admin_lang' from public.settings s where s.id = 1), '?')
           else 'MANQUE → lance migration-langue.sql' end),

  (10.6, 'Lots (plusieurs meubles avec une remise)',
      case when to_regclass('public.bundles') is not null
            and exists (select 1 from pg_trigger
                         where tgname = 'fill_booking_bundle'
                           and tgrelid = 'public.bookings'::regclass)
           then 'OK' else 'MANQUE → lance migration-lots.sql' end),

  (10.7, 'Marquer réservé (hors boutique)',
      case when exists (select 1 from information_schema.columns
                         where table_schema = 'public' and table_name = 'items'
                           and column_name = 'reserved_qty')
            and coalesce(pg_get_functiondef(to_regprocedure('public.check_item_free()')), '') like '%reserved_qty%'
           then 'OK' else 'MANQUE → lance migration-lots.sql' end),

  (11, 'Notif push (ntfy) : rendez-vous',
      case
        when not push_on then
          'pas activée (normal si tu n''utilises pas ntfy)'
        when push_def is null or not notif_new then
          'ANCIENNE VERSION → relance notifications.sql : étape commune + option A'
        when push_def like '%topic text := ''REMPLACE-%' then
          'SUJET PAS REMPLACÉ → rien n''est envoyé. Mets ton sujet dans l''option A puis relance étape commune + option A'
        else
          'OK — sujet : ' || coalesce(substring(push_def from 'topic text := ''([^'']*)'''), '?')
      end),

  (12, 'Notif push (ntfy) : messages',
      case
        when push_msg_on then 'OK'
        when push_on then 'MANQUE → lance migration-panier.sql, puis relance notifications.sql : étape commune + option A'
        else 'pas activée'
      end),

  (13, 'Notif e-mail : rendez-vous',
      case
        when email_fn is null then
          'pas activée (normal si tu n''utilises pas l''e-mail)'
        when email_fn = 'notify_booking_email' then
          'via Resend — ' || case
            when resend_def is null or not notif_new then 'ANCIENNE VERSION → relance étape commune + option B'
            when not resend_key then 'CLÉ RESEND ABSENTE du coffre → rien n''est envoyé'
            when resend_def like '%ton.adresse@example.com%' then 'ADRESSE PAS REMPLACÉE dans l''option B'
            else 'OK' end
        when email_fn = 'notify_booking_brevo' then
          'via Brevo — ' || case
            when brevo_def is null or not notif_new then 'ANCIENNE VERSION → relance étape commune + option C'
            when not brevo_key then
              'CLÉ BREVO ABSENTE → rien n''est envoyé. Si tu utilisais Resend, relance étape commune + option B SEULEMENT'
            when brevo_def like '%example.com%' then 'ADRESSES PAS REMPLACÉES dans l''option C'
            else 'OK' end
        else 'déclencheur inconnu : ' || email_fn
      end),

  (14, 'Notif e-mail : messages',
      case
        when email_msg_on then 'OK'
        when email_fn is not null then 'MANQUE → lance migration-panier.sql, puis relance notifications.sql : étape commune + ton option e-mail'
        else 'pas activée'
      end)
) v(n, etape, etat)
order by n;
