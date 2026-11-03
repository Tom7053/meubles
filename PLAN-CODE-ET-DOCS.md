# À faire : code allégé et documenté, base en un clic, README anglais

> Écrit le 2 novembre 2026. Ce fichier détaille les étapes 1 et 8 de
> [PLAN-OPEN-SOURCE.md](PLAN-OPEN-SOURCE.md) et ajoute le ménage du code.
> Comme pour ce plan, tout se fait dans le **nouveau dépôt**, jamais sur le site de ta vente
> en cours.

## Comment s'en servir

- Les parties se font **dans l'ordre** : la base d'abord, parce que le ménage du code en
  dépend (partie 2).
- **Une tâche = un commit**, avec un message qui dit ce qu'il fait (« Move the shop into
  src/shop », pas « maj »). Coche la case quand c'est poussé.
- **Ranger n'est pas changer** : pendant les parties 2 et 3, le site doit se comporter
  exactement pareil. Une amélioration repérée en chemin va dans une tâche à part.
- Après chaque tâche, la liste de vérifications de [CONTRIBUTING.md](CONTRIBUTING.md#before-opening-a-pull-request) :
  boutique et espace vendeur, en anglais et en français, sur téléphone et ordinateur,
  console sans erreur.

### Où on part

| | Aujourd'hui |
|---|---|
| `index.html` | 6 984 lignes, 360 Ko, toute l'application dans un seul fichier |
| Plus gros morceaux | `ItemsPanel` 690 lignes, générateur de descriptions 485, `BookingSheet` 430, liste des pays 228 |
| Commentaires | 465 lignes de `//` et les blocs `/* */`, presque tout en français |
| Code de compatibilité | 64 lignes renvoient à une migration (« avant migration-x.sql… ») |
| Base de données | `schema.sql` absent du dépôt, puis 10 migrations à lancer dans l'ordre |
| Fichiers morts | `app.jsx` (60 Ko), `affiche.html`, le PDF, `probleme.png`, `probleme2.png` |
| Chargé par chaque visiteur | Babel (3,2 Mo non compressé) pour compiler le JSX dans le navigateur, Tailwind CDN |

---

## Partie 1 — La base de données en une fois

Le but : un nouveau vendeur colle **un seul fichier** dans Supabase, ou mieux, le site le
guide tout seul.

### 1.1 Retrouver le schéma de départ

`schema.sql` n'est plus dans le dépôt, mais ta base Supabase le contient. On le recopie
depuis elle, **structure seulement, jamais les données** (prénoms et numéros des acheteurs).

- [ ] Installer le client PostgreSQL (Windows : installeur de postgresql.org, cocher
      seulement « Command Line Tools »). Sa version doit être au moins celle de la base
      (Supabase → Database → Settings).
- [ ] Récupérer l'adresse de connexion : Supabase → **Connect** → **Session pooler**. Le
      mot de passe est celui de la base, notée à la création (sinon : Database → Settings →
      Reset database password).
- [ ] Exporter la structure du schéma `public` :

  ```bash
  pg_dump --schema-only --schema=public --no-owner \
    "postgresql://postgres.XXXX:MOT-DE-PASSE@aws-0-eu-central-1.pooler.supabase.com:5432/postgres" \
    > schema-export.sql
  ```

- [ ] **Ne pas reprendre** les fonctions d'alerte de cet export (`notify_send_push`,
      `notify_send_resend`, `notify_send_brevo`…) : dans ta base, elles contiennent ton
      sujet ntfy et tes adresses e-mail. Elles viennent de `notifications.sql`, qui garde des
      valeurs à remplacer.
- [ ] Vérifier ce que `pg_dump` peut oublier, dans le SQL Editor :

  ```sql
  -- tables suivies en temps réel
  select tablename from pg_publication_tables where pubname = 'supabase_realtime';
  -- droits donnés aux visiteurs et au vendeur
  select table_name, privilege_type, grantee from information_schema.role_table_grants
   where table_schema = 'public' and grantee in ('anon', 'authenticated') order by 1, 3, 2;
  ```

- [ ] Ne pas publier `schema-export.sql` : il sert seulement de référence pour 1.2.

### 1.2 Écrire `install.sql`

Réécrit à la main à partir de l'export, pour être lisible par un inconnu.

- [ ] Un seul fichier, dans l'ordre : tables, contraintes, vues, fonctions, déclencheurs,
      sécurité (RLS, droits), temps réel, ligne de réglages par défaut (`settings`, `id = 1`,
      valeurs neutres : pas d'adresse, pas d'Odense).
