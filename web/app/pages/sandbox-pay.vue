<template>
  <main>
    <h1>Paiement de test</h1>
    <p class="muted">Mode sandbox : aucun argent réel n'est débité.</p>
    <p v-if="msg" class="err">{{ msg }}</p>
    <button class="btn" @click="go(false)">Simuler un paiement réussi</button><br><br>
    <button class="btn alt" @click="go(true)">Simuler un échec</button>
  </main>
</template>
<script setup lang="ts">
const sb = useSb(); const ref_ = useRoute().query.ref as string; const msg = ref('')
async function go(fail: boolean) {
  const { error } = await sb.functions.invoke('sandbox-confirm', { body: { reference: ref_, fail } })
  if (error) return (msg.value = await fnError(error))
  const { data } = await sb.from('payments').select('bookings(code)').eq('provider_reference', ref_).single()
  navigateTo(`/reservations/${(data as any)?.bookings?.code ?? ''}`)
}
</script>
