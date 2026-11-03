# Contributing

Thanks for wanting to help!

This project is a small, free shop for selling your furniture when you move out. Buyers
browse the listings, book a viewing or leave their number. The seller manages listings,
bookings and messages, prints a poster with a QR code and follows simple stats. It is one
static page on GitHub Pages, with the data in the seller's own Supabase project.

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## What the project stays

Please keep these in mind before proposing a change. They are why the project exists.

- **Free to run.** GitHub Pages and the Supabase free tier, nothing else to pay for.
- **No build step.** `index.html` runs as it is: React, Tailwind and supabase-js load from a
  CDN and Babel compiles in the browser. A new dependency needs a good reason, and an issue
  first.
- **One seller per install.** Each seller runs their own copy with their own Supabase
  project. No one's data goes through the maintainers.
- **Buyers' privacy.** Names and phone numbers can only be read by the signed-in seller
  (Row Level Security). No cookies, no third-party trackers.
- **Phone first.** Most buyers arrive by scanning the poster's QR code.
- **Plain words.** Sellers are not developers. Messages say what happened and what to do
  next, without jargon.

## Ways to help

- **Report a bug.** Open an issue with the steps to reproduce it, what you expected, what
  happened, your browser or phone, and a screenshot made with fake data. If it involves the
  database, include what `verifier-supabase.sql` says.
- **Suggest a feature.** Open an issue first and describe the situation it solves: who
  needs it, and when during a sale.
- **Translations.** The site speaks English and French today, both written side by side in
  the code. Fixes to either are welcome. Adding a third language needs the translations to
  move into separate files first (see the roadmap). Help with that is very welcome: open an
  issue so we can split the work.
- **Description phrases.** The seller space writes listing descriptions from a few choices
  (type, material, condition…), without AI. New furniture types and new ways of phrasing
  are welcome, in both languages.
- **Documentation.** Anything that was unclear when you set the project up.

The roadmap is in [PLAN-OPEN-SOURCE.md](PLAN-OPEN-SOURCE.md) (in French for now): settings
for currency, country and languages, a single install script, and more.

## Set up a development copy

