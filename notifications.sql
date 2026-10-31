-- =====================================================================
--  NOTIFICATIONS AUTOMATIQUES : NOUVEAUX RENDEZ-VOUS ET NOUVEAUX MESSAGES
--
--  Trois options, au choix (tu peux aussi en activer plusieurs) :
--    OPTION A — notification push sur ton téléphone, via ntfy.sh
--               Gratuit, aucun compte à créer, 2 minutes.
--    OPTION B — e-mail, via Resend
--               Gratuit jusqu'à 3000 e-mails par mois, compte à créer.
--    OPTION C — e-mail, via Brevo (plusieurs destinataires possibles)
--
--  Dans tous les cas : SQL Editor > New query > coller > Run.
--  Rien à changer dans le site, ça se passe entièrement côté base.
--
--  Tu reçois une alerte :
--    · à chaque rendez-vous — UNE seule pour un panier de plusieurs
--      meubles, avec la liste complète ;
--    · à chaque message « rappelez-moi » laissé dans la boutique
--      (il faut avoir lancé migration-panier.sql AVANT ce fichier).
--
--  Tu l'avais déjà lancé avant le panier ? Relance ce fichier en entier
--  (étape commune + ton option, avec ton sujet ou tes adresses) : sinon
--  un panier de 3 meubles t'envoie 3 alertes et les messages aucune.
-- =====================================================================


-- ---------------------------------------------------------------------
--  ÉTAPE COMMUNE — à lancer avec n'importe quelle option
-- ---------------------------------------------------------------------
-- pg_net permet à la base d'appeler le web.
create extension if not exists pg_net;

