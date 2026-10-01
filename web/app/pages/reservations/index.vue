<template>
  <main>
    <h1>Mes réservations</h1>
    <div v-if="!user" class="empty">Connectez-vous pour voir vos réservations.<br><br>
      <NuxtLink to="/connexion?redirect=/reservations" class="btn" style="display:block">Connexion</NuxtLink></div>
    <p v-else-if="loading" class="muted">Chargement…</p>
    <div v-else-if="!items.length" class="empty">Vous n'avez pas encore de réservation.</div>
    <NuxtLink v-for="b in items" :key="b.id" :to="`/reservations/${b.code}`" class="card">
      <div class="row"><b>{{ b.venues?.name }}</b><span class="badge" :class="{ warn: b.status !== 'CONFIRMED' }">{{ label[b.status] }}</span></div>
      <div class="muted">{{ fmt(b.start_at) }} · {{ b.duration_hours }} h · {{ b.code }}</div>
      <div v-if="b.status === 'CONFIRMED'" class="muted">Modifications restantes : {{ max - b.modification_count }}</div>
    </NuxtLink>
  </main>
</template>
<script setup lang="ts">
const sb = useSb(); const { user } = useAuth()
const items = ref<any[]>([]); const loading = ref(true); const max = ref(2)
const label: Record<string, string> = { PENDING_PAYMENT: 'Paiement en attente', CONFIRMED: 'Confirmée', CANCELLED: 'Annulée',
  EXPIRED: 'Expirée', COMPLETED: 'Terminée', NO_SHOW: 'Absence' }
const fmt = (iso: string) => new Date(iso).toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Africa/Dakar' })
onMounted(async () => {
  if (!user.value) return (loading.value = false)
  const { data } = await sb.from('bookings').select('id,code,status,during,duration_hours,modification_count,venues(name)')
    .eq('player_id', user.value.id).order('created_at', { ascending: false })
  // `during` est renvoyé sous forme de texte tstzrange : ["2026-10-03 18:00:00+00","…")
  items.value = (data ?? []).map((b: any) => ({ ...b, start_at: new Date(rangeParts(b.during).startMs).toISOString() }))
  const m = (await sb.from('platform_settings').select('value').eq('key', 'max_modifications').single()).data
  if (m) max.value = Number(m.value)
  loading.value = false
})
</script>