1. **Fork and clone** the repository.
2. **Create your own Supabase project** on [supabase.com](https://supabase.com) (free).
   Never point a development copy at someone else's project.
3. **Create the tables.** In Supabase, **SQL Editor → New query**, paste each file and
   **Run**, in this order:

   1. `schema.sql`
   2. `migration-paiement.sql`
   3. `migration-quantite.sql`
   4. `migration-photos.sql`
   5. `migration-stats.sql`
   6. `migration-prix-vente.sql`
   7. `migration-reservation.sql`
   8. `migration-panier.sql`
   9. `migration-langue.sql`
   10. `migration-lots.sql`
   11. `migration-sites.sql`

   `notifications.sql` is optional (push or e-mail alerts for the seller). Then run
   `verifier-supabase.sql`: every line should say `OK`.

   > **Known gap:** `schema.sql` is not in the repository at the moment. Replacing it and
   > the migrations with a single `install.sql` is the first step of the roadmap, and the
   > most useful thing to help with right now.

4. **Create a seller account.** **Authentication → Users → Add user → Create new user**,
   tick **Auto Confirm User**. Then, in **Authentication → Sign In / Providers**, turn off
   **Allow new users to sign up**.
5. **Connect the page.** In **Project Settings → Data API**, copy the Project URL and the
   `anon` public key into `window.CONFIG` near the top of `index.html`. Never use the
   `service_role` key. Keep this change out of your pull requests (stage your work with
   `git add -p`).
6. **Serve the folder** and open it:

   ```bash
   python3 -m http.server 8000
   ```

   The shop is at `http://localhost:8000`, the seller space at
   `http://localhost:8000/#vendeur`. Visits from `localhost` are not counted in the stats.
7. **Add a few listings with made-up data.**

## How the code is organised

| File | What it is |
|---|---|
| `index.html` | The whole app. Configuration at the top, then one `<script type="text/babel">` |
| `migration-*.sql` | One file per database change, run once by each seller |
| `verifier-supabase.sql` | Read-only check: one line per feature, `OK` or which file to run |
| `notifications.sql` | Optional alerts (ntfy push, Resend or Brevo e-mail) sent by database triggers |
| `reset-mot-de-passe.sql` | Template to reset the seller password; keep the placeholders |
| `.github/workflows/supabase-keepalive.yml` | Daily request so Supabase doesn't pause the project |
| `app.jsx`, `affiche.html` | Old versions, unused. Don't edit them |

Inside `index.html`, sections start with comments such as
`/* ------ langues ------ */`. The main components:

- `App` loads the data and listens for realtime changes.
- `Shop` is the buyer side: `ItemCard`, `BundleCard`, `CartSheet`, `BookingSheet`,
  `ContactSheet`.
- `Admin` is the seller space, one panel per tab: `ItemsPanel`, `BundlesPanel`,
  `BookingsPanel`, `MessagesPanel`, `PlanningPanel`, `PosterPanel`, `StatsPanel`,
  `SettingsPanel`.

Search for a component by name: line numbers move often.

## Conventions

### Text and languages

- Every visible string exists in both languages, English first:
  `t('Book a viewing', 'Réserver une visite')`.
- `const t = useT()` speaks the language of the side the component belongs to (shop or
  seller space). Text written in the seller space but read by buyers (listing titles,
  descriptions, the poster) uses the shop language: `makeT(useShopLang())`.
- Dates and numbers go through `Intl` with `t.locale`. Don't build them by hand.
- Prices go through the existing helpers (`showPrice`, `priceFor`, `fmtKr`). Currency
  handling is going to change, and keeping it in one place makes that possible.
- Keep sentences short and concrete. In French, the seller space says « tu ».

### Database changes

Every change ships as a new `migration-<topic>.sql`:

- **Safe to run twice**: `add column if not exists`, `create table if not exists`,
  `create or replace function`, `drop constraint if exists` before `add constraint`.
- **A header comment** in plain words: what it adds, and how to run it (SQL Editor → New
  query → Run).
- **Ends with** `notify pgrst, 'reload schema';` so the site sees new columns at once.
- **Row Level Security** on every new table. Anonymous visitors get only what they need,
  with column-level grants where possible (see `contact_requests` in
  `migration-panier.sql`).
- **Add a line** to `verifier-supabase.sql` and a row to the table in `README.md`.

### The site must keep working before the migration is run

Sellers update `index.html` and run migrations whenever they get to it, sometimes days
apart. The code checks for what's missing and carries on without it:

- a new column: `'link_sites' in settings`;
- a new table: the query's error means "not installed" (see `fetchBundles`);
- in the seller space, an amber note names the file to run; in the shop, the feature is
  simply not shown.

### Browser storage

Wrap every `localStorage` and `sessionStorage` call in `try … catch`: they throw in some
private windows. Use them only for conveniences on one device (the cart, the poster's
choices). Anything the seller expects to find on another device goes in the database.

### Interface

- Tailwind classes. Custom CSS goes in the `<style>` block, only when Tailwind can't do it.
- Check at phone width (375 px) as well as on a computer.
- Buttons with only an icon need an `aria-label`. Sheets and dialogs use `role="dialog"`
  and `aria-modal="true"`.
- Comments explain why, not what. Most are in French today; English is welcome in new code,
  as the project is moving to English.

## Before opening a pull request

There are no automated tests yet, so check by hand:

- [ ] The shop and the seller space, in English and in French (Settings tab).
- [ ] At phone width and on a computer.
- [ ] No errors in the browser console.
- [ ] Database change: the site works before the migration and after it, the migration
      runs twice without error, and `verifier-supabase.sql` says `OK`.
- [ ] Poster change: print preview on A4, one and two per sheet.
- [ ] No keys, passwords, real names, phone numbers or addresses in the diff or the
      screenshots.

Then:

- One topic per pull request.
- Say what changes and why, and link the issue.
- Add before and after screenshots for anything visible, with made-up data.
- List any migration sellers need to run.
- Write commit messages that describe the change ("Add a currency setting"), not
  "update".

## Security

- Never commit a `service_role` key, a password or buyers' data.
- Found a vulnerability, such as a way for a visitor to read buyers' phone numbers? Don't
  open a public issue. Report it privately on GitHub: **Security tab → Report a
  vulnerability**.

## License

By contributing, you agree that your contributions are released under the project's
license, in [LICENSE](LICENSE).
