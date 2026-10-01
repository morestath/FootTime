# FootTime — Lot 4 : administration

## Créer le premier administrateur
1. Créer un compte via l'appli (/connexion).
2. Dans Supabase > SQL Editor :
   `update profiles set role = 'ADMIN_FOOTTIME' where email = 'votre@email';`
3. Ouvrir `/admin`. Les autres comptes se gèrent ensuite dans Admin > Comptes.

## Mise en route des données
Admin > Paramètres : avance, commission, règles d'annulation et d'absence (textes vides au départ).
Admin > Terrains : créer un terrain, ses horaires et ses vraies photos, puis cocher « Visible aux joueurs ».
Admin > Comptes : passer un compte en PROPRIETAIRE (crée sa fiche propriétaire), puis choisir le propriétaire dans la fiche du terrain.

## Migration
`supabase db push` applique 0003 (paramètres lisibles avant connexion, garde-fou de rôle).

## Espaces propriétaire et gestionnaire (`/pro`)
- Accès : un propriétaire actif (fiche `owners`) ou un gestionnaire dont l'affectation est ACTIVE. Lien « Espace professionnel » dans Profil.
- Le propriétaire propose un gestionnaire (Équipe) : l'affectation reste PENDING jusqu'à activation par FootTime (Admin > Comptes).
- Les montants (avances, commission, revenu) sont masqués aux gestionnaires sauf `permissions = {"finance": true}`.
  **Limite connue** : ce masquage est dans l'interface seulement ; au niveau base, un gestionnaire affecté peut lire les montants des réservations de son terrain.
- Une fermeture est refusée si des réservations en attente ou confirmées existent déjà sur le créneau.
- `supabase db push` applique 0004.
