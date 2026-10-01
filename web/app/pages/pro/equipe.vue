<template>
  <p v-if="!current?.owner" class="empty">Réservé au propriétaire du terrain.</p>
  <template v-else>
    <div class="card">
      <input v-model="email" type="email" placeholder="Email du compte FootTime à autoriser" />
      <p v-if="msg" class="muted">{{ msg }}</p>
      <button class="btn" @click="add">Proposer comme gestionnaire</button>
      <p class="muted">La personne doit déjà avoir un compte. Elle n'aura accès qu'après activation par FootTime.</p>
    </div>
    <h2>Personnes autorisées</h2>
    <div v-if="!list.length" class="empty">Aucun gestionnaire.</div>
    <div v-for="m in list" :key="m.profile_id" class="card">
      <div class="row"><b>{{ m.first_name }} {{ m.last_name }}</b><span class="badge" :class="{ warn: m.status !== 'ACTIVE' }">{{ m.status === 'PENDING' ? 'En attente de validation' : m.status }}</span></div>
    </div>
  </template>
</template>
<script setup lang="ts">
const sb = useSb(); const { current } = useStaff(); const email = ref(''), msg = ref(''); const list = ref<any[]>([])
const load = async () => { list.value = (await sb.rpc('list_venue_managers', { p_venue: current.value!.id })).data ?? [] }
async function add() {
  const { error } = await sb.rpc('propose_manager', { p_venue: current.value!.id, p_email: email.value })
  msg.value = error ? error.message : 'Demande enregistrée. FootTime doit la valider.'; email.value = ''; await load()
}
onMounted(load)
</script>
