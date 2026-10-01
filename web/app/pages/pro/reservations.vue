<template>
  <div v-if="!list.length" class="empty">Aucune réservation pour ce terrain.</div>
  <div v-for="b in list" :key="b.id" class="card">
    <div class="row"><b>{{ b.code }}</b><span class="badge" :class="{ warn: b.status !== 'CONFIRMED' }">{{ b.status }}</span></div>
    <div class="muted">{{ fmtDT(b.startMs) }} · {{ b.duration_hours }} h</div>
    <div v-if="finance" class="muted">Total {{ fcfa(b.total_amount) }} · avance {{ fcfa(b.deposit_amount) }} · terrain {{ fcfa(b.venue_amount) }}</div>
  </div>
</template>
<script setup lang="ts">
const sb = useSb(); const { current, finance } = useStaff(); const list = ref<any[]>([])
onMounted(async () => {
  const { data } = await sb.from('bookings').select('id,code,status,during,duration_hours,total_amount,deposit_amount,venue_amount')
    .eq('venue_id', current.value!.id).order('created_at', { ascending: false }).limit(100)
  list.value = (data ?? []).map((b: any) => ({ ...b, startMs: rangeParts(b.during).startMs }))
})
</script>
