-- møbel — donation mode. Run once in Supabase (SQL Editor → New query → Run).
-- Safe to run again: it only adds what is missing.
alter table public.settings add column if not exists donation_mode boolean not null default false;
alter table public.settings add column if not exists donation_until timestamptz;
