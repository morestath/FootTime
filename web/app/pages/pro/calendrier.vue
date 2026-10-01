<template>
  <input v-model="date" type="date" @change="load" />
  <div v-if="!rows.length" class="empty">Terrain fermé ce jour-là.</div>
  <div v-for="r in rows" :key="r.h" class="card" style="padding:10px">
    <div class="row"><b>{{ r.h }} h – {{ r.h + 1 }} h</b>
      <span class="badge" :class="{ warn: r.state !== 'Libre' }">{{ r.state }}</span></div>
    <div v-if="r.note" class="muted">{{ r.note }}</div>
  </div>
</template>
<script setup lang="ts">
const sb = useSb(); const { current } = useStaff()
const date = ref(new Date().toISOString().slice(0, 10)); const rows = ref<any[]>([])
async function load() {
  const v = current.value!.id; const wd = new Date(`${date.value}T00:00:00Z`).getUTCDay()
  const { data: o } = await sb.from('venue_opening_hours').select('opens_at,closes_at').eq('venue_id', v).eq('weekday', wd).maybeSingle()
  if (!o) return (rows.value = [])
  const rg = `[${date.value}T00:00:00Z,${date.value}T23:59:59Z]`
  const bk = (await sb.from('bookings').select('code,status,during,expires_at').eq('venue_id', v)
    .in('status', ['PENDING_PAYMENT', 'CONFIRMED', 'COMPLETED', 'NO_SHOW']).overlaps('during', rg)).data ?? []
  const cl = (await sb.from('venue_closures').select('during,reason').eq('venue_id', v).overlaps('during', rg)).data ?? []
  const a = parseInt(o.opens_at), b = parseInt(o.closes_at); const out: any[] = []
  for (let h = a; h < b; h++) {
    const s = Date.parse(`${date.value}T${String(h).padStart(2, '0')}:00:00Z`), e = s + 3600e3
    const hit = (d: string) => { const p = rangeParts(d); return p.startMs < e && p.endMs > s }
    const c = cl.find((x: any) => hit(x.during)); const k = bk.find((x: any) => hit(x.during) && (x.status !== 'PENDING_PAYMENT' || Date.parse(x.expires_at) > Date.now()))
    out.push(c ? { h, state: 'Fermé', note: c.reason } : k ? { h, state: k.status === 'PENDING_PAYMENT' ? 'Paiement en attente' : 'Réservé', note: k.code } : { h, state: 'Libre' })
  }
  rows.value = out
}
onMounted(load)
</script>