-- Ce que tapent les acheteurs ne doit pas pouvoir mettre en forme l'e-mail.
create or replace function public.notif_html(t text)
returns text
language sql
immutable
as $$
  select replace(replace(replace(replace(coalesce(t, ''),
           '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- Le contenu d'une alerte de rendez-vous : { title, text, subject, html }.
-- Pour un panier (plusieurs lignes au même cart_id), seule la première
-- ligne donne une alerte, avec tous les meubles ; les autres donnent null.
-- to_jsonb marche même avant migration-quantite.sql / migration-panier.sql.
create or replace function public.booking_alert(b jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cart  text := b ->> 'cart_id';
  d     date := (b ->> 'day')::date;
  lines text[];
  n     int;
  pay   text;
begin
  if cart is not null then
    if exists (select 1 from bookings o
                where to_jsonb(o) ->> 'cart_id' = cart
                  and o.id::text < b ->> 'id') then
      return null;
    end if;
    select array_agg(
             case when coalesce((to_jsonb(o) ->> 'quantity')::int, 1) > 1
                  then (to_jsonb(o) ->> 'quantity') || ' × ' else '' end
             || coalesce(o.item_title, 'Meuble')
             order by o.item_title)
      into lines
      from bookings o
     where to_jsonb(o) ->> 'cart_id' = cart;
  end if;

  if lines is null then
    lines := array[case when coalesce((b ->> 'quantity')::int, 1) > 1
                        then (b ->> 'quantity') || ' × ' else '' end
                   || coalesce(b ->> 'item_title', 'Meuble')];
  end if;
  n := array_length(lines, 1);

  pay := case b ->> 'payment'
           when 'mobilepay' then 'MobilePay'
           when 'cash'      then 'Espèces'
           when 'revolut'   then 'Virement instantané Revolut' end;

  return jsonb_build_object(
    'title',   case when n > 1 then 'Nouveau rendez-vous — ' || n || ' meubles'
                    else 'Nouveau rendez-vous' end,
    'text',    (b ->> 'first_name') || ' — ' || to_char(d, 'DD/MM') || ' à ' || (b ->> 'slot') ||
               E'\n' || array_to_string(lines, E'\n') ||
               E'\n' || (b ->> 'phone') ||
               coalesce(E'\n' || pay, ''),
    'subject', 'Nouveau rendez-vous — ' || (b ->> 'first_name') ||
               ' le ' || to_char(d, 'DD/MM') || ' à ' || (b ->> 'slot') ||
               case when n > 1 then ' (' || n || ' meubles)' else '' end,
    'html',
      '<h2 style="font-family:sans-serif;color:#16307a">Nouveau rendez-vous</h2>' ||
      '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
      '<strong>' || notif_html(b ->> 'first_name') || '</strong><br>' ||
      'Téléphone : <a href="tel:' || notif_html(replace(b ->> 'phone', ' ', '')) || '">' ||
        notif_html(b ->> 'phone') || '</a><br>' ||
      'Date : ' || to_char(d, 'DD/MM/YYYY') || ' à ' || notif_html(b ->> 'slot') || '<br>' ||
      case when n > 1
           then 'Meubles (même rendez-vous) :<br>• ' ||
                array_to_string(array(select notif_html(x) from unnest(lines) x), '<br>• ')
           else 'Meuble : ' || notif_html(lines[1]) end ||
      coalesce('<br>Paiement : ' || pay, '') ||
      '</p>'
  );
end;
$$;

-- Le contenu d'une alerte de message « rappelez-moi ».
create or replace function public.contact_alert(m jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  lines text[];
  n     int;
  msg   text := nullif(btrim(m ->> 'message'), '');
begin
  select array_agg(
           case when coalesce((x ->> 'quantity')::int, 1) > 1
                then (x ->> 'quantity') || ' × ' else '' end
           || coalesce(x ->> 'title', 'Meuble')
           order by ord)
    into lines
    from jsonb_array_elements(case when jsonb_typeof(m -> 'items') = 'array'
                                   then m -> 'items' else '[]'::jsonb end)
         with ordinality as t(x, ord);
  n := coalesce(array_length(lines, 1), 0);

  return jsonb_build_object(
    'title',   'À rappeler : ' || (m ->> 'first_name'),
    'text',    (m ->> 'first_name') || ' — ' || (m ->> 'phone') ||
               case when n > 0 then E'\n' || array_to_string(lines, E'\n') else '' end ||
               coalesce(E'\n« ' || msg || ' »', ''),
    'subject', 'Message de ' || (m ->> 'first_name') || ' — à rappeler',
    'html',
      '<h2 style="font-family:sans-serif;color:#16307a">Nouveau message : à rappeler</h2>' ||
      '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
      '<strong>' || notif_html(m ->> 'first_name') || '</strong><br>' ||
      'Téléphone : <a href="tel:' || notif_html(replace(m ->> 'phone', ' ', '')) || '">' ||
        notif_html(m ->> 'phone') || '</a>' ||
      case when n > 0
           then '<br>À propos de :<br>• ' ||
                array_to_string(array(select notif_html(x) from unnest(lines) x), '<br>• ')
           else '' end ||
      '</p>' ||
      coalesce('<blockquote style="font-family:sans-serif;font-size:16px;line-height:1.6;' ||
               'white-space:pre-line;border-left:3px solid #1d4ed8;margin:0;padding:4px 12px">' ||
               notif_html(msg) || '</blockquote>', '')
  );
end;
$$;

-- Personne ne doit pouvoir les appeler depuis le site : seuls les
-- déclencheurs ci-dessous s'en servent.
revoke all on function public.notif_html(text)     from public, anon, authenticated;
revoke all on function public.booking_alert(jsonb) from public, anon, authenticated;
revoke all on function public.contact_alert(jsonb) from public, anon, authenticated;


-- =====================================================================
--  OPTION A — PUSH SUR LE TÉLÉPHONE (ntfy.sh)
-- =====================================================================
--
--  Avant de lancer ce bloc :
--    1. Installe l'application « ntfy » (App Store / Play Store / F-Droid).
--    2. Invente un nom de sujet LONG ET IMPOSSIBLE À DEVINER.
--       Le sujet est public : qui le connaît reçoit tes notifications.
--       Mauvais  : meubles
--       Bon      : meubles-odense-8fk29dqz71
--    3. Dans l'application : « + » puis abonne-toi à ce sujet.
--    4. Remplace le sujet ci-dessous (UN seul endroit).
--
create or replace function public.notify_send_push(title text, message text, tag text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  topic text := 'REMPLACE-PAR-TON-SUJET-SECRET';
begin
  -- Sujet pas encore remplacé : on n'envoie rien plutôt que d'envoyer
  -- les prénoms et numéros sur un sujet que tout le monde peut lire.
  if topic like 'REMPLACE-%' then
    return;
  end if;
  perform net.http_post(
    url     := 'https://ntfy.sh',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := jsonb_build_object(
      'topic',    topic,
      'title',    title,
      'message',  message,
      'tags',     jsonb_build_array(tag),
      'priority', 4
    )
  );
end;
$$;

revoke all on function public.notify_send_push(text, text, text) from public, anon, authenticated;

create or replace function public.notify_booking_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.booking_alert(to_jsonb(new));
  if a is not null then
    perform public.notify_send_push(a ->> 'title', a ->> 'text', 'calendar');
  end if;
  return new;
exception
  when others then
    -- Si la notification échoue, la réservation de l'acheteur doit
    -- quand même aboutir. On ignore l'erreur volontairement.
    return new;
end;
$$;

drop trigger if exists on_new_booking_push on public.bookings;
create trigger on_new_booking_push
  after insert on public.bookings
  for each row execute function public.notify_booking_push();

create or replace function public.notify_contact_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.contact_alert(to_jsonb(new));
  perform public.notify_send_push(a ->> 'title', a ->> 'text', 'speech_balloon');
  return new;
exception
  when others then
    return new;
end;
$$;

do $$
begin
  if to_regclass('public.contact_requests') is null then
    raise notice 'Pas encore de table contact_requests : lance migration-panier.sql, puis relance ce fichier pour être prévenue des messages.';
    return;
  end if;
  execute 'drop trigger if exists on_new_contact_push on public.contact_requests';
  execute 'create trigger on_new_contact_push after insert on public.contact_requests '
       || 'for each row execute function public.notify_contact_push()';
end $$;


-- =====================================================================
--  OPTION B — E-MAIL (Resend)
-- =====================================================================
--
--  Avant de lancer ce bloc :
--    1. Crée un compte sur resend.com avec l'adresse où tu veux recevoir
--       les alertes, puis API Keys > Create API Key (elle commence par re_).
--    2. Sans domaine vérifié, Resend n'autorise l'envoi QUE vers l'adresse
--       de ton compte, depuis onboarding@resend.dev. C'est exactement
--       ce qu'il te faut : tu t'écris à toi-même.
--    3. Enregistre la clé dans le coffre-fort de Supabase (à faire UNE fois,
--       en décommentant la ligne ci-dessous et en y collant ta vraie clé) :

-- select vault.create_secret('re_colle_ta_cle_ici', 'resend_key', 'Clé API Resend');

--    4. Remplace ton.adresse@example.com plus bas (UN seul endroit), puis
--       lance le reste.
--
create or replace function public.notify_send_resend(subject text, html text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'resend_key';

  if v_key is null then
    return;
  end if;

  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'from',    'Meubles <onboarding@resend.dev>',
      'to',      jsonb_build_array('ton.adresse@example.com'),
      'subject', subject,
      'html',    html
    )
  );
end;
$$;

revoke all on function public.notify_send_resend(text, text) from public, anon, authenticated;

create or replace function public.notify_booking_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.booking_alert(to_jsonb(new));
  if a is not null then
    perform public.notify_send_resend(a ->> 'subject', a ->> 'html');
  end if;
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists on_new_booking_email on public.bookings;
create trigger on_new_booking_email
  after insert on public.bookings
  for each row execute function public.notify_booking_email();

create or replace function public.notify_contact_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.contact_alert(to_jsonb(new));
  perform public.notify_send_resend(a ->> 'subject', a ->> 'html');
  return new;
exception
  when others then
    return new;
end;
$$;

do $$
begin
  if to_regclass('public.contact_requests') is null then
    raise notice 'Pas encore de table contact_requests : lance migration-panier.sql, puis relance ce fichier pour être prévenue des messages.';
    return;
  end if;
  execute 'drop trigger if exists on_new_contact_email on public.contact_requests';
  execute 'create trigger on_new_contact_email after insert on public.contact_requests '
       || 'for each row execute function public.notify_contact_email()';
end $$;


-- =====================================================================
--  TESTER
-- =====================================================================
--  Insère un faux rendez-vous ou un faux message : la notification doit
--  arriver en quelques secondes. Supprime-les ensuite.

-- insert into public.bookings (item_title, first_name, phone, day, slot)
-- values ('Test', 'Test', '+45 00 00 00 00', current_date + 1, '10:00');
-- delete from public.bookings where first_name = 'Test';

-- insert into public.contact_requests (first_name, phone, message)
-- values ('Test', '+45 00 00 00 00', 'Ceci est un test');
-- delete from public.contact_requests where first_name = 'Test';


--  Si rien n'arrive, regarde ce que la base a réellement envoyé et reçu :

-- select id, status_code, content, created
--   from net._http_response
--  order by created desc
--  limit 5;

--  status_code 200 ou 202 = c'est parti côté Supabase, le problème est
--  ailleurs (mauvais sujet ntfy, application non abonnée, spam).


-- =====================================================================
--  DÉSACTIVER (après la vente, ou si tu changes d'avis)
-- =====================================================================
-- drop trigger if exists on_new_booking_push   on public.bookings;
-- drop trigger if exists on_new_booking_email  on public.bookings;
-- drop trigger if exists on_new_contact_push   on public.contact_requests;
-- drop trigger if exists on_new_contact_email  on public.contact_requests;


-- =====================================================================
--  OPTION C — E-MAIL VIA BREVO (recommandé si vous êtes deux)
--
--  Avantage sur Resend : une simple adresse d'expédition validée par
--  e-mail suffit, et tu peux ensuite écrire à autant de destinataires
--  que tu veux, sans posséder de domaine.
--  Gratuit jusqu'à 300 e-mails par jour.
--
--  Avant de lancer ce bloc :
--    1. Crée un compte sur brevo.com.
--    2. Senders, Domains & Dedicated IPs > Senders > Add a sender :
--       mets ton adresse, Brevo t'envoie un lien de confirmation.
--       Tant que le sender n'est pas validé, rien ne part.
--    3. SMTP & API > API Keys > Generate a new API key (xkeysib-…).
--    4. Enregistre la clé dans le coffre-fort, UNE fois :

-- select vault.create_secret('xkeysib_colle_ta_cle_ici', 'brevo_key', 'Clé API Brevo');

--    5. Remplace les trois adresses ci-dessous, puis lance le reste
--       (avec l'étape commune tout en haut).
--       Ce bloc remplace le déclencheur e-mail : si tu avais activé
--       l'option Resend, elle est automatiquement désactivée, tu ne
--       recevras pas deux fois le même message.
--
create or replace function public.notify_send_brevo(subject text, html text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'brevo_key';

  if v_key is null then
    return;
  end if;

  perform net.http_post(
    url     := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'accept',       'application/json',
      'api-key',      v_key
    ),
    body := jsonb_build_object(
      -- DOIT être l'adresse validée à l'étape 2
      'sender', jsonb_build_object('name', 'Vente de meubles',
                                   'email', 'ton.adresse@example.com'),
      -- autant de destinataires que tu veux
      'to', jsonb_build_array(
              jsonb_build_object('email', 'ton.adresse@example.com'),
              jsonb_build_object('email', 'la.deuxieme@example.com')
            ),
      'subject',     subject,
      'htmlContent', html
    )
  );
end;
$$;

revoke all on function public.notify_send_brevo(text, text) from public, anon, authenticated;

create or replace function public.notify_booking_brevo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.booking_alert(to_jsonb(new));
  if a is not null then
    perform public.notify_send_brevo(a ->> 'subject', a ->> 'html');
  end if;
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists on_new_booking_email on public.bookings;
create trigger on_new_booking_email
  after insert on public.bookings
  for each row execute function public.notify_booking_brevo();

create or replace function public.notify_contact_brevo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a jsonb;
begin
  a := public.contact_alert(to_jsonb(new));
  perform public.notify_send_brevo(a ->> 'subject', a ->> 'html');
  return new;
exception
  when others then
    return new;
end;
$$;

do $$
begin
  if to_regclass('public.contact_requests') is null then
    raise notice 'Pas encore de table contact_requests : lance migration-panier.sql, puis relance ce fichier pour être prévenue des messages.';
    return;
  end if;
  execute 'drop trigger if exists on_new_contact_email on public.contact_requests';
  execute 'create trigger on_new_contact_email after insert on public.contact_requests '
       || 'for each row execute function public.notify_contact_brevo()';
end $$;
