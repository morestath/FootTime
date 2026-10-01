# FootTime — Lot 2 : paiements, réservation, modification

## Déploiement
```bash
supabase db push                                   # migrations 0001 + 0002
cp supabase/functions/.env.example supabase/functions/.env   # puis remplir
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy create-booking
supabase functions deploy modify-booking
supabase functions deploy sandbox-confirm          # inutile en production
supabase functions deploy payment-webhook --no-verify-jwt
```
URL du webhook Wave à déclarer chez le prestataire :
`https://<PROJECT_REF>.supabase.co/functions/v1/payment-webhook?provider=wave`

## Maintenance planifiée (SQL Editor, extension pg_cron)
```sql
create extension if not exists pg_cron;
select cron.schedule('ft-maintenance', '* * * * *',
  $$ select expire_pending_bookings(); select complete_past_bookings(); $$);
```

## Flux
1. `create-booking` : réserve le créneau (PENDING_PAYMENT, expire après `pending_payment_ttl_minutes`), crée le paiement, renvoie `checkout_url`.
2. Le joueur paie chez le prestataire. Le retour navigateur ne prouve rien.
3. `payment-webhook` : signature vérifiée + confirmation serveur-à-serveur, puis `settle_payment` (idempotent, vérifie le montant) confirme la réservation.
4. `modify-booking` : même durée, nouveau début, 2 modifications max, `modification_cutoff_hours` avant le début.

## Ce qui manque pour la production (honnête)
- **Wave** : compte marchand, `WAVE_API_KEY`, `WAVE_WEBHOOK_SECRET`. Le code suit l'API de checkout Wave telle que je la connais : à valider en environnement de test Wave avant tout usage réel.
- **Orange Money** : non intégré (contrat marchand et documentation API requis). L'appel renvoie une erreur 503 explicite.
- **Sandbox** : `PAYMENTS_SANDBOX=true` et `APP_ENV!=production` uniquement ; refusé sinon.
- **Paiement reçu après expiration, créneau repris** : `payments.needs_refund = true`, à traiter par l'admin (le remboursement lui-même est manuel pour l'instant).
- **Règles provisoires à valider** : avance 30 %, commission 10 %, délai de modification 24 h, règles d'annulation/absence (textes vides).
- **Non couvert** : annulation par le joueur et remboursement (règles non définies), changement de durée lors d'une modification.

## Vérifié
Migrations 0001+0002 exécutées sur PostgreSQL 16 avec de faux schémas `auth`/`storage` : anti-chevauchement, horaires, calcul des montants, règlement idempotent, montant erroné refusé, limite de 2 modifications, paiement tardif, RLS joueur, blocage de l'escalade de rôle. Les Edge Functions (Deno) n'ont **pas** été exécutées ici.
