<template>
  <div class="card">
    <label class="muted">Début</label><input v-model="from" type="datetime-local" />
    <label class="muted">Fin</label><input v-model="to" type="datetime-local" />
    <input v-model="reason" placeholder="Motif (ex. travaux, pelouse en réfection)" />
    <p v-if="msg" class="err">{{ msg }}</p>
    <button class="btn" @click="add">Signaler la fermeture</button>
  </div>
  <h2>Fermetures à venir</h2>
  <div v-if="!list.length" class="empty">Aucune fermeture.</div>
  <div v-for="c in list" :key="c.id" class="card">
    <div class="row"><b>{{ fmtDT(c.s) }} → {{ fmtDT(c.e) }}</b></div>
    <div class="muted">{{ c.reason }}</div>
    <button v-if="c.created_by === user?.id" class="btn alt" style="margin-top:8px" @click="del(c)">Retirer</button>
  </div>
</template>
<script setup lang="ts">
// Heures saisies en heure de Dakar (= UTC).
const sb = useSb(); const { user } = useAuth(); const { current } = useStaff()
const from = ref(''), to = ref(''), reason = ref(''), msg = ref(''); const list = ref<any[]>([])
async function load() {
  const { data } = await sb.from('venue_closures').select('id,during,reason,created_by').eq('venue_id', current.value!.id)
  list.value = (data ?? []).map((c: any) => ({ ...c, ...(() => { const p = rangeParts(c.during); return { s: p.startMs, e: p.endMs } })() }))
    .filter((c: any) => c.e > Date.now()).sort((a: any, b: any) => a.s - b.s)
}
async function add() {
  msg.value = ''
  const s = Date.parse(from.value + ':00Z'), e = Date.parse(to.value + ':00Z')
  if (!(s < e)) return (msg.value = 'La fin doit être après le début.')
  if (!reason.value.trim()) return (msg.value = 'Indiquez un motif.')
  const rg = `[${new Date(s).toISOString()},${new Date(e).toISOString()})`
  const { count } = await sb.from('bookings').select('id', { count: 'exact', head: true }).eq('venue_id', current.value!.id)
    .in('status', ['PENDING_PAYMENT', 'CONFIRMED']).overlaps('during', rg)
  if (count) return (msg.value = 'Des réservations existent sur ce créneau : contactez FootTime pour les traiter avant de fermer.')
  const { error } = await sb.from('venue_closures').insert({ venue_id: current.value!.id, during: rg, reason: reason.value.trim(), created_by: user.value.id })
  if (error) return (msg.value = /exclu|overlap|conflict/i.test(error.message) ? 'Une fermeture existe déjà sur ce créneau.' : error.message)
  from.value = to.value = reason.value = ''; await load()
}
async function del(c: any) { await sb.from('venue_closures').delete().eq('id', c.id); await load() }
onMounted(load)
</script>
