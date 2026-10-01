<template>
  <h1>{{ isNew ? 'Nouveau terrain' : 'Modifier le terrain' }}</h1>
  <div class="card">
    <input v-model="f.name" placeholder="Nom du terrain" />
    <input v-model="f.neighborhood" placeholder="Quartier" />
    <input v-model="f.address" placeholder="Adresse" />
    <input v-model="f.description" placeholder="Description" />
    <input v-model.number="f.latitude" type="number" step="any" placeholder="Latitude" />
    <input v-model.number="f.longitude" type="number" step="any" placeholder="Longitude" />
    <input v-model.number="f.price_per_hour" type="number" min="1" placeholder="Prix par heure (FCFA)" />
    <input v-model="f.rules" placeholder="Règles du terrain" />
    <label class="muted">Propriétaire</label>
    <select v-model="f.owner_id"><option :value="null">— Aucun —</option>
      <option v-for="o in owners" :key="o.id" :value="o.id">{{ o.profiles?.first_name }} {{ o.profiles?.last_name }} ({{ o.profiles?.email }})</option></select>
    <div class="chips">
      <label v-for="e in equip" :key="e[0]" class="chip"><input v-model="f[e[0]]" type="checkbox" style="width:auto;margin:0 6px 0 0" />{{ e[1] }}</label>
      <label class="chip"><input v-model="f.is_active" type="checkbox" style="width:auto;margin:0 6px 0 0" />Visible aux joueurs</label>
    </div>
    <h2>Horaires (vide = fermé)</h2>
    <div v-for="d in hours" :key="d.weekday" class="row" style="gap:8px;align-items:center">
      <span style="width:80px">{{ days[d.weekday] }}</span>
      <input v-model="d.opens" type="time" /><input v-model="d.closes" type="time" />
    </div>
    <p v-if="msg" :class="ok ? 'muted' : 'err'">{{ msg }}</p>
    <button class="btn" :disabled="busy" @click="save">Enregistrer</button>
  </div>

  <template v-if="!isNew">
    <h2>Photos (réelles, fournies par FootTime)</h2>
    <div v-if="!photos.length" class="empty">Aucune photo.</div>
    <div v-for="p in photos" :key="p.id" class="card">
      <img :src="url(p.storage_path)" class="photo" alt="" />
      <button class="btn alt" style="margin-top:8px" @click="delPhoto(p)">Supprimer</button>
    </div>
    <input type="file" accept="image/jpeg,image/png,image/webp" @change="upload" />
  </template>
</template>
<script setup lang="ts">
const sb = useSb(); const id = useRoute().params.id as string; const isNew = id === 'nouveau'
const days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi']
const equip = [['has_lighting', 'Éclairage'], ['has_lockers', 'Vestiaires'], ['has_showers', 'Douches'], ['has_parking', 'Parking']]
const f = ref<any>({ name: '', neighborhood: '', address: '', description: '', latitude: null, longitude: null, price_per_hour: null,
  rules: '', owner_id: null, has_lighting: false, has_lockers: false, has_showers: false, has_parking: false, is_active: false })
const hours = ref(Array.from({ length: 7 }, (_, i) => ({ weekday: i, opens: '', closes: '' })))
const owners = ref<any[]>([]); const photos = ref<any[]>([]); const msg = ref(''); const ok = ref(false); const busy = ref(false)
const url = (p: string) => sb.storage.from('venue-photos').getPublicUrl(p).data.publicUrl
async function loadPhotos() { photos.value = (await sb.from('venue_photos').select('*').eq('venue_id', id).order('position')).data ?? [] }
onMounted(async () => {
  owners.value = (await sb.from('owners').select('id,profiles(first_name,last_name,email)')).data ?? []
  if (isNew) return
  const { data } = await sb.from('venues').select('*').eq('id', id).single(); if (data) f.value = data
  for (const h of (await sb.from('venue_opening_hours').select('*').eq('venue_id', id)).data ?? []) {
    const d = hours.value[h.weekday]; d.opens = h.opens_at.slice(0, 5); d.closes = h.closes_at.slice(0, 5)
  }
  await loadPhotos()
})
async function save() {
  msg.value = ''; ok.value = false
  if (!f.value.name?.trim()) return (msg.value = 'Le nom est obligatoire.')
  if (!Number.isInteger(f.value.price_per_hour) || f.value.price_per_hour <= 0) return (msg.value = 'Prix par heure : entier supérieur à 0.')
  if (hours.value.some((d) => (d.opens || d.closes) && (!d.opens || !d.closes || d.closes <= d.opens))) return (msg.value = 'Horaires invalides.')
  busy.value = true
  const { venue_photos, cities, ...row } = f.value as any
  if (isNew) row.city_id = (await sb.from('cities').select('id').eq('slug', 'kaolack').single()).data?.id
  const res = isNew ? await sb.from('venues').insert(row).select('id').single() : await sb.from('venues').update(row).eq('id', id).select('id').single()
  if (res.error) { busy.value = false; return (msg.value = "Échec de l'enregistrement : " + res.error.message) }
  const vid = res.data.id
  await sb.from('venue_opening_hours').delete().eq('venue_id', vid)
  const rows = hours.value.filter((d) => d.opens && d.closes).map((d) => ({ venue_id: vid, weekday: d.weekday, opens_at: d.opens, closes_at: d.closes }))
  if (rows.length) { const { error } = await sb.from('venue_opening_hours').insert(rows); if (error) { busy.value = false; return (msg.value = error.message) } }
  busy.value = false
  if (isNew) return navigateTo(`/admin/terrains/${vid}`)
  ok.value = true; msg.value = 'Terrain enregistré.'
}
async function upload(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]; if (!file) return
  const path = `${id}/${Date.now()}-${file.name.replace(/[^\w.-]/g, '_')}`
  const up = await sb.storage.from('venue-photos').upload(path, file)
  if (up.error) return (msg.value = up.error.message)
  await sb.from('venue_photos').insert({ venue_id: id, storage_path: path, position: photos.value.length })
  await loadPhotos()
}
async function delPhoto(p: any) {
  await sb.storage.from('venue-photos').remove([p.storage_path]); await sb.from('venue_photos').delete().eq('id', p.id); await loadPhotos()
}
</script>
