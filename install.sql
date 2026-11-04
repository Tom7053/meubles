-- =====================================================================
--  møbel — database install and update
--
--  New shop:  Supabase → SQL Editor → New query → paste this whole file
--             → Run. Then create your seller account (see README.md).
--
--  Update:    after downloading a new version of møbel, run this file
--             again, the same way.
--
--  Safe to run as many times as you like. It never deletes listings,
--  bookings, messages or settings: it only creates what is missing and
--  brings rules and functions up to date.
--
--  Who can do what
--    · Visitors (no account): read listings, photos, bundles and the
--      shop settings; book a viewing; leave a message; count a visit.
--      They never read names or phone numbers.
--    · The seller: the FIRST account created in Authentication → Users.
--      Only that account reads bookings, messages and stats, and edits
--      the shop. Any other account sees nothing private.
-- =====================================================================


-- =====================================================================
--  1. The seller
-- =====================================================================
-- One row: the account that runs the shop. Nobody reads this table
-- through the API; is_seller() reads it for the rules below.
do $$
begin
  if to_regclass('public.seller') is null then
    create table public.seller (
      user_id    uuid primary key references auth.users (id) on delete cascade,
      created_at timestamptz not null default now()
    );
    -- Accounts created before this table existed were all treated as the
    -- seller: they keep their access. On a new project, there is no one yet.
    insert into public.seller (user_id) select id from auth.users;
  end if;
end $$;

alter table public.seller enable row level security;
revoke all on public.seller from anon, authenticated;

-- The first account created becomes the seller; later ones do not.
create or replace function public.claim_seller()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.seller) then
    insert into public.seller (user_id) values (new.id) on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists claim_seller on auth.users;
create trigger claim_seller
  after insert on auth.users
  for each row execute function public.claim_seller();

-- True only for the signed-in seller.
create or replace function public.is_seller()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.seller where user_id = (select auth.uid()));
$$;

revoke all on function public.is_seller() from public;
grant execute on function public.is_seller() to anon, authenticated;


-- =====================================================================
--  2. settings — one row (id = 1) with everything the seller chooses
-- =====================================================================
-- Readable by everyone (the shop needs its language, currency, address
-- and schedule); only the seller changes it.
create table if not exists public.settings (
  id             int primary key default 1 check (id = 1),
  -- Pickup place, and the payment line shown in the shop header.
  address        text not null default '',
  payment        text not null default '',
  -- Opening days, Monday first, and the times offered for a viewing.
  weekdays       jsonb not null default '[true, true, true, true, true, true, false]',
  slots          jsonb not null default '["09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00", "18:00"]',
  -- Closed days, as 'YYYY-MM-DD'.
  blocked        jsonb not null default '[]',
  -- 'en' or 'fr'.
  shop_lang      text not null default 'en',
  admin_lang     text not null default 'en',
  -- Buttons offered under "Links to other sites" in a listing.
  link_sites     text[] not null default array['Facebook Marketplace'],
  -- ISO 4217 code ('EUR', 'DKK', 'USD'…). Empty until the first sign-in.
  currency       text,
  -- ISO 3166 code ('FR', 'DK'…): default country for buyers' phone numbers.
  country        text,
  -- How buyers can pay, offered when they book ('cash', 'mobilepay'…).
  payment_methods text[] not null default array['cash'],
  -- IANA time zone ('Europe/Paris'), taken from the seller's browser:
  -- the Stats tab counts "today" in it.
  time_zone      text,
  -- Shop header and poster. Empty = a neutral text in the shop language.
  shop_title     text not null default '',
  shop_intro     text not null default '',
  shop_text      text not null default '',
  -- Last day buyers can book. Empty = no end date.
  last_day       date,
  -- How much the sale should bring in. Empty = no goal.
  sales_goal     numeric(12, 2),
  -- false until the seller has gone through "First steps".
  setup_done     boolean not null default false,
  -- Version of this file last run; the seller space asks for an update
  -- when it is too old.
  schema_version int not null default 0
);

