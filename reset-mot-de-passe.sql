-- =====================================================================
--  MOT DE PASSE OUBLIÉ — le changer directement, sans attendre d'e-mail
--
--  Supabase : SQL Editor → New query → coller → remplacer les deux
--  valeurs → Run. Ça marche même si l'e-mail de réinitialisation
--  n'arrive pas (limite d'envoi, spams, adresse non autorisée…).
-- =====================================================================

-- Le mot de passe est chiffré (bcrypt) avant d'être enregistré, exactement
-- comme le fait Supabase quand on le change depuis le site.
update auth.users
   set encrypted_password = extensions.crypt('Toms/MDP', extensions.gen_salt('bf')),
       updated_at = now()
 where email = 'tommaine59@gmail.com'
returning email, updated_at;

-- Une ligne s'affiche avec ton e-mail : c'est fait, connecte-toi sur le site
-- avec ce nouveau mot de passe.
--
-- Aucune ligne ? L'adresse n'est pas la bonne. Pour voir celle du compte
-- vendeur, lance uniquement cette requête :
--
-- select email, last_sign_in_at from auth.users;
