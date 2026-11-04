# Changelog

What changes from one version to the next, and what sellers need to do. Newest first.

## 1.0.0 — unreleased

The first open-source version. Earlier versions ran one sale, in Danish kroner.

**To update an older install:** replace your files with this version, keep your Supabase
URL and anon key in `config.js`, then run `install.sql` once in the SQL Editor. Your
listings, bookings, messages and settings are kept; the shop keeps Danish kroner and
Revolut + cash until you change them. If you use alerts, run `notifications.sql` again too
(with your topic or addresses).

### Added
- **First steps** at the seller's first sign-in: languages, country, currency, ways to pay,
  shop title and text, last day for viewings, sales goal.
- **Any currency**: prices follow the shop's currency and country (`1.250 kr`, `1 250 €`,
  `$1,250`).
- **Ways to pay** chosen by the seller among 22 (cash, bank transfer, MobilePay, Swish,
  Venmo…), suggested by country.
- **Shop header, last day and goal** in Settings, instead of fixed in the code.
- Buyers' phone numbers start with the shop's country.
- `install.sql`: the whole database in one file, safe to run again, for new and older
  installs.
- Only the first account created is the seller; other accounts see nothing private.
- Screens that guide the setup: `config.js` not filled in, database missing or outdated,
  signed in with another account.
- Alerts (`notifications.sql`) in the seller space language, English or French.
- `LICENSE` (MIT), `SECURITY.md`, `ROADMAP.md`, this changelog, an English README.

### Changed
- The Supabase URL and key live in `config.js`: updating `index.html` keeps them.
- Libraries load at exact versions (React 18.3.1, Babel 7.29.10, supabase-js 2.117.3,
  Tailwind 3.4.17).
- The keep-alive workflow reads `config.js`.
- Stats count "today" in the seller's time zone.

### Removed
- The ten `migration-*.sql` files, `verifier-supabase.sql` and `reset-mot-de-passe.sql`:
  `install.sql` replaces them, and the README has the password reset query.
- `app.jsx` and `affiche.html`, no longer used.
