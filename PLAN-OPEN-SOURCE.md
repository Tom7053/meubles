# Plan : rendre la boutique open source et universelle

> Écrit le 2 novembre 2026. Ta vente tourne jusqu'au 20 novembre (rendez-vous possibles
> jusqu'au 30) : rien dans ce plan ne touche au site en ligne avant. Tout se fait dans un
> nouveau dépôt (étape 0).

## Le but

N'importe qui, n'importe où, qui vend ses meubles (déménagement, fin de stage,
expatriation) peut :

1. copier le projet, créer un Supabase gratuit, remplir ses deux clés ;
2. choisir dans **Réglages** sa langue, sa devise, son pays, ses moyens de paiement et ses
   sites d'annonces ;
3. ne **jamais** toucher au code.

Ce qui ne change pas : un site statique gratuit (GitHub Pages + Supabase gratuit), sans
serveur, sans compilation, un vendeur par installation.

---

## Étape 0 — Avant tout

### Ton mot de passe vendeur est public

`reset-mot-de-passe.sql` contient ton e-mail et un mot de passe en clair, et le dépôt
`Tom7053/meubles` est **public**. Si c'est toujours ton mot de passe, n'importe qui peut
entrer dans ton espace vendeur : lire les prénoms et numéros des acheteurs, supprimer des
annonces.

1. Change le mot de passe maintenant (écran de connexion → **Mot de passe oublié ?**, ou
   le fichier SQL lancé dans Supabase **sans enregistrer le fichier dans le dépôt**).
2. Remets des valeurs à remplacer dans le fichier (`'NOUVEAU-MOT-DE-PASSE'`,
   `'ton.adresse@example.com'`) et pousse.
3. L'ancien mot de passe reste dans l'historique git, mais une fois changé il ne sert plus
   à rien.

### Ce qui est personnel dans le dépôt

| Quoi | Où |
|---|---|
| Ton adresse | `index.html:261`, `index.html:6113`, le PDF, `probleme.png`, `probleme2.png` |
| Odense, 20 novembre, ton stage | `index.html:6-7`, `1236`, `1691`, `6558-6564` |
| Ton e-mail perso | `reset-mot-de-passe.sql:14`, auteur des commits |
| Ton e-mail pro | auteur de 15 commits |
| URL et clé anon de ton Supabase | `index.html:33-34` : publiques par conception, mais une copie du projet qui les garderait écrirait dans **ta** base |

**Recommandé : un nouveau dépôt, sans historique.** Copie les fichiers, enlève ce qui est
personnel, `git init`, premier commit. L'ancien dépôt reste tel quel pour ta vente ; passe-le
en privé ou supprime-le après le 30 novembre. C'est plus simple et plus sûr que de réécrire
l'historique avec `git filter-repo`.

Dans le nouveau dépôt, utilise l'adresse anonyme de GitHub pour signer les commits
(GitHub → Settings → Emails → `…+Tom7053@users.noreply.github.com`).

---

## Ce qui est figé aujourd'hui

### Langues

- **640 appels `t('anglais', 'français')`** écrits sur place (dont 94 avec des variables
  `${…}` et 12 avec du JSX), plus 12 `tp(…)` sur l'affiche et 13 tests `lang === 'fr'`.
  Ajouter l'allemand, c'est toucher environ 650 lignes.
- `LANGS = ['en', 'fr']` (`index.html:200`), `fr-FR` / `en-GB` en dur (`index.html:206`).
- Jours de la semaine écrits à la main (`DAYS`, `index.html:248`).
- Moyens de paiement en anglais et français (`PAYMENT_METHODS`, `index.html:424`).
- Noms de pays : anglais, plus le français via `Intl` (`index.html:908-925`).
- Générateur de descriptions (`index.html:3638-4123`) : près de 500 lignes de phrases
  anglaises et françaises, avec l'accord en genre du français (`f: true`).
- La base refuse toute autre langue : `check (shop_lang in ('en', 'fr'))`
  (`migration-langue.sql:19-23`).
- Alertes (`notifications.sql`) en français seulement.
- README, commentaires du code et fichiers SQL en français.

### Devise

- `fmtKr` formate en danois avec « kr » (`index.html:284`) ; `withKr` ajoute « kr » à tout
  prix (`index.html:288`).