-- ---- Older installs: add what they are missing ----------------------
alter table public.settings add column if not exists shop_lang  text not null default 'en';
alter table public.settings add column if not exists admin_lang text not null default 'en';
alter table public.settings add column if not exists link_sites text[] not null
  default array['Facebook Marketplace'];
alter table public.settings add column if not exists country text;
alter table public.settings add column if not exists time_zone text;
alter table public.settings add column if not exists shop_title text not null default '';
alter table public.settings add column if not exists shop_intro text not null default '';
alter table public.settings add column if not exists shop_text  text not null default '';
alter table public.settings add column if not exists last_day date;
alter table public.settings add column if not exists sales_goal numeric(12, 2);
alter table public.settings add column if not exists setup_done boolean not null default false;
alter table public.settings add column if not exists schema_version int not null default 0;

-- Before version 1, every shop was priced in Danish kroner and offered
-- Revolut and cash: an older install keeps that until the seller changes it.
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'settings'
                    and column_name = 'currency') then
    alter table public.settings add column currency text;
    update public.settings set currency = 'DKK';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'settings'
                    and column_name = 'payment_methods') then
    alter table public.settings add column payment_methods text[] not null default array['cash'];
    update public.settings set payment_methods = array['revolut', 'cash'];
  end if;
end $$;

alter table public.settings drop constraint if exists settings_shop_lang_check;
alter table public.settings add constraint settings_shop_lang_check
  check (shop_lang ~ '^[a-z]{2}(-[A-Z]{2})?$');
alter table public.settings drop constraint if exists settings_admin_lang_check;
alter table public.settings add constraint settings_admin_lang_check
  check (admin_lang ~ '^[a-z]{2}(-[A-Z]{2})?$');
alter table public.settings drop constraint if exists settings_currency_check;
alter table public.settings add constraint settings_currency_check
  check (currency is null or currency ~ '^[A-Z]{3}$');
alter table public.settings drop constraint if exists settings_country_check;
alter table public.settings add constraint settings_country_check
  check (country is null or country ~ '^[A-Z]{2}$');
alter table public.settings drop constraint if exists settings_sales_goal_check;
alter table public.settings add constraint settings_sales_goal_check
  check (sales_goal is null or sales_goal >= 0);

-- The one row.
insert into public.settings (id)
select 1 where not exists (select 1 from public.settings where id = 1);


-- =====================================================================
--  3. items — the furniture for sale
-- =====================================================================
create table if not exists public.items (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  title           text not null,
  -- As typed by the seller: '450', '1200.50', or words ('Free').
  price           text,
  condition       text,
  description     text,
  -- [{ "label": "Facebook Marketplace", "url": "https://…" }]
  links           jsonb not null default '[]',
  -- Cover photo (a data URL). The other photos live in item_photos.
  image           text,
  status          text not null default 'available',
  -- This item's own dates and times, instead of the shop's schedule.
  available_from  date,
  available_to    date,
  custom_schedule boolean not null default false,
  weekdays        jsonb,
  slots           jsonb,
  -- Identical copies for sale (2 chairs), and how many are gone.
  quantity        int not null default 1,
  sold_qty        int not null default 0,
  -- Price actually paid for each copy sold, in order: [400, 350].
  sale_prices     jsonb not null default '[]',
  -- Copies promised to a buyer met elsewhere (Marketplace…).
  reserved_qty    int not null default 0,
  -- The choices behind the generated description (type, material…).
  details         jsonb
);

-- ---- Older installs ---------------------------------------------------
alter table public.items add column if not exists condition text;
alter table public.items add column if not exists links jsonb not null default '[]';
alter table public.items add column if not exists available_from date;
alter table public.items add column if not exists available_to date;
alter table public.items add column if not exists custom_schedule boolean not null default false;
alter table public.items add column if not exists weekdays jsonb;
alter table public.items add column if not exists slots jsonb;
alter table public.items add column if not exists quantity int not null default 1;
alter table public.items add column if not exists sold_qty int not null default 0;
alter table public.items add column if not exists sale_prices jsonb not null default '[]';
alter table public.items add column if not exists reserved_qty int not null default 0;
alter table public.items add column if not exists details jsonb;

