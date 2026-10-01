<template>
  <main>
    <div class="chips">
      <NuxtLink v-for="l in links" :key="l[0]" :to="l[0]" class="chip">{{ l[1] }}</NuxtLink>
    </div>
    <NuxtPage />
  </main>
</template>
<script setup lang="ts">
definePageMeta({ middleware: 'admin' })
const links = [['/admin', 'Tableau de bord'], ['/admin/terrains', 'Terrains'], ['/admin/comptes', 'Comptes'],
  ['/admin/avis', 'Avis'], ['/admin/parametres', 'Paramètres']]
</script>