- Les prix sont **du texte** en base : `items.price = '450 kr'` (`index.html:4601`). Les
  calculs passent par `priceValue`, qui devine le séparateur des milliers : « 1.200 » vaut
  1200, ce qui serait faux pour « 1.20 € ».
- « kr » écrit à côté des champs prix (`index.html:4353`, `4804`, `4888`).
- Objectif de vente de 3000 kr en dur (`SALES_GOAL`, `index.html:270`).

### Pays et lieu

- Téléphone : Danemark par défaut (`index.html:1643`, `2482`), épinglé en haut de la liste
  (`index.html:2356`), règle danoise des 8 chiffres (`index.html:967`, `995`), exemple
  « 12 34 56 78 » (`index.html:2539`).
- Fuseau `Europe/Copenhagen` dans les stats (`migration-stats.sql:69`).
- Semaine qui commence le lundi (`index.html:459`), heures en 24 h.
- Affiche en A4 (`index.html:6351`).
- Paiements Revolut, espèces, MobilePay, imposés aussi par la base
  (`check (payment in (…))`, `migration-paiement.sql:21`). L'affiche a sa propre liste
  (`index.html:6349`).
- Sites d'annonces par défaut DBA, Leboncoin… (`index.html:255`), déjà modifiables dans
  Réglages.

### Ta vente

- Titre « Furniture for sale — Odense », accroche « Moving out of Odense on 20 November »,
  affiche « My internship ends on 20 November ».
- Dernier jour de rendez-vous en dur : `LAST_DAY = '2026-11-30'` (`index.html:414`). Passé
  cette date, plus aucun calendrier ne fonctionne.
- Adresse et paiement par défaut (`index.html:259-266`).
- Textes et choix de l'affiche gardés dans le navigateur (localStorage), pas en base :
  perdus en changeant d'appareil.

### Installation

- **`schema.sql` n'est pas dans le dépôt**, alors que le README commence par lui : une
  installation neuve est impossible aujourd'hui. Même chose pour
  `migration-planning-par-objet.sql`.
- 10 migrations à lancer dans un ordre précis.
- Les clés Supabase sont dans `index.html` : récupérer une nouvelle version du projet
  écrase sa configuration.
- `app.jsx` et `affiche.html` ne servent plus.
- **Pas de licence** : sans elle, personne n'a légalement le droit de réutiliser le code.
- Bibliothèques chargées sans version exacte (`react@18`, `@babel/standalone@7`,
  `supabase-js@2`, Tailwind CDN) : une mise à jour chez eux peut casser le site du jour au
  lendemain.

---

## Ce que ça devient

### « Premiers pas » au premier lancement

Sur une installation neuve, l'espace vendeur ouvre un assistant avant tout le reste :

1. langue de l'espace vendeur et langue de la boutique ;
2. pays, qui propose tout seul la devise, le fuseau, le premier jour de la semaine, le
   format de papier, l'indicatif, les moyens de paiement et les sites d'annonces courants
   dans ce pays ;
3. titre de la vente, ville, accroche, dernier jour, adresse ;
4. objectif de vente (facultatif).

Tout reste modifiable dans Réglages. Les valeurs de départ viennent du navigateur
(`navigator.language`, `Intl.DateTimeFormat().resolvedOptions().timeZone`).

### Nouvelles colonnes de `settings`

| Colonne | Exemple | Remplace |
|---|---|---|
| `country` | `'DK'` | Danemark en dur |
| `currency` | `'DKK'`, `'EUR'`, `'USD'` | « kr » |
| `locale` | `'da-DK'`, `'fr-BE'` | `'da-DK'`, `fr-FR`, `en-GB` en dur |
| `timezone` | `'Europe/Copenhagen'` | le fuseau des stats |
| `week_start` | `1` (lundi) ou `0` (dimanche) | lundi en dur |
| `paper` | `'A4'` ou `'Letter'` | A4 en dur |
| `shop_title`, `city`, `headline` | | Odense, 20 novembre |
| `last_day` | `'2026-11-30'`, ou vide = pas de fin | `LAST_DAY` |
| `sales_goal` | `3000`, ou vide = pas d'objectif | `SALES_GOAL` |
| `payment_methods` | `['MobilePay', 'Cash']` | `PAYMENT_METHODS` et la contrainte en base |
| `poster` | jsonb : textes, choix, format | localStorage de l'affiche |
| `shop_lang`, `admin_lang` | tout code (`'de'`, `'pt-BR'`) | `check in ('en', 'fr')` |