alter table public.items drop constraint if exists items_quantity_check;
alter table public.items add constraint items_quantity_check
  check (quantity >= 1 and sold_qty >= 0 and sold_qty <= quantity);
alter table public.items drop constraint if exists items_sale_prices_check;
alter table public.items add constraint items_sale_prices_check
  check (jsonb_typeof(sale_prices) = 'array');
alter table public.items drop constraint if exists items_reserved_qty_check;
alter table public.items add constraint items_reserved_qty_check
  check (reserved_qty between 0 and 20);


-- =====================================================================
--  4. item_photos — photos after the cover, loaded only when a buyer
--     opens the gallery (the list stays light on a phone)
-- =====================================================================
-- item_id takes the type of items.id, which can differ on old installs.
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
      -- Lets the shop say "4 photos" without loading them.
      photo_count int generated always as (jsonb_array_length(photos)) stored
    )$sql$, id_type);
end $$;


-- =====================================================================
--  5. bookings — viewings booked by buyers
-- =====================================================================
-- One row per item. Items booked together (a cart or a bundle) share a
-- cart_id and the same time.
create table if not exists public.bookings (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  item_id         uuid references public.items (id) on delete set null,
  -- Copied at booking time: still readable if the listing is deleted.
  item_title      text,
  first_name      text not null check (char_length(btrim(first_name)) between 1 and 60),
  phone           text not null check (char_length(phone) between 4 and 30),
  -- How the buyer says they will pay (an id from payment_methods).
  payment         text,
  day             date not null,
  slot            text not null check (slot ~ '^\d{2}:\d{2}$'),
  -- 'new' → 'seen' → 'confirmed', or 'declined'.
  status          text not null default 'new'
                  check (status in ('new', 'seen', 'confirmed', 'declined')),
  quantity        int not null default 1,
  cart_id         uuid,
  -- Booked as part of a bundle: its title and discount, copied by the
  -- database (fill_booking_bundle) so no one can invent a discount.
  bundle_id       uuid,
  bundle_title    text,
  bundle_discount int,
  -- Noted by the seller after the viewing: 'sold' or 'unsold'. Until
  -- then the item stays out of the shop.
  outcome         text,
  -- Amount received at this viewing, all copies included.
  sale_price      numeric
);

-- ---- Older installs ---------------------------------------------------
alter table public.bookings add column if not exists payment text;
alter table public.bookings add column if not exists quantity int not null default 1;
alter table public.bookings add column if not exists cart_id uuid;
alter table public.bookings add column if not exists bundle_id uuid;
alter table public.bookings add column if not exists bundle_title text;
alter table public.bookings add column if not exists bundle_discount int;
alter table public.bookings add column if not exists outcome text;
alter table public.bookings add column if not exists sale_price numeric;

alter table public.bookings drop constraint if exists bookings_payment_check;
alter table public.bookings add constraint bookings_payment_check
  check (payment is null or payment ~ '^[a-z0-9_]{1,30}$');
alter table public.bookings drop constraint if exists bookings_quantity_check;
alter table public.bookings add constraint bookings_quantity_check
  check (quantity between 1 and 20);
alter table public.bookings drop constraint if exists bookings_outcome_check;
alter table public.bookings add constraint bookings_outcome_check
  check (outcome is null or outcome in ('sold', 'unsold'));

create index if not exists bookings_cart_id_idx on public.bookings (cart_id);

-- Older installs refused a second booking at the same time with a unique
-- index on (day, slot). That also refused the other items of a cart:
-- check_slot_free below replaces it.
do $$
declare
  r record;
begin
  for r in
    select i.indexrelid::regclass as idx, c.conname
      from pg_index i
      left join pg_constraint c on c.conindid = i.indexrelid and c.conrelid = i.indrelid
     where i.indrelid = 'public.bookings'::regclass
       and i.indisunique
       and not i.indisprimary
       and i.indexprs is null
       and (select array_agg(a.attname::text order by a.attname::text)
              from unnest(i.indkey) k
              join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k)
           = array['day', 'slot']
  loop
    if r.conname is not null then
      execute format('alter table public.bookings drop constraint %I', r.conname);
    else
      execute format('drop index %s', r.idx);
    end if;
  end loop;
