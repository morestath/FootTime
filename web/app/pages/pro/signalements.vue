<template>
  <div class="card">
    <select v-model="kind"><option v-for="k in kinds" :key="k[0]" :value="k[0]">{{ k[1] }}</option></select>
    <input v-model="message" placeholder="Décrivez le problème" />
    <p v-if="msg" class="err">{{ msg }}</p>
    <button class="btn" @click="send">Envoyer à FootTime</button>
  </div>
  <h2>Mes signalements</h2>
  <div v-if="!list.length" class="empty">Aucun signalement.</div>
  <div v-for="r in list" :key="r.id" class="card">
    <div class="row"><b>{{ Object.fromEntries(kinds)[r.kind] }}</b><span class="badge warn">{{ r.status }}</span></div>
    <div class="muted">{{ r.message }}</div>
  </div>
</template>
<script setup lang="ts">
const sb = useSb(); const { user } = useAuth(); const { current } = useStaff()
const kinds = [['CLOSURE', 'Fermeture exceptionnelle'], ['UNAVAILABLE', 'Indisponibilité'], ['TECHNICAL', 'Problème technique'], ['OTHER', 'Autre']]
const kind = ref('TECHNICAL'), message = ref(''), msg = ref(''); const list = ref<any[]>([])
const load = async () => { list.value = (await sb.from('reports').select('id,kind,message,status').eq('venue_id', current.value!.id).order('created_at', { ascending: false })).data ?? [] }
async function send() {
  msg.value = ''; if (message.value.trim().length < 5) return (msg.value = 'Décrivez le problème.')
  const { error } = await sb.from('reports').insert({ venue_id: current.value!.id, reporter_id: user.value.id, kind: kind.value, message: message.value.trim() })
  if (error) return (msg.value = error.message); message.value = ''; await load()
}
onMounted(load)
</script>