Une boutique = une devise, celle du pays où l'on vend. Pas de conversion pour les
acheteurs. Changer de devise ne convertit pas les prix déjà saisis, et Réglages le dit.

### Les prix en nombres

- Nouvelle colonne `items.price_amount numeric(12,2)` (vide = gratuit). La migration la
  remplit une fois à partir du texte actuel, avec la logique de `priceValue`, et garde
  `price` pour lire les anciennes lignes.
- Le champ prix devient un vrai champ nombre (`inputmode="decimal"`) dont le séparateur
  décimal suit la langue : plus de devinette entre « 1.200 » et « 1.20 ».
- Un seul formateur pour tout le site :

  ```js
  const money = (n, { currency, locale }) => new Intl.NumberFormat(locale, {
    style: 'currency', currency,
    minimumFractionDigits: Number.isInteger(n) ? 0 : undefined,
  }).format(n);
  // da-DK DKK → « 450 kr. »   fr-FR EUR → « 450 € »   en-IE EUR → « €450 »   en-US USD → « $450 »
  ```

- Le symbole à côté des champs prix vient de `formatToParts`, à gauche ou à droite selon
  la langue.
- Les remises des lots s'arrondissent à l'unité de la devise (1 kr, 1 centime, 1 yen) au
  lieu de `Math.round`.

### Les langues dans des fichiers à part

```
locales/
  index.json   ← la liste des langues proposées dans Réglages
  en.json      ← référence, toujours complète
  fr.json
  da.json      ← une nouvelle langue = un fichier
```

- `t('book.cta')` au lieu de `t('Book a viewing', 'Réserver une visite')`.
  - Variables : `t('booking.held', { name, date })` pour `"réservé par {name}, rdv le {date}"`.
  - Pluriels avec `Intl.PluralRules`.
  - Mise en forme (les 12 cas JSX) : balises `<b>…</b>` dans la chaîne, transformées en
    JSX par une petite fonction.
- Une clé qui manque dans une langue s'affiche en anglais, avec un avertissement dans la
  console.
- **Extraction automatique** : un script Node, lancé une fois, relit les 650 appels `t(…)`
  et `tp(…)`, crée les clés et écrit `en.json` et `fr.json`. Les 13 tests
  `lang === 'fr'` se reprennent à la main.
- Ce que le navigateur sait déjà faire passe par `Intl` au lieu d'être traduit : jours et
  mois (`DAYS` disparaît), noms de pays dans toutes les langues (`Intl.DisplayNames`),
  dates, nombres, heures en 12 h ou 24 h.
- Arabe, hébreu : `dir="rtl"` et les classes Tailwind « logiques » (`ms-`, `me-`, `ps-`,
  `pe-`, `text-start`). Pour plus tard, mais écrire les nouvelles classes ainsi dès
  maintenant évite de tout reprendre.

### Le générateur de descriptions

C'est le plus gros morceau : chaque langue a sa grammaire (le français accorde, l'allemand
décline, le danois a deux genres…).

- Un « pack » par langue, `generator/en.js` et `generator/fr.js`, avec les phrases et les
  règles d'accord de cette langue. Les menus (type, matière, état…) gardent les mêmes clés
  dans toutes les langues : les choix enregistrés dans `items.details` restent valables
  quand on change de langue.
- Une langue sans pack : le générateur écrit une description simple, en liste, avec les
  noms traduits de `locales/xx.json` (« Type : table · Matière : chêne · État : très
  bon »). Moins joli, jamais vide.
- `CONTRIBUTING.md` explique comment écrire un pack.

### Téléphone

- Indicatif par défaut = pays des Réglages, en haut de la liste.
- La règle danoise disparaît. On garde la vérification valable partout : 4 à 15 chiffres
  en tout (norme E.164). `libphonenumber-js` validerait chaque pays exactement, mais c'est
  une dépendance lourde pour un gain faible.

### Alertes

`notifications.sql` lit `settings.admin_lang` et prend ses textes dans un petit dictionnaire
SQL (anglais et français au départ, anglais pour les autres langues).

### Installation en une fois

```
index.html
config.js            ← les deux clés, le seul fichier à remplir
locales/
generator/
install.sql          ← tout le schéma à jour, pour une installation neuve
migrations/          ← seulement pour mettre à jour une installation existante
  001-paiement.sql
  002-quantite.sql
  …
  011-universel.sql  ← les nouvelles colonnes de ce plan
verifier-supabase.sql
```

