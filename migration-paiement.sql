-- =====================================================================
-- Moyen de paiement annoncé à la réservation
-- À lancer une fois dans Supabase : SQL Editor → New query → Run.
-- (Inutile si tu installes tout à neuf avec un schema.sql qui le contient
--  déjà.)
-- =====================================================================

-- La colonne accepte 'mobilepay', 'revolut', ou rien pour les rendez-vous
-- pris avant cette mise à jour.
alter table public.bookings
  add column if not exists payment text;

alter table public.bookings
  drop constraint if exists bookings_payment_check;

alter table public.bookings
  add constraint bookings_payment_check
  check (payment is null or payment in ('mobilepay', 'revolut'));
