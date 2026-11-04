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
  database, include the message the seller space or the SQL Editor shows.
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

What's planned is in [ROADMAP.md](ROADMAP.md): languages in separate files, prices as
numbers, splitting `index.html`, and more. Pick an item, open an issue to say you're on it.

## Set up a development copy

1. **Fork and clone** the repository.
2. **Create your own Supabase project** on [supabase.com](https://supabase.com) (free).
   Never point a development copy at someone else's project.
3. **Create the tables.** In Supabase, **SQL Editor → New query**, paste `install.sql` and
   **Run**. `notifications.sql` is optional (push or e-mail alerts for the seller).
4. **Create a seller account.** **Authentication → Users → Add user → Create new user**,
   tick **Auto Confirm User**. The first account is the seller. Then, in
   **Authentication → Sign In / Providers**, turn off **Allow new users to sign up**.
5. **Connect the page.** In **Project Settings → Data API**, copy the Project URL and the
   `anon` public key into `config.js`. Never use the `service_role` key. Keep this change
   out of your pull requests: `git update-index --skip-worktree config.js` makes git
   ignore it on your machine.
6. **Serve the folder** and open it:

   ```bash
   python3 -m http.server 8000
   ```

   The shop is at `http://localhost:8000`, the seller space at
   `http://localhost:8000/#admin`. Visits from `localhost` are not counted in the stats.
7. **Go through First steps, then add a few listings with made-up data.** To see First
   steps again, run `update public.settings set setup_done = false;` in the SQL Editor.

## How the code is organised

| File | What it is |
|---|---|
| `index.html` | The whole app: libraries, styles, then one `<script type="text/babel">` |
| `config.js` | The seller's Supabase URL and anon key. The project never changes it after 1.0 |
| `install.sql` | The whole database, safe to run again: new installs and updates |
| `notifications.sql` | Optional alerts (ntfy push, Resend or Brevo e-mail) sent by database triggers |
| `about/` | The project's presentation page |
| `.github/workflows/supabase-keepalive.yml` | Daily request so Supabase doesn't pause the project |

Inside `index.html`, sections start with comments such as
`/* ------ langues ------ */`. The main components:

- `App` loads the data and listens for realtime changes.
- `Shop` is the buyer side: `ItemCard`, `BundleCard`, `CartSheet`, `BookingSheet`,
  `ContactSheet`.
- `Admin` is the seller space, one panel per tab: `ItemsPanel`, `BundlesPanel`,
  `BookingsPanel`, `MessagesPanel`, `PlanningPanel`, `PosterPanel`, `StatsPanel`,
  `SettingsPanel`. Before them, the set-up screens: `NotConfigured`, `DatabaseScreen`,
  `NotSeller` and `FirstSteps`.
- `SHOP` holds what plain helpers need from the settings (currency, country, last day,
  goal). `App` fills it on every render.

Search for a component by name: line numbers move often.

## Conventions

### Text and languages

- Every visible string exists in both languages, English first:
  `t('Book a viewing', 'Réserver une visite')`.
- `const t = useT()` speaks the language of the side the component belongs to (shop or
  seller space). Text written in the seller space but read by buyers (listing titles,
  descriptions, the poster) uses the shop language: `makeT(useShopLang())`.
- Dates and numbers go through `Intl` with `t.locale`. Don't build them by hand.
- Money goes through the helpers: `formatMoney(n)` for an amount, `priceText(raw)` and
  `showPrice(raw, lang)` for a price as typed, `currencySymbol()` next to a price field.
  Never write a currency sign by hand.
- Keep sentences short and concrete. In French, the seller space says « tu ».

### Database changes

Every change goes into `install.sql`, which sellers run again after each update:

- **Safe to run again**, on a new project and on an older install: `add column if not
  exists` (also in the "Older installs" block of the table), `create table if not exists`,
  `create or replace function`, `drop constraint if exists` before `add constraint`.
- **Comments in plain English**: what a table holds, who can read or write it.
- **Row Level Security** on every new table, with its rules in section 10: visitors get
  only what they need, the seller is `public.is_seller()`. Column-level grants where
  possible (see `bookings` and `contact_requests` in section 11).
- **Raise the version**: `schema_version` at the end of `install.sql` and
  `SCHEMA_VERSION` in `index.html`, so older databases are asked to update.
- **Add a line to `CHANGELOG.md`** saying sellers must run `install.sql` again.

### Between the update and `install.sql`

Sellers update the site and run `install.sql` whenever they get to it, sometimes days
apart. Meanwhile the shop must keep working, and the seller space asks for the update
(`DatabaseScreen`, from `settings.schema_version`). A new feature can simply be hidden in
the shop until its column exists (`'link_sites' in settings`). Older checks of this kind
are still in the code; removing them is on the roadmap.

### Browser storage

Wrap every `localStorage` and `sessionStorage` call in `try … catch`: they throw in some
private windows. Use them only for conveniences on one device (the cart, the poster's
choices). Anything the seller expects to find on another device goes in the database.

### Interface

- Tailwind classes. Custom CSS goes in the `<style>` block, only when Tailwind can't do it.
- Check at phone width (375 px) as well as on a computer.
- Buttons with only an icon need an `aria-label`. Sheets and dialogs use `role="dialog"`
  and `aria-modal="true"`.
- Comments explain why, not what, in English. Many older ones are still in French:
  translating a file you're working on is welcome, in its own commit.

## Before opening a pull request

There are no automated tests yet, so check by hand:

- [ ] The shop and the seller space, in English and in French (Settings tab).
- [ ] At phone width and on a computer.
- [ ] No errors in the browser console.
- [ ] Database change: `install.sql` runs twice without error on a new project and on an
      older install, and the site works before and after it.
- [ ] Money: try a shop in another currency and country (Settings), e.g. EUR in France
      and USD in the United States.
- [ ] Poster change: print preview on A4, one and two per sheet.
- [ ] No keys, passwords, real names, phone numbers or addresses in the diff or the
      screenshots.

Then:

- One topic per pull request.
- Say what changes and why, and link the issue.
- Add before and after screenshots for anything visible, with made-up data.
- Say if sellers need to run `install.sql` again.
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