end $$;

-- ---- One buyer per time slot -----------------------------------------
-- Lets the rows of one cart share a time, refuses everything else with
-- code 23505 (the shop then says "someone just took that time").
create or replace function public.check_slot_free()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.day is null or new.slot is null then
    return new;
  end if;

  -- Declining frees the time; an update that changes neither the status
  -- nor the time changes nothing.
  if tg_op = 'UPDATE' and (
       coalesce(new.status, '') = 'declined'
       or (new.day = old.day and new.slot = old.slot
           and coalesce(old.status, '') <> 'declined')) then
    return new;
  end if;

  -- Two buyers on the same time at the same second go one after the other.
  perform pg_advisory_xact_lock(hashtext('mobel slot ' || new.day::text || ' ' || new.slot::text));

  if exists (
    select 1
      from bookings b
     where b.day = new.day
       and b.slot = new.slot
       and b.id is distinct from new.id
       and coalesce(b.status, '') <> 'declined'
       and (new.cart_id is null or b.cart_id is distinct from new.cart_id)
  ) then
    raise exception 'slot_taken'
      using errcode = 'unique_violation', hint = 'This time is already taken.';
  end if;

  return new;
end;
$$;

drop trigger if exists check_slot_free on public.bookings;
create trigger check_slot_free
  before insert or update of status, day, slot on public.bookings
  for each row execute function public.check_slot_free();

-- ---- One buyer per item ----------------------------------------------
-- A booking holds the item (or the copies asked for) until the seller
-- notes sold or unsold. A second buyer at the same second is refused
-- with 'item_taken'.
create or replace function public.check_item_free()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it       jsonb;
  total    int;
  sold     int;
  held     int;
  reserved int;
  wanted   int := coalesce(new.quantity, 1);
begin
  -- A booking always starts without an outcome.
  new.outcome := null;
  new.sale_price := null;

  if new.item_id is null then
    return new;
  end if;

  -- Locks the item: simultaneous bookings go one after the other.
  select to_jsonb(i) into it
    from items i
   where i.id::text = new.item_id::text
     for update;

  if it is null then
    return new;
  end if;

  total    := greatest(1, coalesce((it ->> 'quantity')::int, 1));
  sold     := case when it ->> 'status' = 'sold' then total
                   else least(total, coalesce((it ->> 'sold_qty')::int, 0)) end;
  reserved := greatest(0, coalesce((it ->> 'reserved_qty')::int, 0));

  select coalesce(sum(coalesce(b.quantity, 1)), 0) into held
    from bookings b
   where b.item_id::text = new.item_id::text
     and coalesce(b.status, '') <> 'declined'
     and b.outcome is null;

  if wanted > total - sold - held - reserved then
    raise exception 'item_taken' using hint = 'This item is already booked or sold.';
  end if;

  return new;
end;
$$;

drop trigger if exists check_item_free on public.bookings;
create trigger check_item_free
  before insert on public.bookings
  for each row execute function public.check_item_free();


-- =====================================================================
--  6. bundles — items sold together at a discount
-- =====================================================================
-- items: [{ "id": …, "count": 1 }]; discount: % off the listed prices.
-- The items stay for sale one by one too.
create table if not exists public.bundles (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title      text not null check (char_length(btrim(title)) between 1 and 160),
  items      jsonb not null default '[]'::jsonb
             check (case when jsonb_typeof(items) = 'array'
                         then jsonb_array_length(items) between 1 and 12
                         else false end),
  discount   int not null default 0 check (discount between 0 and 90)
);

-- The buyer only sends the bundle id: the title and discount are read
-- here, so a buyer cannot make up a discount.
create or replace function public.fill_booking_bundle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bu public.bundles;
begin
  new.bundle_title := null;
  new.bundle_discount := null;

  if new.bundle_id is null then
    return new;
  end if;

  select * into bu from bundles where id = new.bundle_id;

  -- Bundle deleted meanwhile, or an item that is not part of it.
  if not found or not exists (
       select 1 from jsonb_array_elements(bu.items) e
        where e ->> 'id' = new.item_id::text) then
    raise exception 'bundle_gone' using hint = 'This bundle no longer exists.';
  end if;

  new.bundle_title := bu.title;
  new.bundle_discount := bu.discount;
  return new;