- [ ] **Sans risque à relancer** : `if not exists`, `create or replace`,
      `drop … if exists` avant chaque `create policy` et `add constraint`.
- [ ] Commentaires et noms des règles **en anglais** (« lots visibles par tous » devient
      `"bundles are readable by everyone"`).
- [ ] Une section par table, avec en tête ce que la table contient et qui peut la lire ou
      l'écrire.
- [ ] Termine par `notify pgrst, 'reload schema';` et une requête qui affiche
      « Installed. Next: create your seller account. ».
- [ ] Les colonnes prévues dans PLAN-OPEN-SOURCE.md (devise, pays…) n'y sont **pas
      encore** : elles arriveront avec leur étape, dans `install.sql` et en migration.

### 1.3 Seul le vendeur voit les données

Aujourd'hui, les règles disent « tout compte connecté est le vendeur »
(`to authenticated using (true)`, par exemple `migration-panier.sql:142`). Si quelqu'un
oublie de couper les inscriptions dans Supabase, n'importe qui peut se créer un compte avec
la clé publique et lire tous les numéros de téléphone. En open source, quelqu'un l'oubliera.

- [ ] Une table `seller (user_id uuid primary key references auth.users on delete cascade)`.
- [ ] Un déclencheur sur `auth.users` : le **premier** compte créé devient le vendeur, les
      suivants non.
- [ ] Une fonction `is_seller()` (`security definer`, `search_path = ''`) qui vérifie
      `auth.uid()` dans `seller`.
- [ ] Toutes les règles « vendeur » passent de `using (true)` à `using (public.is_seller())`.
- [ ] Une migration pour les installations existantes, qui inscrit le compte déjà là.
- [ ] Test : un deuxième compte créé dans Authentication ne voit ni rendez-vous, ni
      messages, ni statistiques.

### 1.4 Le site guide l'installation

Quand les tables n'existent pas, l'espace vendeur affiche un écran d'installation au lieu
d'une erreur :

1. **Copier le script** : un bouton qui copie `install.sql` (le site le lit à côté de
   lui sur GitHub Pages, `fetch('install.sql')`).
2. **Ouvrir le SQL Editor** : un lien direct vers
   `https://supabase.com/dashboard/project/<ref>/sql/new`, où `<ref>` est tiré de
   l'adresse Supabase de `config.js`.
3. **Run**, puis **J'ai terminé** : le site vérifie et passe à « Crée ton compte vendeur ».

- [ ] Détecter « pas installé » (erreur `42P01` ou `PGRST205` sur `settings`).
- [ ] L'écran, en anglais et en français.

### 1.5 Les mises à jour des installations existantes

- [ ] Dossier `migrations/` avec des noms numérotés (`001-paiement.sql`, …,
      `010-sites.sql`), puis les nouvelles à la suite. Une installation neuve n'en a pas
      besoin.
- [ ] Une colonne `settings.schema_version` : chaque migration la met à jour, et
      `verifier-supabase.sql` dit « run migrations 012 to 014 ».
- [ ] `verifier-supabase.sql` en anglais.
- [ ] Tester `install.sql` sur un **projet Supabase vide** (un deuxième projet gratuit) :
      `verifier-supabase.sql` doit répondre OK partout.

---

## Partie 2 — Alléger le code

### 2.1 Ménage

- [ ] Supprimer `app.jsx`, `affiche.html`, le PDF, `probleme.png`, `probleme2.png`.
- [ ] Supprimer `migration-planning-par-objet.sql` de la documentation (le fichier n'existe
      plus).
- [ ] Clés Supabase dans `config.js` (valeurs à remplacer), plus dans `index.html`.
- [ ] Versions exactes des bibliothèques : `react@18.3.1`, `react-dom@18.3.1`,
      `@babel/standalone@7.29.12`, `@supabase/supabase-js` à sa version du jour.

### 2.2 Enlever le code de compatibilité

Depuis le début, le site marche même quand une migration n'a pas été lancée : il vérifie
chaque colonne et affiche des encadrés orange « lance migration-x.sql ». Avec
`install.sql`, une installation neuve a tout d'un coup : ce code ne sert plus.

- [ ] Repérer chaque cas : `grep -n "migration-" index.html` (64 lignes), les tests
      `'colonne' in objet`, les drapeaux `manyPhotos`, `bundlesMissing`,
      `messagesMissing`, `sitesReady`, `shopReady`, les encadrés `role="status"`.
- [ ] Les enlever un par un : un commit par migration concernée.
- [ ] Garder une seule vérification au démarrage : si `settings.schema_version` est trop
      ancien, l'espace vendeur dit quelle migration lancer.
