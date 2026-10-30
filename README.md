# Vente de meubles — installation

Site statique hébergé sur GitHub Pages, données sur Supabase.
Boutique en anglais pour les acheteurs, espace vendeur en français.

## Les fichiers

| Fichier | Où il va | Quand |
|---|---|---|
| `index.html` | dépôt GitHub | toujours — c'est la page et toute l'application, contient tes clés |
| `.github/workflows/supabase-keepalive.yml` | dépôt GitHub | pour que Supabase ne mette pas le projet en pause (voir « Projet en pause ») |
| `schema.sql` | Supabase, SQL Editor | une fois, au début |
| `notifications.sql` | Supabase, SQL Editor | une fois, si tu veux être alertée |
| `migration-paiement.sql` | Supabase, SQL Editor | si la base existait avant le choix du paiement, **ou pour accepter Cash** (sans risque à relancer) |
| `migration-quantite.sql` | Supabase, SQL Editor | une fois, **pour vendre plusieurs exemplaires d'un meuble** (2 lits…) (sans risque à relancer) |
| `migration-photos.sql` | Supabase, SQL Editor | une fois, **pour mettre plusieurs photos par meuble** et retrouver les choix de la description en rouvrant une annonce (sans risque à relancer) |
| `migration-stats.sql` | Supabase, SQL Editor | une fois, **pour l'onglet Stats** (visites, scans du QR code, meubles les plus vus). **Si tu l'avais déjà lancé, relance-le** : la nouvelle version permet d'effacer ta propre visite quand tu te connectes (sans risque à relancer) |
| `migration-prix-vente.sql` | Supabase, SQL Editor | une fois, **pour noter le prix de vente réel** quand tu as négocié (sans risque à relancer) |
| `migration-planning-par-objet.sql` | Supabase, SQL Editor | **inutile** en installation neuve, `schema.sql` l'inclut déjà |
| `reset-mot-de-passe.sql` | Supabase, SQL Editor | seulement si tu as oublié le mot de passe vendeur |
| `affiche.html` | — | **plus nécessaire** : l'affiche se fait maintenant dans l'onglet Affiche de l'espace vendeur |
| `app.jsx` | — | **plus utilisé** : ancienne version, `index.html` contient toute l'application |

Sur GitHub, le site n'a besoin que d'`index.html` ; le dossier `.github` sert au
réveil automatique de Supabase. Les fichiers `.sql` se collent dans Supabase, ils
n'ont pas besoin d'être dans le dépôt (tu peux les y laisser, ils ne contiennent
aucun secret).

---

## 1. Créer le projet Supabase (5 min)