end;
$$;

drop trigger if exists fill_booking_bundle on public.bookings;
create trigger fill_booking_bundle
  before insert on public.bookings
  for each row execute function public.fill_booking_bundle();


-- =====================================================================
--  7. contact_requests — "call me back" messages from buyers
-- =====================================================================
-- items: the listings the buyer asks about, copied as they were:
-- [{ "id", "title", "price", "quantity" }].
-- status: 'new' on arrival, 'seen' once read, 'done' once handled.
create table if not exists public.contact_requests (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  first_name text not null check (char_length(btrim(first_name)) between 1 and 60),
  phone      text not null check (char_length(phone) between 4 and 30),
  message    text check (char_length(message) <= 1000),
  items      jsonb not null default '[]'::jsonb
             check (case when jsonb_typeof(items) = 'array'
                         then jsonb_array_length(items) <= 30 and octet_length(items::text) <= 8000
                         else false end),
  status     text not null default 'new' check (status in ('new', 'seen', 'done'))
);

create index if not exists contact_requests_created_at_idx
  on public.contact_requests (created_at desc);


-- =====================================================================
--  8. visits — anonymous stats (no cookies, nothing personal)
-- =====================================================================
-- session: a random number per visit, forgotten when the tab closes.
-- source: the site the visitor came from (facebook.com…).
-- qr: an estimate — arrived on a phone, with no referrer.
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

