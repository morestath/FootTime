<template>
  <h1>Avis à modérer</h1>
  <div v-if="!list.length" class="empty">Aucun avis en attente.</div>
  <div v-for="r in list" :key="r.id" class="card">
    <div class="row"><b>{{ r.venues?.name }}</b><span class="badge">★ {{ r.rating }}</span></div>
    <p>{{ r.comment || 'Sans commentaire' }}</p>
    <button class="btn" @click="set(r, 'APPROVED')">Approuver</button><br><br>
    <button class="btn alt" @click="set(r, 'REJECTED')">Rejeter</button>
  </div>
</template>
<script setup lang="ts">
const sb = useSb(); const list = ref<any[]>([])
const load = async () => { list.value = (await sb.from('reviews').select('id,rating,comment,venues(name)').eq('status', 'PENDING').order('created_at')).data ?? [] }
async function set(r: any, status: string) { await sb.from('reviews').update({ status }).eq('id', r.id); await load() }
onMounted(load)
</script>
