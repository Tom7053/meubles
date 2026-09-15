# Vente de meubles — installation

Site statique hébergé sur GitHub Pages, données sur Supabase.
Boutique en anglais pour les acheteurs, espace vendeur en français.

## Les fichiers

| Fichier | Où il va | Quand |
|---|---|---|
| `index.html` | dépôt GitHub | toujours — c'est la page, contient tes clés |
| `app.jsx` | dépôt GitHub | toujours — toute l'application |
| `schema.sql` | Supabase, SQL Editor | une fois, au début |
| `notifications.sql` | Supabase, SQL Editor | une fois, si tu veux être alertée |
| `migration-paiement.sql` | Supabase, SQL Editor | une fois, si la base existait avant le choix MobilePay / Revolut |
| `migration-planning-par-objet.sql` | Supabase, SQL Editor | **inutile** en installation neuve, `schema.sql` l'inclut déjà |
| `affiche.html` | ton ordinateur | à ouvrir dans le navigateur puis imprimer en PDF |

Seuls `index.html` et `app.jsx` sont publiés sur GitHub. Les fichiers `.sql` se
collent dans Supabase, ils n'ont pas besoin d'être dans le dépôt (tu peux les y
laisser, ils ne contiennent aucun secret).

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
2. Envoie `index.html`, `app.jsx` et `README.md` (glisser-déposer sur github.com suffit).
3. **Settings → Pages → Source: Deploy from a branch**, branche `main`, dossier `/ (root)`.
4. Une minute plus tard, ton site est en ligne sur
   `https://TON-PSEUDO.github.io/meubles/`

C'est cette adresse à coller dans le champ de l'affiche pour générer le QR code.
**Fixe-la avant d'imprimer.**

## 6. Premier usage

Ouvre le site, clique sur **Seller access** en bas de page, connecte-toi avec l'e-mail
de l'étape 3. Trois onglets :

- **Annonces** — ajouter, modifier, marquer comme vendu ou supprimer un meuble.
- **Rendez-vous** — les demandes, avec le numéro cliquable pour rappeler.
- **Planning** — jours d'ouverture, créneaux horaires, jours fermés, adresse et paiement.

---

## Notes

**Notifications.** Tant que l'onglet vendeur est ouvert, une alerte s'affiche à la
seconde où quelqu'un réserve (temps réel Supabase). Pour être prévenue même site fermé,
lance `notifications.sql` dans le SQL Editor : au choix une notification push sur ton
téléphone via ntfy (gratuit, sans compte) ou un e-mail via Resend. Tout se passe côté
base de données, il n'y a rien à changer dans le site.

**Photos.** Elles sont redimensionnées dans le navigateur puis stockées en base64
dans la table. Compte environ 100 Ko par meuble, très loin des 500 Mo gratuits.

**Tester en local.** Ouvrir `index.html` directement ne marche pas (le navigateur
refuse de charger `app.jsx` depuis un fichier). Lance plutôt dans le dossier :

```bash
python3 -m http.server 8000
```

puis ouvre `http://localhost:8000`.

**Après la vente.** Supprime le dépôt GitHub et le projet Supabase, ou passe simplement
tous les meubles en « vendu ».
