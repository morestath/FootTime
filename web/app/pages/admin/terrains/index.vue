<template>
  <h1>Terrains</h1>
  <NuxtLink to="/admin/terrains/nouveau" class="btn" style="display:block;margin-bottom:12px">Ajouter un terrain</NuxtLink>
  <div v-if="!list.length" class="empty">Aucun terrain. Ajoutez le premier.</div>
  <NuxtLink v-for="v in list" :key="v.id" :to="`/admin/terrains/${v.id}`" class="card">
    <div class="row"><b>{{ v.name }}</b><span class="badge" :class="{ warn: !v.is_active }">{{ v.is_active ? 'Actif' : 'Désactivé' }}</span></div>
    <div class="muted">{{ v.neighborhood }} · {{ fcfa(v.price_per_hour) }} / h</div>
  </NuxtLink>
</template>
<script setup lang="ts">
const list = ref<any[]>([])
onMounted(async () => { list.value = (await useSb().from('venues').select('id,name,neighborhood,price_per_hour,is_active').order('name')).data ?? [] })
</script>
