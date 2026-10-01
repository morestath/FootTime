<template>
  <h1>Comptes</h1>
  <input v-model="q" placeholder="Rechercher (email, nom)" @input="load" />
  <p v-if="msg" class="err">{{ msg }}</p>
  <div v-for="p in list" :key="p.id" class="card">
    <b>{{ p.first_name }} {{ p.last_name }}</b><div class="muted">{{ p.email }} · {{ p.phone }}</div>
    <select :value="p.role" @change="upd(p, 'role', ($event.target as HTMLSelectElement).value)">
      <option v-for="r in roles" :key="r">{{ r }}</option></select>
    <select :value="p.status" @change="upd(p, 'status', ($event.target as HTMLSelectElement).value)">
      <option v-for="s in ['ACTIVE', 'SUSPENDED', 'PENDING']" :key="s">{{ s }}</option></select>
  </div>
  <h2>Affecter un gestionnaire à un terrain</h2>
  <div class="card">
    <select v-model="mv"><option value="">Terrain…</option><option v-for="v in venues" :key="v.id" :value="v.id">{{ v.name }}</option></select>
    <input v-model="me" type="email" placeholder="Email du compte à affecter" />
    <button class="btn" @click="assign">Affecter (actif)</button>
  </div>
</template>
<script setup lang="ts">
const sb = useSb(); const roles = ['JOUEUR', 'PROPRIETAIRE', 'GESTIONNAIRE', 'ADMIN_FOOTTIME']
const list = ref<any[]>([]); const venues = ref<any[]>([]); const q = ref(''); const msg = ref(''); const mv = ref(''); const me = ref('')
async function load() {
  let r = sb.from('profiles').select('id,first_name,last_name,email,phone,role,status').order('created_at', { ascending: false }).limit(50)
  const t = q.value.trim().replace(/[,()%]/g, '')
  if (t) r = r.or(`email.ilike.%${t}%,first_name.ilike.%${t}%,last_name.ilike.%${t}%`)
  list.value = (await r).data ?? []
}
async function upd(p: any, k: string, v: string) {
  msg.value = ''
  if (k === 'role' && v === 'ADMIN_FOOTTIME' && !confirm('Donner les droits administrateur à ce compte ?')) return load()
  const { error } = await sb.from('profiles').update({ [k]: v }).eq('id', p.id)
  if (error) msg.value = error.message
  else if (k === 'role' && v === 'PROPRIETAIRE')
    await sb.from('owners').upsert({ profile_id: p.id, status: 'ACTIVE' }, { onConflict: 'profile_id' })
  await load()
}
async function assign() {
  msg.value = ''
  const { data } = await sb.from('profiles').select('id,role').eq('email', me.value.trim()).maybeSingle()
  if (!mv.value || !data) return (msg.value = 'Terrain ou compte introuvable.')
  if (data.role === 'JOUEUR') await sb.from('profiles').update({ role: 'GESTIONNAIRE' }).eq('id', data.id)
  const { error } = await sb.from('venue_managers').upsert({ venue_id: mv.value, profile_id: data.id, status: 'ACTIVE' })
  msg.value = error ? error.message : 'Gestionnaire affecté.'; await load()
}
onMounted(async () => { venues.value = (await sb.from('venues').select('id,name').order('name')).data ?? []; await load() })
</script>
