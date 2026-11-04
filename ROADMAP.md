# Roadmap

Where møbel is going. The goal: anyone, anywhere, selling their furniture before a move
can fork the project, create a free Supabase project, fill in `config.js`, set everything
else from the seller space, and never touch the code.

What stays the same: a free static site (GitHub Pages + Supabase's free plan), no server,
no build step for contributors, one seller per install.

Want to help with an item? Open an issue first so we can split the work. Each step below
leaves the site working.

## Done in 1.0

- One `install.sql` for new and older installs, safe to run again.
- Only the first account is the seller (`is_seller()`).
- Supabase keys in `config.js`; libraries at exact versions; MIT license.
- First steps at the first sign-in: languages, country, currency, ways to pay, shop
  header, last day, goal. All editable in Settings.
- Any currency, formatted for the shop's language and country.
- Alerts in the seller space language.

## Next

### 1. Languages in separate files

Today every string is written in place, English then French: `t('Book a viewing',
'Réserver une visite')` — about 650 calls. Adding German means touching all of them.

- `locales/en.json` (reference, always complete), `locales/fr.json`, one file per new
  language, and `locales/index.json` listing them.
- `t('book.cta')`, with variables (`t('booking.held', { name, date })`), plurals through
  `Intl.PluralRules`, and `<b>…</b>` tags for the dozen strings that hold markup.
- A missing key falls back to English, with a warning in the console.
- A one-off Node script extracts the existing calls into `en.json` and `fr.json`.
- What the browser already knows comes from `Intl`: weekday and month names (the `DAYS`
  table goes), country names, dates, numbers, 12- or 24-hour times.
- Right-to-left languages later: `dir="rtl"` and logical Tailwind classes (`ms-`, `me-`,
  `text-start`). New code can already use them.
- `settings.shop_lang` / `admin_lang` already accept any code (`de`, `pt-BR`).

### 2. Descriptions in every language

The description generator writes English and French sentences, with French gender
agreement. Each language has its own grammar.

- One pack per language (`generator/en.js`, `generator/fr.js`) with its phrases and rules.
  The menus (type, material, condition…) keep the same keys everywhere, so choices saved
  in `items.details` stay valid when the language changes.
- A language without a pack gets a plain list ("Type: table · Material: oak · Condition:
  very good"). Less pretty, never empty.

### 3. Prices as numbers

Prices are text (`'450'`, older `'450 kr'`), read by `priceValue`, which guesses the
thousands separator.

- `items.price_amount numeric(12,2)`, filled once from the text; `price` kept for words
  ("To discuss").
- A number field whose decimal separator follows the language.
- Bundle discounts rounded to the currency's unit instead of whole numbers.

### 4. The rest of "country"

- First day of the week (Sunday in the US), 12-hour clock.
- Poster on Letter paper as well as A4.
- Phone numbers: drop the Danish 8-digit rule, keep the E.164 check (4 to 15 digits).
- Poster texts and choices in the database instead of the browser, to find them on
  another device.

### 5. A lighter `index.html`

7,000 lines in one file today.

- Remove the code that still copes with databases older than `install.sql` (`manyPhotos`,
  `bundlesMissing`, `messagesMissing`, `'column' in object` checks, amber notes): the
  seller space now asks for the update instead.
- Split into files, still without a build step: Babel can load
  `<script type="text/babel" src="…">` in order. `src/core/` (money, dates, i18n…),
  `src/shop/`, `src/admin/`, `src/App.jsx` last. Move first, change after, one commit each.
  Aim for 400 lines per file at most.
- One `saveSettings(patch)` instead of four copies of "save, roll back on error"; one
  `readStored` / `writeStored` for browser storage.
- Comments in English, file by file, as they move.
- `meubles-` browser storage keys and `#vendeur` renamed after the project (`#vendeur`
  still accepted).
- `ARCHITECTURE.md`: tables and who can read them, the life of an item (for sale → held →
  sold or back), real-time, languages, stats, file order, and a glossary:

  | Concept | In the code |
  |---|---|
  | item, listing | `item`, `items` |
  | bundle | `bundle` |
  | viewing (buyer) / booking (code) | `booking` |
  | cart | `cart` |
  | reserved elsewhere | `reserved_qty` |
  | held by a booking | `held` |
  | seller space | `Admin` |
  | poster | `Poster…` |
  | call-back message | `contact_requests` |

### 6. Showing it

- Screenshots and a GIF of the seller space, with made-up data.
- A demo shop: a second Supabase project filled by `demo-seed.sql`.
- A "Delete all bookings and messages" button for the end of a sale.

### 7. Tests

- `install.sql` run on an empty database and on an older one, with
  [PGlite](https://pglite.dev) and stubs for Supabase's `auth` schema and roles: rules,
  triggers and re-runs checked in seconds, in CI.
- A short end-to-end run of the shop and First steps against a mock Supabase client.

### Later, maybe

- Compile once with a GitHub Action instead of shipping Babel (3 MB) to every visitor.
  Contributors would still have nothing to install. To decide after the split.
