<template>
  <main>
    <select v-if="venues.length > 1" v-model="sel">
      <option v-for="v in venues" :key="v.id" :value="v.id">{{ v.name }}</option></select>
    <h1 v-else>{{ current?.name }}</h1>
    <div class="chips">
      <NuxtLink v-for="l in links" :key="l[0]" :to="l[0]" class="chip">{{ l[1] }}</NuxtLink>
      <NuxtLink v-if="current?.owner" to="/pro/equipe" class="chip">Équipe</NuxtLink>
    </div>
    <NuxtPage :key="sel" />
  </main>
</template>
<script setup lang="ts">
definePageMeta({ middleware: 'staff' })
const { venues, sel, current } = useStaff()
const links = [['/pro', 'Tableau de bord'], ['/pro/calendrier', 'Calendrier'], ['/pro/reservations', 'Réservations'],
  ['/pro/fermetures', 'Fermetures'], ['/pro/signalements', 'Signalements']]
</script>