-- The totals for the Stats tab, computed here. "Today" follows the
-- seller's time zone (settings.time_zone), UTC if it is unknown.
create or replace function public.seller_stats()
returns json
language sql
stable
security invoker
set search_path = public
as $$
  with tz as (
    select coalesce((select n.name
                       from settings s
                       join pg_timezone_names n on n.name = s.time_zone
                      where s.id = 1
                      limit 1), 'UTC') as name
  ),
  v as (
    select visits.*,
           (created_at at time zone tz.name)::date = (now() at time zone tz.name)::date as today
      from visits, tz
     where kind = 'visit'
  )
  select json_build_object(
    'since',        (select min(created_at) from visits),
    'visits',       (select count(*) from v),
    'visits_today', (select count(*) from v where today),
    'qr',           (select count(*) from v where qr),
    'qr_today',     (select count(*) from v where qr and today),
    -- where visits come from: 'qr', a site, or 'phone' / 'computer'
    'sources', (select coalesce(json_agg(s order by s.n desc), '[]'::json) from (
                  select case when qr then 'qr'
                              when source is not null then source
                              when mobile then 'phone'
                              else 'computer' end as source,
                         count(*) as n
                    from v
                   group by 1) s),
    -- per item: shown on screen, and visitors who opened its photos or
    -- started a booking
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


-- =====================================================================
--  9. What visitors may see — without names or phone numbers
-- =====================================================================
-- Recreated each time: older installs may have other columns.
drop view if exists public.busy_slots;
drop view if exists public.booked_items;

-- Times already taken, for the buyers' calendar.
create view public.busy_slots as
  select b.day, b.slot
    from public.bookings b
   where coalesce(b.status, '') <> 'declined';

-- Copies held by a booking in progress, per item.
create view public.booked_items as
  select b.item_id,
         sum(coalesce(b.quantity, 1))::int as qty
    from public.bookings b
   where b.item_id is not null
     and coalesce(b.status, '') <> 'declined'
     and b.outcome is null
   group by b.item_id;


-- =====================================================================
--  10. Row Level Security
-- =====================================================================
-- Every rule is rewritten from scratch: older installs had rules under
-- other names, which this removes first.
do $$
declare
  p record;
begin
  for p in
    select policyname, tablename
      from pg_policies
     where schemaname = 'public'
       and tablename in ('settings', 'items', 'item_photos', 'bookings',
                         'bundles', 'contact_requests', 'visits')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

alter table public.settings         enable row level security;
alter table public.items            enable row level security;
alter table public.item_photos      enable row level security;
alter table public.bookings         enable row level security;
alter table public.bundles          enable row level security;
alter table public.contact_requests enable row level security;
alter table public.visits           enable row level security;

-- ---- Public shop: everyone reads, the seller writes ------------------
create policy "settings are readable by everyone" on public.settings
  for select to anon, authenticated using (true);
create policy "the seller edits settings" on public.settings
  for update to authenticated using (public.is_seller()) with check (public.is_seller());

create policy "items are readable by everyone" on public.items
  for select to anon, authenticated using (true);
create policy "the seller manages items" on public.items
  for all to authenticated using (public.is_seller()) with check (public.is_seller());

create policy "photos are readable by everyone" on public.item_photos
  for select to anon, authenticated using (true);
create policy "the seller manages photos" on public.item_photos
  for all to authenticated using (public.is_seller()) with check (public.is_seller());

create policy "bundles are readable by everyone" on public.bundles
  for select to anon, authenticated using (true);
create policy "the seller manages bundles" on public.bundles
  for all to authenticated using (public.is_seller()) with check (public.is_seller());

-- ---- Private: buyers write, only the seller reads --------------------
create policy "anyone can book a viewing" on public.bookings
  for insert to anon, authenticated with check (status = 'new');
create policy "the seller reads bookings" on public.bookings
  for select to authenticated using (public.is_seller());
create policy "the seller updates bookings" on public.bookings
  for update to authenticated using (public.is_seller()) with check (public.is_seller());
create policy "the seller deletes bookings" on public.bookings
  for delete to authenticated using (public.is_seller());

create policy "anyone can leave a message" on public.contact_requests
  for insert to anon, authenticated with check (status = 'new');
create policy "the seller reads messages" on public.contact_requests
  for select to authenticated using (public.is_seller());
create policy "the seller updates messages" on public.contact_requests
  for update to authenticated using (public.is_seller()) with check (public.is_seller());
create policy "the seller deletes messages" on public.contact_requests
  for delete to authenticated using (public.is_seller());

create policy "anyone can count a visit" on public.visits
  for insert to anon, authenticated with check (true);
create policy "the seller reads visits" on public.visits
  for select to authenticated using (public.is_seller());
-- When the seller signs in, the site deletes their own visit to the shop.
create policy "the seller deletes visits" on public.visits
  for delete to authenticated using (public.is_seller());


-- =====================================================================
--  11. Table and column rights
-- =====================================================================
-- Rules above decide which rows; these decide which tables and columns.
revoke all on public.settings, public.items, public.item_photos, public.bookings,
              public.bundles, public.contact_requests, public.visits,
              public.busy_slots, public.booked_items
  from anon, authenticated;

grant select on public.settings, public.items, public.item_photos, public.bundles
  to anon, authenticated;
grant update on public.settings to authenticated;
grant insert, update, delete on public.items, public.item_photos, public.bundles
  to authenticated;

-- Buyers fill in only these columns of a booking.
grant insert (item_id, item_title, first_name, phone, payment, day, slot, status,
              quantity, cart_id, bundle_id)
  on public.bookings to anon, authenticated;
grant select, update, delete on public.bookings to authenticated;

grant insert (first_name, phone, message, items) on public.contact_requests
  to anon, authenticated;
grant select, delete on public.contact_requests to authenticated;
grant update (status) on public.contact_requests to authenticated;

grant insert on public.visits to anon, authenticated;
grant select, delete on public.visits to authenticated;

grant select on public.busy_slots, public.booked_items to anon, authenticated;


-- =====================================================================
--  12. Real-time: the open seller space hears new bookings and messages
-- =====================================================================
do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    return;
  end if;
  foreach t in array array['bookings', 'contact_requests'] loop
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime'
                      and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;


-- =====================================================================
--  Done
-- =====================================================================
update public.settings set schema_version = 1 where id = 1;

-- The site sees the new tables and columns right away.
notify pgrst, 'reload schema';

select case
         when exists (select 1 from public.seller)
           then 'Up to date (version 1). Your seller account is ready: open your site and add #admin to its address.'
         else 'Installed (version 1). Next: create your seller account in Authentication → Users → Add user.'
       end as result;