- [ ] Le moyen de paiement « MobilePay » retiré (`retired: true`) : gardé seulement s'il
      existe encore des rendez-vous qui l'utilisent.

### 2.3 Découper `index.html` en fichiers

Toujours **sans compilation** : Babel sait lire des fichiers séparés
(`<script type="text/babel" data-presets="react" src="…">`) et les exécute dans l'ordre de
la page. Les fichiers de données sans JSX se chargent avec un `<script>` normal.

```
index.html            ← l'en-tête, les bibliothèques, la liste des scripts, rien d'autre
config.js
install.sql
src/
  core/
    supabase.js       ← client, nettoyage de l'adresse
    i18n.js           ← makeT, LangContext, ShopLangContext
    money.js          ← priceValue, fmtKr, withKr, showPrice, priceFor
    dates.js          ← toKey, fmtDate, monthDays…
    storage.js        ← readStored, writeStored
    stock.js          ← quantités, exemplaires retenus, lots
    stats.js
  data/
    countries.js      ← COUNTRY_LINES, COUNTRY_ALIASES
    description.js    ← KINDS, MATERIALS, COLOURS, FEATURES, FLAWS, CONDITIONS
  ui/
    Icon.jsx, Sheet.jsx, PhoneField.jsx, CountryPicker.jsx, pickers.jsx
  shop/
    Shop.jsx, ItemCard.jsx, BundleCard.jsx, PhotoViewer.jsx,
    CartSheet.jsx, BookingSheet.jsx, ContactSheet.jsx
  admin/
    Admin.jsx, Login.jsx, ItemsPanel.jsx, ItemForm.jsx, BundlesPanel.jsx,
    BookingsPanel.jsx, MessagesPanel.jsx, PlanningPanel.jsx,
    PosterPanel.jsx, StatsPanel.jsx, SettingsPanel.jsx
  App.jsx             ← en dernier : chargement, temps réel, rendu
```

- [ ] **Déplacer sans modifier** : un commit par dossier, le contenu identique au caractère
      près. Les changements viennent dans des commits à part.
- [ ] Tous les fichiers partagent la même portée : deux fichiers ne doivent pas définir le
      même nom.
- [ ] En tête de chaque fichier : ce qu'il définit, et de quels fichiers il a besoin.
- [ ] Viser **400 lignes au plus** par fichier : `ItemsPanel` se coupe en liste + formulaire
      (`ItemForm`), `BookingSheet` en étapes.
- [ ] Le site ne s'ouvre plus en double-cliquant sur `index.html` (le navigateur refuse de
      lire les fichiers à côté) : le README le dit, avec `python3 -m http.server`.

### 2.4 Regrouper ce qui se répète

- [ ] **Enregistrer un réglage** : 4 copies du même schéma (afficher tout de suite,
      enregistrer, revenir en arrière si la base refuse, message d'erreur) dans
      `SettingsPanel` et `PlanningPanel` → une fonction `saveSettings(patch)`.
- [ ] **Stockage du navigateur** : 12 appels directs à `localStorage` / `sessionStorage`,
      chacun avec son `try … catch` → `readStored` / `writeStored` partout.
- [ ] **Prix** : tout passe par `money.js`. C'est là que la devise arrivera (PLAN-OPEN-SOURCE,
      étape 3).
- [ ] Chercher les autres doublons en découpant : fenêtres, boutons « Vendu / Invendu »,
      messages d'erreur Supabase.

### 2.5 Plus tard : ne plus faire télécharger Babel

Chaque visiteur télécharge 3,2 Mo de Babel pour compiler le site sur son téléphone. Une
GitHub Action pourrait compiler une fois à chaque modification et publier le résultat sur
GitHub Pages. Les contributeurs n'auraient toujours rien à installer. À décider après le
découpage, pas avant.

---

## Partie 3 — Le code documenté en anglais

### 3.1 Les commentaires

- [ ] Traduire en anglais, **fichier par fichier, juste après l'avoir déplacé** (2.3) :
      un commit pour déplacer, un autre pour traduire.
