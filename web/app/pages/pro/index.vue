<template>
  <h2>Aujourd'hui</h2>
  <div class="card"><div class="row"><span>Réservations du jour</span><b>{{ today }}</b></div></div>
  <template v-if="finance">
    <h2>Finances de ce terrain</h2>
    <p v-if="!m" class="muted">Chargement…</p>
    <div v-else class="card">
      <div class="row"><span>Avances reçues</span><b>{{ fcfa(m.paid) }}</b></div>
      <div class="row"><span>Chiffre d'affaires (réservations confirmées ou terminées)</span><b>{{ fcfa(m.total) }}</b></div>
      <div class="row"><span>Commission FootTime</span><b>{{ fcfa(m.commission) }}</b></div>
      <div class="row total"><span>Montant revenant au terrain</span><span>{{ fcfa(m.venue) }}</span></div>
    </div>
  </template>
  <p v-if="!today && today !== 0" class="muted">Chargement…</p>
</template>
<script setup lang="ts">
const sb = useSb(); const { current, finance } = useStaff()
const today = ref<number | null>(null); const m = ref<any>(null)
const sum = (r: any[] | null, k: string) => (r ?? []).reduce((a, x) => a + x[k], 0)
onMounted(async () => {
  const v = current.value!.id; const d = new Date().toISOString().slice(0, 10)
  const t = await sb.from('bookings').select('id', { count: 'exact', head: true }).eq('venue_id', v)
    .in('status', ['CONFIRMED', 'COMPLETED']).overlaps('during', `[${d}T00:00:00Z,${d}T23:59:59Z]`)
  today.value = t.count ?? 0
  if (!finance.value) return
  const [p, b] = await Promise.all([
    sb.from('payments').select('amount,bookings!inner(venue_id)').eq('status', 'SUCCEEDED').eq('bookings.venue_id', v),
    sb.from('bookings').select('total_amount,commission_amount,venue_amount').eq('venue_id', v).in('status', ['CONFIRMED', 'COMPLETED'])])
  m.value = { paid: sum(p.data, 'amount'), total: sum(b.data, 'total_amount'), commission: sum(b.data, 'commission_amount'), venue: sum(b.data, 'venue_amount') }
})
</script>
