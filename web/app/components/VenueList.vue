<template>
  <p v-if="loading" class="muted">Chargement…</p>
  <p v-else-if="error" class="err">{{ error }}</p>
  <div v-else-if="!venues.length" class="empty">Aucun terrain n'est encore disponible à Kaolack.</div>
  <NuxtLink v-for="v in venues" :key="v.id" :to="`/terrains/${v.id}`" class="card">
    <img v-if="v.photo" :src="v.photo" class="photo" :alt="v.name" />
    <div v-else class="photo">Photo à venir</div>
    <h2 style="margin-top:10px">{{ v.name }}</h2>
    <div class="muted">{{ v.neighborhood }}</div>
    <div class="row"><span>{{ fcfa(v.price_per_hour) }} / heure</span>
      <span v-if="v.rating" class="badge">★ {{ v.rating }} ({{ v.count }})</span></div>
  </NuxtLink>
</template>
<script setup lang="ts">
const sb = useSb()
const venues = ref<any[]>([]); const loading = ref(true); const error = ref('')
onMounted(async () => {
  const { data, error: e } = await sb.from('venues')
    .select('id,name,neighborhood,price_per_hour,venue_photos(storage_path,position),cities!inner(slug)')
    .eq('cities.slug', 'kaolack').eq('is_active', true).order('name')
  if (e) error.value = 'Impossible de charger les terrains.'
  else {
    const { data: rv } = await sb.from('reviews').select('venue_id,rating')   // avis approuvés (RLS)
    venues.value = (data ?? []).map((v: any) => {
      const r = (rv ?? []).filter((x: any) => x.venue_id === v.id)
      const p = [...(v.venue_photos ?? [])].sort((a, b) => a.position - b.position)[0]
      return { ...v, count: r.length, rating: r.length ? (r.reduce((s: number, x: any) => s + x.rating, 0) / r.length).toFixed(1) : null,
        photo: p ? sb.storage.from('venue-photos').getPublicUrl(p.storage_path).data.publicUrl : null }
    })
  }
  loading.value = false
})
</script>
