# møbel — everything must go

A free little shop for selling your furniture when you move out. Share one link in your
community groups, stick a poster with a QR code in the hallway, and let buyers book their
own viewings. No server to run, nothing to pay: one web page on GitHub Pages, your data in
your own free Supabase project.

The shop speaks English or French, in the currency of your choice. You pick both the
first time you sign in.

## What you get

- **A shop for your buyers**, made for phones: photos, prices, search, a cart.
- **Viewings that book themselves**: buyers pick a day and a time from your schedule,
  leave a first name and a phone number, and say how they will pay. One item, a cart of
  several, or a bundle — always one viewing.
- **"Call me back" messages** for buyers who have a question first.
- **Bundles**: several items sold together at a discount.
- **A seller space** for your listings, bookings, messages and schedule. Descriptions
  write themselves from a few choices (type, material, condition…), without AI.
- **A printable poster** with your prices and a QR code to the shop.
- **Simple stats**, without cookies: visits, QR code scans, most viewed items.
- **Alerts** on your phone or by e-mail when someone books (optional).

## How it works

Two free services, two jobs:

| | Keeps | Is |
|---|---|---|
| **GitHub** | the site's files (`index.html`, `config.js`) | public |
| **Supabase** | your data: listings, photos, bookings, messages | private where it matters |

**GitHub Pages** publishes the files of a GitHub repository as a website, for free. Every
change saved on the `main` branch is online about a minute later. Your shop's address is
`https://<your-username>.github.io/<repository-name>/`.

> **Choose the repository name before printing the poster.** The QR code holds the
> address: renaming the repository changes it, and posters already up stop working.

**What is public, and why it is fine.** Everything in the repository is public, `config.js`
included. That is by design: the Supabase address and its `anon` key are meant to be
public. What protects your data are the rules installed by `install.sql`: anyone can read
the listings and book a viewing, but **only your seller account can read buyers' names and
phone numbers**. Buyers' data never goes to GitHub. Never put the `service_role` key or a
password in the repository.

**The repository must be public**: GitHub Pages is free for public repositories only.

**Limits.** GitHub Pages: 1 GB for the site and about 100 GB of traffic a month. Photos are
served by Supabase, not GitHub, so you will be far from it. Supabase's free plan: 500 MB of
database; a photo takes about 100 KB.

**Supabase falls asleep.** Free projects are paused after a week without activity. The
workflow in `.github/workflows/supabase-keepalive.yml` reads one row every day to keep yours
awake. On a fork, GitHub turns workflows off at first: open the **Actions** tab and click
**I understand my workflows, go ahead and enable them**. GitHub also turns scheduled
workflows off after 60 days without a commit, after warning you by e-mail: turn it back on
in the same tab.

## Install

About 15 minutes. You need a GitHub account and a Supabase account (both free).

### 1. Copy the project

