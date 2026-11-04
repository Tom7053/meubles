-- =====================================================================
--  møbel — alerts for new bookings and new messages (optional)
--
--  While the seller space is open, new bookings and messages already pop
--  up live. This file also alerts you when the site is closed. Pick one
--  option (or several):
--
--    OPTION A — push notification on your phone, with ntfy.sh
--               Free, no account, 2 minutes.
--    OPTION B — e-mail, with Resend
--               Free up to 3,000 e-mails a month, account needed.
--    OPTION C — e-mail, with Brevo (several recipients possible)
--
--  How: run install.sql first. Then SQL Editor → New query → paste the
--  COMMON STEP and your option → replace the values marked REPLACE → Run.
--  Nothing to change in the site: it all happens in the database.
--
--  You get one alert per booking (one for a whole cart, with the list of
--  items) and one per "call me back" message. Alerts are written in the
--  seller space language (English or French, Settings tab).
--
--  Safe to run again, for example after updating møbel.
-- =====================================================================


-- ---------------------------------------------------------------------
--  COMMON STEP — run it with any option
-- ---------------------------------------------------------------------
-- pg_net lets the database call the web.
create extension if not exists pg_net;

-- What buyers type must not be able to format the e-mail.
create or replace function public.notif_html(t text)
returns text
language sql
immutable
as $$
  select replace(replace(replace(replace(coalesce(t, ''),
           '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- The language of the alerts: the seller space language, 'en' or 'fr'.
create or replace function public.notif_lang()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case when (select admin_lang from settings where id = 1) like 'fr%' then 'fr' else 'en' end;
$$;

-- English or French text, in the alerts' language.
create or replace function public.notif_t(en text, fr text)
returns text
language sql
stable
as $$
  select case when public.notif_lang() = 'fr' then fr else en end;
$$;

-- The ways to pay, as in PAYMENT_METHODS in index.html.
create or replace function public.notif_payment(id text)
returns text
language sql
stable
as $$
  select case id
    when 'cash'      then public.notif_t('Cash', 'Espèces')
    when 'transfer'  then public.notif_t('Bank transfer', 'Virement bancaire')
    when 'card'      then public.notif_t('Card', 'Carte bancaire')
    when 'revolut'   then public.notif_t('Revolut instant transfer', 'Virement instantané Revolut')
    when 'paypal'    then 'PayPal'
    when 'wero'      then 'Wero'
    when 'lydia'     then 'Lydia'
    when 'mobilepay' then 'MobilePay'
    when 'swish'     then 'Swish'
    when 'vipps'     then 'Vipps'
    when 'twint'     then 'TWINT'
    when 'bizum'     then 'Bizum'
    when 'blik'      then 'BLIK'
    when 'satispay'  then 'Satispay'
    when 'tikkie'    then 'Tikkie'
    when 'venmo'     then 'Venmo'
    when 'zelle'     then 'Zelle'
    when 'cashapp'   then 'Cash App'
    when 'interac'   then public.notif_t('Interac e-Transfer', 'Virement Interac')
    when 'payid'     then 'PayID'
    when 'upi'       then 'UPI'
    when 'pix'       then 'Pix'
    else id
  end;
$$;

-- A booking alert: { title, text, subject, html }. For a cart (several
-- rows with the same cart_id), only the first row gives an alert, listing
-- every item; the others give null.
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
  item  text := public.notif_t('Item', 'Meuble');
  lines text[];
  n     int;
  pay   text := public.notif_payment(b ->> 'payment');
  at    text := public.notif_t(' at ', ' à ');
  title text;
begin
  if cart is not null then
    if exists (select 1 from bookings o
                where o.cart_id::text = cart
                  and o.id::text < b ->> 'id') then
      return null;
    end if;
    select array_agg(
             case when coalesce(o.quantity, 1) > 1 then o.quantity || ' × ' else '' end
             || coalesce(o.item_title, item)
             order by o.item_title)
      into lines
      from bookings o
     where o.cart_id::text = cart;
  end if;

  if lines is null then
    lines := array[case when coalesce((b ->> 'quantity')::int, 1) > 1
                        then (b ->> 'quantity') || ' × ' else '' end
                   || coalesce(b ->> 'item_title', item)];
  end if;
  n := array_length(lines, 1);
  title := public.notif_t('New booking', 'Nouveau rendez-vous');

  return jsonb_build_object(
    'title',   case when n > 1 then title || ' — ' || n || public.notif_t(' items', ' meubles') else title end,
    'text',    (b ->> 'first_name') || ' — ' || to_char(d, 'DD/MM') || at || (b ->> 'slot') ||
               E'\n' || array_to_string(lines, E'\n') ||
               E'\n' || (b ->> 'phone') ||
               coalesce(E'\n' || pay, ''),
    'subject', title || ' — ' || (b ->> 'first_name') || ', ' || to_char(d, 'DD/MM') || at || (b ->> 'slot') ||
               case when n > 1 then ' (' || n || public.notif_t(' items)', ' meubles)') else '' end,
    'html',
      '<h2 style="font-family:sans-serif;color:#16307a">' || title || '</h2>' ||
      '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
      '<strong>' || notif_html(b ->> 'first_name') || '</strong><br>' ||
      public.notif_t('Phone', 'Téléphone') || ' : <a href="tel:' || notif_html(replace(b ->> 'phone', ' ', '')) || '">' ||
        notif_html(b ->> 'phone') || '</a><br>' ||
      public.notif_t('Date', 'Date') || ' : ' || to_char(d, 'DD/MM/YYYY') || at || notif_html(b ->> 'slot') || '<br>' ||
      case when n > 1
           then public.notif_t('Items (same viewing)', 'Meubles (même rendez-vous)') || ' :<br>• ' ||
                array_to_string(array(select notif_html(x) from unnest(lines) x), '<br>• ')
           else item || ' : ' || notif_html(lines[1]) end ||
      coalesce('<br>' || public.notif_t('Payment', 'Paiement') || ' : ' || notif_html(pay), '') ||
      '</p>'
  );
end;
$$;

-- A "call me back" message alert.
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
  item  text := public.notif_t('Item', 'Meuble');
begin
  select array_agg(
           case when coalesce((x ->> 'quantity')::int, 1) > 1
                then (x ->> 'quantity') || ' × ' else '' end
           || coalesce(x ->> 'title', item)
           order by ord)
    into lines
    from jsonb_array_elements(case when jsonb_typeof(m -> 'items') = 'array'
                                   then m -> 'items' else '[]'::jsonb end)
         with ordinality as t(x, ord);
  n := coalesce(array_length(lines, 1), 0);

  return jsonb_build_object(
    'title',   public.notif_t('Call back: ', 'À rappeler : ') || (m ->> 'first_name'),
    'text',    (m ->> 'first_name') || ' — ' || (m ->> 'phone') ||
               case when n > 0 then E'\n' || array_to_string(lines, E'\n') else '' end ||
               coalesce(E'\n« ' || msg || ' »', ''),
    'subject', public.notif_t('Message from ', 'Message de ') || (m ->> 'first_name') ||
               public.notif_t(' — call back', ' — à rappeler'),
    'html',
      '<h2 style="font-family:sans-serif;color:#16307a">' ||
        public.notif_t('New message: call back', 'Nouveau message : à rappeler') || '</h2>' ||
      '<p style="font-family:sans-serif;font-size:16px;line-height:1.6">' ||
      '<strong>' || notif_html(m ->> 'first_name') || '</strong><br>' ||
      public.notif_t('Phone', 'Téléphone') || ' : <a href="tel:' || notif_html(replace(m ->> 'phone', ' ', '')) || '">' ||
        notif_html(m ->> 'phone') || '</a>' ||
      case when n > 0
           then '<br>' || public.notif_t('About', 'À propos de') || ' :<br>• ' ||
                array_to_string(array(select notif_html(x) from unnest(lines) x), '<br>• ')
           else '' end ||
      '</p>' ||
      coalesce('<blockquote style="font-family:sans-serif;font-size:16px;line-height:1.6;' ||
               'white-space:pre-line;border-left:3px solid #1d4ed8;margin:0;padding:4px 12px">' ||
               notif_html(msg) || '</blockquote>', '')
  );
end;
$$;

-- No one may call these from the site: only the triggers below use them.
revoke all on function public.notif_html(text)           from public, anon, authenticated;
revoke all on function public.notif_lang()               from public, anon, authenticated;
revoke all on function public.notif_t(text, text)        from public, anon, authenticated;
revoke all on function public.notif_payment(text)        from public, anon, authenticated;
revoke all on function public.booking_alert(jsonb)       from public, anon, authenticated;
revoke all on function public.contact_alert(jsonb)       from public, anon, authenticated;


-- =====================================================================
--  OPTION A — PUSH ON YOUR PHONE (ntfy.sh)
-- =====================================================================
--
--  Before running this block:
--    1. Install the "ntfy" app (App Store / Play Store / F-Droid).
--    2. Make up a LONG topic name THAT NO ONE CAN GUESS.
--       Topics are public: whoever knows it receives your alerts.
--       Bad:   furniture
--       Good:  mobel-7hq2k9xz41wd
--    3. In the app: "+", then subscribe to that topic.
--    4. Replace the topic below (ONE place).
--
create or replace function public.notify_send_push(title text, message text, tag text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  topic text := 'REPLACE-WITH-YOUR-SECRET-TOPIC';
begin
  -- Topic not replaced yet: send nothing rather than names and numbers
  -- on a topic anyone can read.
  if topic like 'REPLACE-%' then
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
    -- If the alert fails, the buyer's booking must still go through.
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

drop trigger if exists on_new_contact_push on public.contact_requests;
create trigger on_new_contact_push
  after insert on public.contact_requests
  for each row execute function public.notify_contact_push();


-- =====================================================================
--  OPTION B — E-MAIL (Resend)
-- =====================================================================
--
--  Before running this block:
--    1. Create an account on resend.com with the address where you want
--       the alerts, then API Keys → Create API Key (it starts with re_).
--    2. Without a verified domain, Resend only sends TO your account's
--       address, FROM onboarding@resend.dev. That is all you need: you
--       write to yourself.
--    3. Store the key in Supabase's vault, ONCE: uncomment the line
--       below, paste your real key, run it alone.

-- select vault.create_secret('re_paste_your_key_here', 'resend_key', 'Resend API key');

--    4. Replace you@example.com below (ONE place), then run the rest.
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
      'from',    'møbel <onboarding@resend.dev>',
      'to',      jsonb_build_array('you@example.com'),
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

drop trigger if exists on_new_contact_email on public.contact_requests;
create trigger on_new_contact_email
  after insert on public.contact_requests
  for each row execute function public.notify_contact_email();


-- =====================================================================
--  OPTION C — E-MAIL WITH BREVO (best if several people get the alerts)
--
--  Unlike Resend, a sender address confirmed by e-mail is enough, and
--  you can then write to as many recipients as you like, without owning
--  a domain. Free up to 300 e-mails a day.
--
--  Before running this block:
--    1. Create an account on brevo.com.
--    2. Senders, Domains & Dedicated IPs → Senders → Add a sender: your
--       address. Brevo sends a confirmation link; nothing goes out until
--       the sender is confirmed.
--    3. SMTP & API → API Keys → Generate a new API key (xkeysib-…).
--    4. Store the key in the vault, ONCE:

-- select vault.create_secret('xkeysib_paste_your_key_here', 'brevo_key', 'Brevo API key');

--    5. Replace the three addresses below, then run the rest (with the
--       common step at the top). This block replaces the e-mail trigger:
--       if option B was on, it is turned off, you will not get each alert
--       twice.
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
      -- MUST be the address confirmed in step 2
      'sender', jsonb_build_object('name', 'møbel',
                                   'email', 'you@example.com'),
      -- as many recipients as you like
      'to', jsonb_build_array(
              jsonb_build_object('email', 'you@example.com'),
              jsonb_build_object('email', 'someone.else@example.com')
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

drop trigger if exists on_new_contact_email on public.contact_requests;
create trigger on_new_contact_email
  after insert on public.contact_requests
  for each row execute function public.notify_contact_brevo();


-- =====================================================================
--  TEST
-- =====================================================================
--  Insert a fake booking or message: the alert should arrive within
--  seconds. Delete them afterwards.

-- insert into public.bookings (item_title, first_name, phone, day, slot)
-- values ('Test', 'Test', '+1 555 000 0000', current_date + 1, '10:00');
-- delete from public.bookings where first_name = 'Test';

-- insert into public.contact_requests (first_name, phone, message)
-- values ('Test', '+1 555 000 0000', 'This is a test');
-- delete from public.contact_requests where first_name = 'Test';

--  Nothing arrives? See what the database actually sent and received:

-- select id, status_code, content, created
--   from net._http_response
--  order by created desc
--  limit 5;

--  status_code 200 or 202 = it left Supabase; the problem is elsewhere
--  (wrong ntfy topic, app not subscribed, spam folder).


-- =====================================================================
--  TURN OFF (after the sale, or if you change your mind)
-- =====================================================================
-- drop trigger if exists on_new_booking_push   on public.bookings;
-- drop trigger if exists on_new_booking_email  on public.bookings;
-- drop trigger if exists on_new_contact_push   on public.contact_requests;
-- drop trigger if exists on_new_contact_email  on public.contact_requests;
