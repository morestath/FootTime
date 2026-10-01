# FootTime — Guide de lancement

## 1. Supabase
1. Créer un projet sur supabase.com (région proche de Dakar si possible).
2. `supabase login` puis `supabase link --project-ref <REF>`.
3. `supabase db push` : applique les migrations 0001 à 0004.
4. Authentication > Providers : email activé. Choisir si la confirmation d'email est exigée (SMTP à configurer si oui).
5. SQL Editor : activer pg_cron et planifier la maintenance (voir `docs/LOT2.md`).

## 2. Fonctions serveur
```bash
cp supabase/functions/.env.example supabase/functions/.env   # remplir
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy create-booking
supabase functions deploy modify-booking
supabase functions deploy sandbox-confirm       # tests uniquement
supabase functions deploy payment-webhook --no-verify-jwt
```

## 3. Premier administrateur
S'inscrire dans l'appli, puis dans le SQL Editor :
`update profiles set role = 'ADMIN_FOOTTIME' where email = 'votre@email';`

## 4. Application web
```bash
cd web && cp .env.example .env     # URL et clé anon du projet Supabase
npm install && npm run dev
```
Déploiement : Vercel ou Netlify (`npm run build`), variables `NUXT_PUBLIC_*` renseignées. Mettre `APP_URL` et `ALLOWED_ORIGIN` (fonctions) sur l'adresse publique.

## 5. Données réelles (Admin)
Paramètres (avance, commission, règles d'annulation et d'absence) → Terrains (fiche, horaires, photos réelles, « Visible aux joueurs ») → Comptes (propriétaires, gestionnaires).

## 6. Test de bout en bout (sandbox)
Inscription joueur → réservation → paiement de test → réservation confirmée + notification → modification (x2, la 3e est refusée) → seconde réservation du même créneau refusée → réservation passée à COMPLETED → avis → modération admin.

## 7. Passage en production
- `PAYMENTS_SANDBOX=false`, `APP_ENV=production`, `NUXT_PUBLIC_SANDBOX=false`, puis retirer `sandbox-confirm`.
- Wave : clés réelles, URL du webhook déclarée, test en environnement Wave avant ouverture. Orange Money non intégré.
- Règles d'annulation/absence, avance et commission validées par FootTime ; conditions d'utilisation et confidentialité publiées.
- Vérifier qu'aucun terrain ni donnée de test ne reste visible.