On this repository's GitHub page, click **Fork** (top right). Forking rather than
downloading lets you get new versions later with one button (see [Updating](#updating)).

### 2. Create a Supabase project

On [supabase.com](https://supabase.com), **New project**. Pick the region closest to your
buyers. Write the database password down somewhere: you will not need it afterwards.

### 3. Create the database

In Supabase: **SQL Editor → New query**. Paste the whole content of
[`install.sql`](install.sql) and click **Run**. The result says what to do next.

### 4. Create your seller account

**Authentication → Users → Add user → Create new user**. Your e-mail, a password, and tick
**Auto Confirm User**. The first account created is the seller: only it can read bookings,
messages and stats.

Then **Authentication → Sign In / Providers**: turn off **Allow new users to sign up**.
Other accounts would see nothing private anyway, but there is no reason to leave the door
open.

### 5. Connect the site to Supabase

In Supabase, **Project Settings → Data API**: copy the **Project URL** and the **anon
public** key. On GitHub, open `config.js` in your fork, click the pencil ✏️, paste both
values in place of `https://YOUR-PROJECT.supabase.co` and `YOUR-ANON-KEY`, then **Commit
changes**.

### 6. Put the site online

On GitHub, in your fork: **Settings → Pages → Source: Deploy from a branch**, branch
`main`, folder `/ (root)`, **Save**. A minute later (the **Actions** tab shows "pages build
and deployment"), the shop is online at `https://<your-username>.github.io/<repository-name>/`.

### 7. Tell Supabase where the site is

**Authentication → URL Configuration → Site URL**: paste the address of step 6, **Save**.
Without it, the "forgot password" link sent by e-mail leads to `localhost`.

### 8. Open your seller space

Go to `https://<your-username>.github.io/<repository-name>/#admin` (bookmark it on your
phone) and sign in with the account of step 4. **First steps** asks three things:

1. **Languages**: yours (for the seller space) and the shop's (what buyers read).
2. **Where you sell**: your country, which suggests the **currency** and the usual ways
   to pay. Change any of them.
3. **Your shop**: the title and the few words buyers read first, an optional last day for
   viewings and an optional sales goal.

All of it stays editable in **Settings**. Then add your first listing, set your opening
days in **Schedule**, and print the **Poster**.

## Using it

**Buyers** see each item with **Book a viewing**, **Add to cart** and **Contact me**. A
cart books one viewing for several items: only the days and times when all of them can go
are offered. Nothing is reserved until the booking is made; if someone was faster, the
cart updates and nothing is booked.

**The seller space** has eight tabs:

- **Listings** — add, edit, mark as sold or reserved elsewhere (Marketplace…). Up to 8
  photos each. Several identical items (2 chairs): set the quantity. **Mark as sold** asks the
  price you actually got, for when you haggled.
- **Bundles** — items sold together at a discount. They stay for sale one by one too.
- **Bookings** — with the phone number one tap away. A booked item leaves the shop until you
  note **Sold** or **Unsold** after the viewing.
- **Messages** — buyers who want to be called back.
- **Schedule** — opening days, times, closed days, pickup address.
- **Poster** — pick the items to show, edit any text by clicking it, print on A4 (one or
  two per sheet).
- **Stats** — visits, estimated QR code scans, interest per item. Your own visits are not
  counted.
- **Settings** — languages, country, currency, ways to pay, shop header, last day, goal,
  and the other sites you post on.

**Changing the currency** does not convert prices you already typed: `450` stays `450`, in
the new currency. **Changing the shop language** does not translate listings already
written: open one and click **Rewrite** to redo its description.

## Updating

1. On your fork's GitHub page: **Sync fork → Update branch**. Your `config.js` is kept.
2. Read [`CHANGELOG.md`](CHANGELOG.md). If it says so, run `install.sql` again in the SQL
   Editor: it is safe to run as many times as you like and never deletes your data.

If the database is older than the site, the seller space says so and shows the steps.

## Alerts (optional)

While the seller space is open, new bookings and messages pop up live. To be told with the
site closed, run [`notifications.sql`](notifications.sql) in the SQL Editor, with one of:

- **ntfy** — a push notification on your phone. Free, no account, 2 minutes.
- **Resend** — an e-mail to yourself. Free up to 3,000 e-mails a month.
- **Brevo** — e-mails to several people. Free up to 300 a day.

The file explains each one step by step. Alerts come in your seller space language.

## Forgot your password

- **From the site**: sign-in screen → **Forgot your password?** → your e-mail. It needs the Site
  URL of step 7. Supabase's built-in e-mail service only sends a few e-mails an hour.
- **Directly in Supabase**, instantly: in the SQL Editor, run this with your e-mail and a
  new password (and don't save it anywhere public):

  ```sql
  update auth.users
     set encrypted_password = extensions.crypt('NEW-PASSWORD', extensions.gen_salt('bf')),
         updated_at = now()
   where email = 'you@example.com'
  returning email;
  ```

  No row returned? The e-mail is not the right one: `select email from auth.users;` lists
  them.

This is the password of your seller account (Authentication → Users), not of your
supabase.com account, nor the database password.

## Troubleshooting

| What you see | What to do |
|---|---|
| "Almost there: this shop is not connected" | `config.js` still has its placeholders (step 5). |
| "Supabase can't be reached" at sign-in, or an empty shop | The project is paused: on supabase.com, open it and click **Restore project**. Then check the keep-alive workflow is on. |
| "Create the database" / "Update the database" | Run `install.sql` in the SQL Editor, then click **Done, check again**. |
| "Not the seller's account" | You signed in with an account created after the seller's. Use the first one. |
| A change does not show up | GitHub Pages caches for up to 10 minutes. Reload with `Ctrl + F5`, or close and reopen the tab on a phone. |
| The password reset link leads to `localhost` | Set the Site URL (step 7). |
| The poster's QR code leads to the wrong address | The repository was renamed after printing. Print again. |

## Privacy

- Buyers' first names and phone numbers are stored only in **your** Supabase project, and
  only your seller account can read them. Nothing goes through the people who make møbel.
- Stats use no cookies and no third-party tools: a random number per visit, forgotten when
  the tab closes.
- **After the sale**, delete what you no longer need: bookings and messages in the seller
  space, or the whole Supabase project (**Project Settings → General → Delete project**).
  To take the site down: GitHub **Settings → Pages → Unpublish site**, or delete the
  repository.

## Test it on your computer

From the project folder:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000` (and `http://localhost:8000/#admin` for the seller
space). Use your own Supabase project in `config.js`, never someone else's.

## Contributing

Bug reports, translations, new description phrases and fixes are welcome. Start with
[CONTRIBUTING.md](CONTRIBUTING.md); what's planned is in [ROADMAP.md](ROADMAP.md). Everyone
taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Found a security problem?
See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE): use it, change it, share it.
