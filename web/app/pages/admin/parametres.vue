<template>
  <h1>Paramètres</h1>
  <div v-for="s in rows" :key="s.key" class="card">
    <label class="muted">{{ labels[s.key] ?? s.key }}</label>
    <input v-model="s.edit" />
  </div>
  <p v-if="msg" :class="ok ? 'muted' : 'err'">{{ msg }}</p>
  <button class="btn" @click="save">Enregistrer</button>
</template>
<script setup lang="ts">
const sb = useSb(); const rows = ref<any[]>([]); const msg = ref(''); const ok = ref(false)
const labels: Record<string, string> = { deposit_percent: 'Avance (% du total, 0–100)', commission_bps: 'Commission (points de base : 1000 = 10 %)',
  pending_payment_ttl_minutes: 'Durée de blocage avant paiement (minutes)', max_modifications: 'Modifications maximum par réservation',
  modification_cutoff_hours: 'Modification impossible à moins de … h du début', cancellation_rules: "Règles d'annulation (texte affiché avant paiement)",
  no_show_rules: "Règles d'absence (texte affiché avant paiement)" }
onMounted(async () => { rows.value = ((await sb.from('platform_settings').select('key,value').order('key')).data ?? []).map((r: any) => ({ ...r, edit: String(r.value) })) })
async function save() {
  msg.value = ''; ok.value = false
  for (const r of rows.value) {
    let v: any = r.edit
    if (typeof r.value === 'number') {
      v = Number(r.edit)
      const max = r.key === 'deposit_percent' ? 100 : r.key === 'commission_bps' ? 10000 : 100000
      if (!Number.isInteger(v) || v < 0 || v > max) return (msg.value = `Valeur invalide : ${labels[r.key] ?? r.key}`)
    }
    if (v !== r.value) {
      const { error } = await sb.from('platform_settings').update({ value: v, updated_at: new Date().toISOString() }).eq('key', r.key)
      if (error) return (msg.value = error.message)
      r.value = v
    }
  }
  ok.value = true; msg.value = 'Paramètres enregistrés.'
}
</script>
