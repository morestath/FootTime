<template>
  <h1>Tableau de bord</h1>
  <p v-if="!s" class="muted">Chargement…</p>
  <template v-else>
    <div class="card">
      <div class="row"><span>Joueurs</span><b>{{ s.players }}</b></div>
      <div class="row"><span>Terrains (actifs / total)</span><b>{{ s.venuesActive }} / {{ s.venues }}</b></div>
      <div class="row"><span>Propriétaires</span><b>{{ s.owners }}</b></div>
      <div class="row"><span>Gestionnaires actifs</span><b>{{ s.managers }}</b></div>
      <div class="row"><span>Réservations confirmées ou terminées</span><b>{{ s.bookings }}</b></div>
      <div class="row"><span>Avis à modérer</span><b>{{ s.reviews }}</b></div>
      <div class="row"><span>Signalements ouverts</span><b>{{ s.reports }}</b></div>
    </div>
    <h2>Argent (valeurs distinctes)</h2>
    <div class="card">
      <div class="row"><span>Total payé (avances reçues)</span><b>{{ fcfa(s.paid) }}</b></div>
      <div class="row"><span>Commission FootTime</span><b>{{ fcfa(s.commission) }}</b></div>
      <div class="row"><span>Revenu revenant aux terrains</span><b>{{ fcfa(s.venueRevenue) }}</b></div>
      <p class="muted">Commission et revenu terrain portent sur le montant total des réservations confirmées ou terminées.</p>
    </div>
    <h2>Paiements à rembourser</h2>
    <div v-if="!refunds.length" class="empty">Aucun paiement à traiter.</div>
    <div v-for="p in refunds" :key="p.id" class="card">
      <div class="row"><b>{{ p.bookings?.code }}</b><span>{{ fcfa(p.amount) }} · {{ p.provider }}</span></div>
      <p class="muted">Paiement reçu mais créneau indisponible. Remboursement manuel chez le prestataire.</p>
    </div>
  </template>
</template>
<script setup lang="ts">
const sb = useSb(); const s = ref<any>(null); const refunds = ref<any[]>([])
const cnt = async (t: string, f?: (q: any) => any) => { let q: any = sb.from(t).select('*', { count: 'exact', head: true }); if (f) q = f(q); return (await q).count ?? 0 }
const sum = (rows: any[] | null, k: string) => (rows ?? []).reduce((a, r) => a + r[k], 0)
onMounted(async () => {
  const [players, venues, venuesActive, owners, managers, bookings, reviews, reports, pay, bk, rf] = await Promise.all([
    cnt('profiles', (q) => q.eq('role', 'JOUEUR')), cnt('venues'), cnt('venues', (q) => q.eq('is_active', true)),
    cnt('owners'), cnt('venue_managers', (q) => q.eq('status', 'ACTIVE')),
    cnt('bookings', (q) => q.in('status', ['CONFIRMED', 'COMPLETED'])),
    cnt('reviews', (q) => q.eq('status', 'PENDING')), cnt('reports', (q) => q.neq('status', 'RESOLVED')),
    sb.from('payments').select('amount').eq('status', 'SUCCEEDED'),
    sb.from('bookings').select('commission_amount,venue_amount').in('status', ['CONFIRMED', 'COMPLETED']),
    sb.from('payments').select('id,amount,provider,bookings(code)').eq('needs_refund', true),
  ])
  refunds.value = rf.data ?? []
  s.value = { players, venues, venuesActive, owners, managers, bookings, reviews, reports,
    paid: sum(pay.data, 'amount'), commission: sum(bk.data, 'commission_amount'), venueRevenue: sum(bk.data, 'venue_amount') }
})
</script>
