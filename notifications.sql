-- =====================================================================
--  NOTIFICATIONS AUTOMATIQUES À CHAQUE NOUVEAU RENDEZ-VOUS
--
--  Deux options, au choix (tu peux aussi activer les deux) :
--    OPTION A — notification push sur ton téléphone, via ntfy.sh
--               Gratuit, aucun compte à créer, 2 minutes.
--    OPTION B — e-mail, via Resend
--               Gratuit jusqu'à 3000 e-mails par mois, compte à créer.
--
--  Dans les deux cas : SQL Editor > New query > coller > Run.
--  Rien à changer dans le site, ça se passe entièrement côté base.
-- =====================================================================


-- ---------------------------------------------------------------------
--  ÉTAPE COMMUNE — activer pg_net (permet à la base d'appeler le web)
-- ---------------------------------------------------------------------
create extension if not exists pg_net;


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
--    4. Remplace le sujet ci-dessous (2 endroits : ici et dans le test).
--
create or replace function public.notify_booking_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url     := 'https://ntfy.sh',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body    := jsonb_build_object(
      'topic',    'REMPLACE-PAR-TON-SUJET-SECRET',
      'title',    'Nouveau rendez-vous',
      'message',  new.first_name || ' — ' ||
                  to_char(new.day, 'DD/MM') || ' à ' || new.slot ||
                  E'\n' || coalesce(new.item_title, 'Meuble') ||
                  E'\n' || new.phone ||
                  coalesce(E'\n' || case new.payment
                    when 'mobilepay' then 'MobilePay'
                    when 'revolut' then 'Virement Revolut' end, ''),
      'tags',     jsonb_build_array('calendar'),
      'priority', 4
    )
  );
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

--    4. Remplace ton.adresse@example.com plus bas, puis lance le reste.
--
create or replace function public.notify_booking_email()
returns trigger
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
    return new;
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
      'subject', 'Nouveau rendez-vous — ' || new.first_name ||
                 ' le ' || to_char(new.day, 'DD/MM') || ' à ' || new.slot,
      'html',
        '<h2 style="font-family:sans-serif">Nouveau rendez-vous</h2>' ||
        '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
        '<strong>' || new.first_name || '</strong><br>' ||
        'Téléphone : <a href="tel:' || replace(new.phone, ' ', '') || '">' || new.phone || '</a><br>' ||
        'Date : ' || to_char(new.day, 'DD/MM/YYYY') || ' à ' || new.slot || '<br>' ||
        'Meuble : ' || coalesce(new.item_title, '—') ||
        coalesce('<br>Paiement : ' || case new.payment
          when 'mobilepay' then 'MobilePay'
          when 'revolut' then 'Virement instantané Revolut' end, '') ||
        '</p>'
    )
  );
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


-- =====================================================================
--  TESTER
-- =====================================================================
--  Insère un faux rendez-vous : la notification doit arriver en quelques
--  secondes. Supprime-le ensuite.

-- insert into public.bookings (item_title, first_name, phone, day, slot)
-- values ('Test', 'Test', '+45 00 00 00 00', current_date + 1, '10:00');

-- delete from public.bookings where first_name = 'Test';


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
-- drop trigger if exists on_new_booking_push  on public.bookings;
-- drop trigger if exists on_new_booking_email on public.bookings;


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

--    5. Remplace les trois adresses ci-dessous, puis lance le reste.
--       Ce bloc remplace le déclencheur e-mail : si tu avais activé
--       l'option Resend, elle est automatiquement désactivée, tu ne
--       recevras pas deux fois le même message.
--
create or replace function public.notify_booking_brevo()
returns trigger
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
    return new;
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
      'subject', 'Nouveau rendez-vous — ' || new.first_name ||
                 ' le ' || to_char(new.day, 'DD/MM') || ' à ' || new.slot,
      'htmlContent',
        '<h2 style="font-family:sans-serif;color:#16307a">Nouveau rendez-vous</h2>' ||
        '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
        '<strong>' || new.first_name || '</strong><br>' ||
        'Téléphone : <a href="tel:' || replace(new.phone, ' ', '') || '">' || new.phone || '</a><br>' ||
        'Date : ' || to_char(new.day, 'DD/MM/YYYY') || ' à ' || new.slot || '<br>' ||
        'Meuble : ' || coalesce(new.item_title, '—') ||
        coalesce('<br>Paiement : ' || case new.payment
          when 'mobilepay' then 'MobilePay'
          when 'revolut' then 'Virement instantané Revolut' end, '') ||
        '</p>'
    )
  );
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
