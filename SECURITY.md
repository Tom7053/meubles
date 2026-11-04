# Security

møbel keeps buyers' first names and phone numbers. A flaw that lets a visitor read them,
book on someone else's behalf, or change a shop they don't own matters a lot to us.

## Reporting a vulnerability

Please **don't open a public issue**. Report it privately on GitHub: the repository's
**Security** tab → **Report a vulnerability**.

Say what an attacker can do, and how to reproduce it on a fresh install (a new Supabase
project with `install.sql`). Use made-up data only: never real buyers' names or numbers.

We aim to answer within a week, and to fix serious problems before talking about them in
public. We'll credit you in the changelog if you wish.

## What protects the data

- `install.sql` turns on Row Level Security on every table. Visitors can read the shop and
  add bookings, messages and visits; they can never read them back.
- Only the **first account** created in the Supabase project is the seller
  (`public.is_seller()`). Any other signed-in account sees nothing private.
- `config.js` holds only the project URL and the `anon` key, both public by design.

## What sellers should do

- Never put the `service_role` key, a password or buyers' data in the repository.
- Turn off **Allow new users to sign up** in Supabase (Authentication → Sign In /
  Providers) once the seller account exists.
- Use a long, unique password for the seller account.
- Delete bookings and messages, or the whole Supabase project, once the sale is over.

## Supported versions

Only the latest version gets fixes. Update with **Sync fork**, then run `install.sql`
again (see the README).