- [ ] Garder les commentaires qui disent **pourquoi** (« on lit le lien avant que Supabase
      ne nettoie l'adresse »). Supprimer ceux qui répètent le code.
- [ ] Les exemples en français dans les commentaires (« 450 kr », « Lit + Matelas »)
      deviennent des exemples neutres (« 450 », « Bed + Mattress »).
- [ ] Les textes affichés (`t('…', '…')`) **ne bougent pas** : ce sont des traductions, pas
      des commentaires.
- [ ] Les fichiers SQL aussi : commentaires, noms des règles, messages de
      `verifier-supabase.sql`.

### 3.2 Les mêmes mots partout

Pour que le code, l'interface anglaise et la documentation disent la même chose :

| Français | Anglais | Dans le code |
|---|---|---|
| meuble, annonce | item, listing | `item`, `items` |
| lot | bundle | `bundle` |
| rendez-vous | viewing (pour l'acheteur), booking (dans le code) | `booking` |
| panier | cart | `cart` |
| réservé (hors boutique) | reserved | `reserved_qty` |
| retenu par un rendez-vous | held | `held` |
| espace vendeur | seller space | `Admin` |
| affiche | poster | `Poster…` |
| Réglages | Settings | `settings` |
| message « rappelez-moi » | contact request | `contact_requests` |

- [ ] Ce tableau va dans `ARCHITECTURE.md`.
- [ ] Les noms encore en français changent : `fmtKr` → `formatMoney`, `withKr` →
      `normalizePrice`, clés `meubles-…` du navigateur → préfixe du nom du projet.
      `#vendeur` reste accepté à côté de `#admin`.

### 3.3 `ARCHITECTURE.md` (en anglais)

Une page pour comprendre le projet sans lire le code :

- [ ] **Vue d'ensemble** : un schéma. GitHub Pages sert les fichiers, Supabase garde les
      données, le navigateur de l'acheteur garde le panier.
- [ ] **Les tables** : à quoi sert chacune, ses colonnes, qui peut lire et écrire (visiteur,
      vendeur).
- [ ] **La vie d'un meuble** : en vente → retenu par un rendez-vous ou réservé ailleurs →
      vendu ou de retour en vente. Les lots et les paniers.
- [ ] **Le temps réel** : ce qui se met à jour tout seul et pourquoi.
- [ ] **Les langues** : langue de la boutique, langue de l'espace vendeur, `t()`.
- [ ] **Les statistiques** : sans cookie, ce qu'on compte, ce qu'on oublie.
- [ ] **L'ordre des fichiers** dans `index.html` et pourquoi.
- [ ] Le glossaire de 3.2.

---

## Partie 4 — Le README en anglais

`README.md` en anglais pour tout le monde. Le README français actuel devient
`README.fr.md`, mis à jour avec les mêmes étapes. Il s'adresse à quelqu'un qui n'a jamais
utilisé GitHub ni Supabase : chaque étape dit où cliquer.

### Plan du README

1. **Le titre et une phrase** : à quoi sert le projet. Une capture ou un GIF avec des
   données inventées.
2. **What you get** : la boutique, la réservation de visite, le panier, les lots, l'affiche
   avec QR code, les statistiques, les alertes. Cinq à huit lignes.
3. **How it works** : la partie demandée, voir ci-dessous.
4. **Install** : les étapes, ci-dessous.
5. **Updating** : récupérer une nouvelle version.
6. **Notifications** (facultatif) : ntfy, Resend, Brevo.
7. **Forgot your password**.
8. **Troubleshooting** : les problèmes déjà rencontrés.
9. **Privacy** : ce qui est gardé, où, et comment tout effacer.
10. **Contributing**, **Code of Conduct**, **License**.

### « How it works » : où vit le site

Ce que l'utilisateur doit comprendre, en mots simples :

- [ ] **Deux services gratuits, deux rôles.** GitHub garde et publie les fichiers du site
      (la page, le code). Supabase garde les données (meubles, photos, rendez-vous,
      messages). Rien d'autre, pas de serveur à soi, rien à payer.
- [ ] **GitHub Pages**, c'est quoi : GitHub publie gratuitement les fichiers d'un dépôt
      comme un site. Chaque modification enregistrée sur la branche `main` est en ligne
      environ une minute plus tard (onglet **Actions**, tâche « pages build and
      deployment »).
- [ ] **L'adresse du site** : `https://<pseudo>.github.io/<nom-du-dépôt>/`. Elle est dans le
      QR code de l'affiche : **choisir le nom du dépôt avant d'imprimer**, le renommer
      change l'adresse et casse les affiches déjà collées.
- [ ] **Ce qui est public** : tout le contenu du dépôt, y compris `config.js`. C'est prévu :
      l'adresse Supabase et la clé `anon` sont faites pour être publiques, ce sont les règles
      de la base qui protègent. Ne jamais y mettre la clé `service_role` ni un mot de passe.
      Les données des acheteurs ne sont **jamais** sur GitHub.
- [ ] **Dépôt public obligatoire** : GitHub Pages est gratuit pour les dépôts publics ;
      un dépôt privé demande un abonnement payant.
- [ ] **Les limites** : 1 Go pour le site et environ 100 Go de trafic par mois. Les photos
      sont servies par Supabase, pas par GitHub : on en est très loin. Côté Supabase,
      500 Mo de base, une photo prend environ 100 Ko.
- [ ] **Après une mise à jour**, un navigateur peut montrer l'ancienne version jusqu'à
      10 minutes (cache de GitHub Pages) : recharger avec `Ctrl + F5`, ou fermer et rouvrir
      l'onglet sur téléphone.
- [ ] **Le réveil de Supabase** : un projet gratuit inutilisé une semaine est mis en pause.
      Le workflow `supabase-keepalive.yml` l'interroge chaque jour. Sur une copie (fork),
      GitHub désactive les workflows au départ : onglet **Actions** → **I understand my
      workflows, go ahead and enable them**. GitHub les coupe aussi après 60 jours sans
      modification du dépôt, en prévenant par e-mail : il suffit de les réactiver.
- [ ] **Nom de domaine à soi** (facultatif) : Settings → Pages → Custom domain, puis un
      enregistrement CNAME chez le fournisseur du domaine, et **Enforce HTTPS**.
- [ ] **Après la vente** : Settings → Pages → **Unpublish site**, ou supprimer le dépôt ;
      puis supprimer le projet Supabase pour effacer les numéros des acheteurs.

### « Install » : les étapes

- [ ] **1. Copy the project** : **Fork** sur la page GitHub du projet. Pourquoi Fork plutôt
      que télécharger : le bouton **Sync fork** récupère ensuite les nouvelles versions.
- [ ] **2. Create a Supabase project** : région la plus proche des acheteurs.
- [ ] **3. Create the database** : coller `install.sql` dans SQL Editor → Run, ou se laisser
      guider par l'écran d'installation du site (1.4).
- [ ] **4. Connect the site** : sur GitHub, ouvrir `config.js` → crayon ✏️ → coller l'adresse
      et la clé `anon` (Supabase → Project Settings → Data API) → **Commit changes**.
- [ ] **5. Turn on GitHub Pages** : Settings → Pages → Source **Deploy from a branch**,
      `main`, `/ (root)` → Save. Attendre une minute.
- [ ] **6. Create your seller account** : Supabase → Authentication → Users → Add user →
      **Auto Confirm User**. Puis couper **Allow new users to sign up** (même avec 1.3,
      autant fermer la porte).
- [ ] **7. Set the Site URL** : Supabase → Authentication → URL Configuration → l'adresse
      GitHub Pages. Sans ça, le lien « mot de passe oublié » renvoie vers `localhost`.
- [ ] **8. Open the seller space** : `https://<pseudo>.github.io/<dépôt>/#admin`, se
      connecter, régler la boutique dans Settings.
- [ ] Chaque étape avec une capture d'écran de l'endroit où cliquer.

### « Updating »

- [ ] Sur la page du fork : **Sync fork** → **Update branch**.
- [ ] Lire les notes de la version (`CHANGELOG.md`) : si une migration est indiquée, la
      lancer dans le SQL Editor. `verifier-supabase.sql` dit ce qui manque.
- [ ] `config.js` n'est jamais modifié par le projet après la v1 : la mise à jour ne crée
      pas de conflit et garde les clés.

### « Troubleshooting »

- [ ] « Supabase est injoignable » : projet en pause → Restore project (et vérifier le
      workflow de réveil).
- [ ] Une modification n'apparaît pas : cache, `Ctrl + F5`.
- [ ] Encadré « run this migration » : lancer le fichier indiqué, puis recharger la page.
- [ ] Le lien de mot de passe oublié mène à `localhost` : Site URL (étape 7).
- [ ] Le QR code mène à la mauvaise adresse : nom du dépôt changé après impression.

---

## Ordre et fin

| # | Partie | Fini quand |
|---|---|---|
| 1 | Base en une fois | un projet Supabase vide s'installe avec `install.sql`, ou depuis l'écran du site, et un deuxième compte ne voit aucune donnée |
| 2 | Code allégé | plus de fichier mort, plus de code « avant migration », aucun fichier au-dessus de 400 lignes, le site se comporte comme avant |
| 3 | Code en anglais | plus un commentaire en français dans `src/` ni dans les `.sql`, `ARCHITECTURE.md` écrit |
| 4 | README anglais | quelqu'un qui n'a jamais utilisé GitHub ni Supabase met sa boutique en ligne en suivant le README, sans aide |

Pour la partie 4, le meilleur test : demander à quelqu'un d'autre de suivre le README
pendant que tu regardes, sans l'aider, et noter chaque endroit où il bloque.