- `config.js` à part : passer à une nouvelle version, c'est remplacer `index.html` sans
  perdre sa configuration.
- `install.sql` remplace `schema.sql` et les 10 migrations. Il reste sans risque à
  relancer, et il est testé sur un projet Supabase vide.
- `verifier-supabase.sql` vérifie aussi les nouvelles colonnes.
- Versions exactes des bibliothèques (`react@18.3.1`…).
- `app.jsx`, `affiche.html`, le PDF et les captures disparaissent.

---

## L'open source

- **Licence MIT** : chacun peut réutiliser, modifier et même vendre le code, en gardant ton
  nom dans la licence. L'alternative, AGPL, oblige ceux qui modifient et hébergent le projet
  à publier leurs changements ; c'est plus contraignant et rarement utile ici.
- **README en anglais** (`README.md`), le français à côté (`README.fr.md`). Le README
  actuel s'adresse à une personne précise (« tu », « alertée ») : il est réécrit pour un
  inconnu qui découvre le projet.
- **Captures avec des données inventées**, et une **démo** : un second projet Supabase
  rempli de meubles fictifs par `demo-seed.sql`, avec la boutique visible par tous. Pour
  l'espace vendeur, un GIF du parcours suffit.
- **`CONTRIBUTING.md`** : ajouter une langue, écrire un pack de descriptions, tester en
  local, ne jamais mettre de clé `service_role`.
- **`SECURITY.md`** : comment signaler une faille sans la publier.
- **Données des acheteurs** : prénoms et numéros restent dans le Supabase de chaque
  vendeur, rien ne passe par toi. Le README le dit, et un bouton « Effacer les rendez-vous
  et messages » sert en fin de vente (RGPD).
- **Commentaires du code** : passés en anglais au fil des étapes, pas d'un coup.
- **Un nom en anglais** pour le projet. Le préfixe `meubles-` des clés localStorage et
  `#vendeur` suivent (`#vendeur` reste accepté).
- Une version `v1.0.0`, avec un `CHANGELOG.md`.

---

## L'ordre de travail

Chaque étape laisse le site utilisable.

| # | Étape | Fini quand |
|---|---|---|
| 0 | Sécurité, nouveau dépôt propre | mot de passe changé, nouveau dépôt sans rien de personnel |
| 1 | Installation : `install.sql`, `config.js`, licence, versions exactes, ménage | un projet Supabase vide s'installe avec un seul fichier SQL |
| 2 | Ta vente → Réglages : titre, ville, accroche, dernier jour, objectif, affiche en base | plus aucun « Odense » ni « 20 November » dans le code |
| 3 | Devise, prix en nombres | une boutique en EUR et une en USD s'affichent juste, anciens prix convertis |
| 4 | Pays : téléphone, fuseau, semaine, 12 h / 24 h, papier, paiements libres | une boutique « US » : dimanche en premier, 3:00 PM, Letter, +1 par défaut |
| 5 | Langues en fichiers, `Intl`, assistant « Premiers pas » | ajouter `da.json` suffit pour avoir la boutique en danois |
| 6 | Générateur par langue, description de secours | une langue sans pack donne quand même une description |
| 7 | Alertes multilingues | l'alerte arrive dans la langue de l'espace vendeur |
| 8 | README anglais, CONTRIBUTING, démo, `v1.0.0` | un inconnu installe le projet sans aide |

Les étapes 2 à 4 se font sans les fichiers de langue : leurs nouveaux textes s'écrivent
encore en `t('…', '…')` et sont extraits avec les autres à l'étape 5.

---

## Décisions à prendre

1. **Le nom du projet.**
2. **La licence** : MIT (recommandé) ou AGPL.
3. **Nouveau dépôt** (recommandé) ou nettoyage de l'historique de `meubles`.
4. **Les langues de départ** : anglais et français existent. Le danois serait le plus utile
   pour tes acheteurs actuels.
5. **Rester sans compilation** : Babel compile les quelque 7 000 lignes dans le navigateur
   à chaque visite, ce qui ralentit le premier affichage sur un vieux téléphone. Une
   compilation par GitHub Action réglerait ça, au prix d'une étape de plus pour les
   contributeurs. Recommandé : rester sans compilation pour la v1.