1. Va sur [supabase.com](https://supabase.com), crée un compte, puis **New project**.
2. Choisis la région **Europe (Frankfurt)** ou **North EU**, plus proche du Danemark.
3. Note le mot de passe de la base quelque part, tu n'en auras plus besoin ensuite.

## 2. Créer les tables

Dans le menu de gauche : **SQL Editor → New query**.
Colle tout le contenu de `schema.sql`, puis **Run**.

Ça crée trois tables (`items`, `bookings`, `settings`), les règles de sécurité,
la vue publique des créneaux occupés et le temps réel.

## 3. Créer ton compte vendeur

**Authentication → Users → Add user → Create new user**.
Mets ton e-mail et un mot de passe, et coche **Auto Confirm User**.
C'est avec ça que tu te connecteras à l'espace vendeur.

Va ensuite dans **Authentication → Sign In / Providers** et désactive
**Allow new users to sign up** : personne d'autre ne pourra créer de compte.

## 4. Brancher le site

**Project Settings → Data API**, copie :

- **Project URL** → dans `index.html`, remplace `https://TON-PROJET.supabase.co`
- **anon public key** → remplace `COLLE-ICI-TA-CLE-ANON`

Ces deux valeurs sont **faites pour être publiques**, elles peuvent rester dans un dépôt
public sans risque. Ce sont les règles RLS de `schema.sql` qui protègent réellement :
tout le monde peut lire les annonces et créer un rendez-vous, mais **seul ton compte
connecté peut lire les prénoms et les numéros de téléphone**.

Ne mets jamais la clé `service_role` dans ces fichiers, celle-là donne tous les droits.

## 5. Publier sur GitHub

1. Crée un dépôt **public** (par exemple `meubles`).
2. Envoie `index.html`, `README.md` et le dossier `.github` (glisser-déposer sur github.com suffit).
3. **Settings → Pages → Source: Deploy from a branch**, branche `main`, dossier `/ (root)`.
4. Une minute plus tard, ton site est en ligne sur
   `https://TON-PSEUDO.github.io/meubles/`

C'est cette adresse que contient le QR code de l'affiche (onglet Affiche, rempli tout seul).
**Fixe-la avant d'imprimer.**

Dans Supabase, **Authentication → URL Configuration → Site URL**, colle cette même
adresse (`https://TON-PSEUDO.github.io/meubles/`) puis **Save**. Sans ça, le lien
« Mot de passe oublié » reçu par e-mail renvoie vers `localhost` et ne marche pas.

## 6. Premier usage

Ouvre le site, clique sur **Seller access** en bas de page (ou va directement sur
`https://TON-PSEUDO.github.io/meubles/#vendeur`, à mettre en favori sur ton téléphone),
connecte-toi avec l'e-mail de l'étape 3. Cinq onglets :

- **Annonces** — ajouter, modifier, marquer comme vendu ou supprimer un meuble.
  **Photos** : jusqu'à 8 par meuble, on peut en choisir plusieurs d'un coup. La
  première sert de couverture (liste, affiche, réservation) ; « Mettre en 1re »
  en change. Les acheteurs touchent la photo pour toutes les voir en glissant du
  doigt. Il faut avoir lancé `migration-photos.sql` une fois, sinon seule la
  couverture est gardée.
  **Description** : elle s'écrit toute seule en anglais avec le type, la matière,
  l'état, l'année d'achat, le prix payé neuf (l'économie est calculée), les atouts,
  les défauts, le transport… (pas d'IA, juste des phrases toutes faites). Chaque
  type de meuble a ses propres phrases et chaque annonce reçoit des tournures
  différentes ; **Reformuler** en propose d'autres à chaque clic. Tu peux la
  retoucher. Le titre (en anglais) se remplit aussi tout seul tant que tu ne l'as
  pas tapé. Les choix sont gardés avec l'annonce (après `migration-photos.sql`).
  Le prix se tape sans « kr », il est ajouté tout seul.
  **Nombre** : pour 2 lits identiques, mets 2 et le prix d'un seul. Les acheteurs
  choisissent combien ils en prennent en réservant. Quand un exemplaire part, clique
  sur **+** de « 0 vendu sur 2 » ; quand tout est vendu, l'annonce quitte la boutique.
  Il faut avoir lancé `migration-quantite.sql` une fois.
  **Vendu** : « Marquer vendu » (ou **+**) demande à quel prix : au prix affiché, ou
  à un autre prix si tu as négocié. La liste montre « vendu 400 kr (affiché 450 kr) »
  et l'objectif compte ce que tu as vraiment encaissé, avec l'écart dû aux
  négociations. **−** ou « Remettre en vente » annule la dernière vente. Pour noter un
  autre prix, il faut avoir lancé `migration-prix-vente.sql` une fois ; sans lui, on
  ne peut vendre qu'au prix affiché.
- **Rendez-vous** — les demandes, avec le numéro cliquable pour rappeler.
- **Planning** — jours d'ouverture, créneaux horaires, jours fermés, adresse et paiement.
- **Affiche** — coche les meubles à mettre sur l'affiche avec leur prix ; tous les
  autres sont cités dessous, sous « Also for sale ». Si tout ne tient pas au-dessus
  du bandeau bleu, le haut de l'affiche rapetisse tout seul (60 % au plus petit) et
  un avertissement orange dit que la liste cochée est trop longue : décoche quelques
  meubles. Clique sur un texte pour le modifier, choisis les paiements affichés en bas
  (Revolut et Cash au départ, on en retire ou on en ajoute), choisis le **format** :
  **1 par feuille** (une affiche A4) ou **2 par feuille** (deux affiches A5 identiques
  sur un A4 en paysage, à couper le long des pointillés), puis **Imprimer / Enregistrer
  en PDF** (papier A4, en paysage pour 2 par feuille, graphiques d'arrière-plan cochés).
  Les choix sont gardés dans ce navigateur.

  **Impression.** L'affiche a sa propre marge blanche de 6 mm, car les imprimantes ne
  savent pas imprimer jusqu'au bord : l'aperçu à l'écran est ce qui sort. Si
  l'imprimante est réglée sur le papier américain **Letter**, l'affiche sort quand même
  entière et centrée, mais un peu plus petite : choisis **A4** dans « Plus de
  paramètres › Taille du papier » pour qu'elle remplisse la feuille.
- **Stats** — visites du site, scans du QR code, d'où viennent les visiteurs, et pour
  chaque meuble : combien l'ont vu, combien se sont intéressés (photos ouvertes ou
  réservation commencée) et combien de rendez-vous. Il faut avoir lancé
  `migration-stats.sql` une fois ; le compteur démarre à ce moment-là. L'adresse du
  site ne change pas : l'affiche déjà imprimée et son QR code restent bons.
  Le **scan du QR code est une estimation** : le QR code mène à l'adresse simple du
  site, donc toute arrivée sur téléphone sans lien d'origine compte comme un scan
  (taper l'adresse à la main aussi). Pas de cookie ni d'outil extérieur : un numéro
  tiré au hasard par visite, oublié à la fermeture de l'onglet. Tes visites ne
  comptent pas : si tu arrives sur la boutique puis te connectes à l'espace vendeur,
  ta visite est effacée, et ce téléphone ou cet ordinateur n'est plus jamais compté,
  même déconnecté. Les essais en local (localhost) ne comptent pas non plus.

---

## Mot de passe oublié

Deux solutions :

- **Depuis le site** : écran de connexion → **Mot de passe oublié ?** → entre ton
  e-mail. Supabase t'envoie un lien qui te ramène sur le site pour choisir un
  nouveau mot de passe. Il faut que la **Site URL** soit réglée (voir étape 5).
  Le service d'e-mail gratuit de Supabase n'envoie que quelques e-mails par heure,
  et seulement aux adresses membres de ton organisation Supabase.
- **Directement dans Supabase**, immédiat et sans e-mail : ouvre
  `reset-mot-de-passe.sql`, mets ton e-mail et le nouveau mot de passe, colle-le
  dans le SQL Editor et **Run**.

Attention à ne pas confondre : ce mot de passe est celui du compte vendeur du site
(Authentication → Users), pas celui de ton compte supabase.com ni celui de la base.

**Projet en pause.** Supabase met en pause les projets gratuits restés une semaine
sans activité : le site n'affiche plus rien et la connexion dit « Supabase est
injoignable ». Va sur supabase.com, ouvre le projet et clique sur **Restore project**,
puis attends quelques minutes.

Pour que ça n'arrive pas, `.github/workflows/supabase-keepalive.yml` (gratuit, via
GitHub Actions) envoie chaque jour une petite lecture de la table `items` : Supabase
considère alors le projet comme actif.

1. Le fichier doit être dans le dépôt GitHub, dossier `.github/workflows/`.
2. Rien d'autre à régler : il lit l'URL et la clé anon dans `index.html`. Si tu
   préfères, ajoute deux secrets dans le dépôt (**Settings → Secrets and variables
   → Actions**), `SUPABASE_URL` et `SUPABASE_ANON_KEY`, pris dans Supabase sous
   **Project Settings → Data API** : ils passent alors avant `index.html`.
3. Onglet **Actions** du dépôt → **Supabase keep-alive** → **Run workflow** pour
   tester. Si la case passe au vert, c'est bon.

Si le projet se remet un jour en pause, le workflow échoue et GitHub t'envoie un
e-mail. Limite à connaître : sur un dépôt public, GitHub coupe les tâches planifiées
après 60 jours sans activité dans le dépôt (aucun commit). Il prévient par e-mail
avant, et il suffit de réactiver le workflow dans l'onglet Actions.

## Notes

**Notifications.** Tant que l'onglet vendeur est ouvert, une alerte s'affiche à la
seconde où quelqu'un réserve (temps réel Supabase). Pour être prévenue même site fermé,
lance `notifications.sql` dans le SQL Editor : au choix une notification push sur ton
téléphone via ntfy (gratuit, sans compte) ou un e-mail via Resend. Tout se passe côté
base de données, il n'y a rien à changer dans le site.

**Photos.** Elles sont redimensionnées dans le navigateur puis stockées en base64
dans la base. Compte environ 100 Ko par photo, très loin des 500 Mo gratuits. Seules
les couvertures se chargent avec la liste ; les autres photos d'un meuble ne se
chargent que quand quelqu'un ouvre sa galerie, la boutique reste donc rapide
sur téléphone.

**Tester en local.** Ouvrir `index.html` directement ne marche pas (le navigateur
refuse de charger `app.jsx` depuis un fichier). Lance plutôt dans le dossier :

```bash
python3 -m http.server 8000
```

puis ouvre `http://localhost:8000`.

**Après la vente.** Supprime le dépôt GitHub et le projet Supabase, ou passe simplement
tous les meubles en « vendu ».
