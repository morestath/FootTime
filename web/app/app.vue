<template>
  <header class="top" style="display:flex;justify-content:space-between;align-items:center">
    <div><b>FootTime</b><small>TROUVE. RÉSERVE. JOUE.</small></div>
    <NuxtLink v-if="user" to="/notifications" class="badge">Notifications{{ unread ? ` (${unread})` : '' }}</NuxtLink>
  </header>
  <NuxtPage />
  <nav class="tabs">
    <NuxtLink to="/">Accueil</NuxtLink><NuxtLink to="/terrains">Terrains</NuxtLink>
    <NuxtLink to="/reservations">Réservations</NuxtLink><NuxtLink to="/profil">Profil</NuxtLink>
  </nav>
</template>
<script setup lang="ts">
const { user, init } = useAuth(); await init()
const sb = useSb(); const route = useRoute(); const unread = ref(0)
async function count() {
  unread.value = user.value ? ((await sb.from('notifications').select('id', { count: 'exact', head: true }).is('read_at', null)).count ?? 0) : 0
}
watch(user, count, { immediate: true }); watch(() => route.fullPath, count)
</script>
