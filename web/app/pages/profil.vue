<template>
  <main>
    <h1>Profil</h1>
    <div v-if="!user" class="empty">Connectez-vous pour gérer votre profil.<br><br>
      <NuxtLink to="/connexion" class="btn" style="display:block">Connexion</NuxtLink></div>
    <template v-else>
      <input v-model="p.first_name" placeholder="Prénom" /><input v-model="p.last_name" placeholder="Nom" />
      <input v-model="p.phone" placeholder="Téléphone" inputmode="tel" />
      <p class="muted">Email : {{ user.email }}</p>
      <p v-if="msg" class="muted">{{ msg }}</p>
      <button class="btn" @click="save">Enregistrer</button><br><br>
      <NuxtLink v-if="isStaff" to="/pro" class="btn alt" style="display:block;margin-bottom:12px">Espace professionnel</NuxtLink>
      <NuxtLink v-if="isAdmin" to="/admin" class="btn alt" style="display:block;margin-bottom:12px">Administration</NuxtLink>
      <button class="btn alt" @click="signOut">Se déconnecter</button>
    </template>
  </main>
</template>
<script setup lang="ts">
const sb = useSb(); const { user, signOut } = useAuth()
const p = ref<any>({}); const msg = ref(''); const isAdmin = ref(false); const isStaff = ref(false)
onMounted(async () => {
  if (!user.value) return
  const r = (await sb.from('profiles').select('first_name,last_name,phone,role').eq('id', user.value.id).single()).data ?? {} as any
  p.value = r; isAdmin.value = r.role === 'ADMIN_FOOTTIME'
  const st = useStaff(); await st.load(); isStaff.value = st.venues.value.length > 0
})
async function save() {
  const { error } = await sb.from('profiles').update({ first_name: p.value.first_name, last_name: p.value.last_name, phone: p.value.phone }).eq('id', user.value.id)
  msg.value = error ? "Échec de l'enregistrement." : 'Profil enregistré.'
}
</script>
