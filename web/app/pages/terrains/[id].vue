<template>
  <main>
    <p v-if="!v && !error" class="muted">Chargement…</p>
    <p v-if="error" class="err">{{ error }}</p>
    <template v-if="v">
      <div v-if="photos.length" style="display:flex;gap:8px;overflow-x:auto;scroll-snap-type:x mandatory">
        <img v-for="u in photos" :key="u" :src="u" :alt="v.name" class="photo" style="min-width:100%;scroll-snap-align:start" />
      </div>
      <div v-else class="photo">Photo à venir</div>
      <h1 style="margin-top:12px">{{ v.name }}</h1>
      <p class="muted">{{ [v.neighborhood, v.address].filter(Boolean).join(' · ') }}</p>
      <p v-if="v.description">{{ v.description }}</p>
      <div class="chips">
        <span v-for="e in equip" :key="e" class="badge">{{ e }}</span>
      </div>
      <a v-if="v.latitude && v.longitude" class="muted" target="_blank" rel="noopener"
         :href="`https://www.openstreetmap.org/?mlat=${v.latitude}&mlon=${v.longitude}#map=17/${v.latitude}/${v.longitude}`">Voir sur la carte</a>

      <h2>Réserver</h2>
      <div class="card">
        <label class="muted">Date</label>
        <input v-model="date" type="date" :min="today" @change="pick = null; loadBusy()" />
        <label class="muted">Durée</label>
        <select v-model.number="hours" @change="pick = null">
          <option v-for="n in 4" :key="n" :value="n">{{ n }} heure{{ n > 1 ? 's' : '' }}</option>
        </select>
        <label class="muted">Heure de début</label>
        <p v-if="!openHours.length" class="empty">Terrain fermé ce jour-là.</p>
        <div class="chips">
          <button v-for="h in openHours" :key="h" class="chip" :class="{ on: pick === h }"
                  :disabled="!validStart(h)" @click="pick = h">{{ h }} h</button>
        </div>

        <template v-if="pick !== null">
          <div class="row"><span>{{ fcfa(v.price_per_hour) }} × {{ hours }} h</span><span>{{ fcfa(total) }}</span></div>
          <div class="row"><span>Avance à payer maintenant</span><b>{{ fcfa(deposit) }}</b></div>
          <div class="row total"><span>Reste à payer sur place</span><span>{{ fcfa(total - deposit) }}</span></div>

          <h2>Conditions</h2>
          <p class="muted"><b>Annulation :</b> {{ settings.cancellation_rules }}</p>
          <p class="muted"><b>Absence :</b> {{ settings.no_show_rules }}</p>
          <p v-if="v.rules" class="muted"><b>Règles du terrain :</b> {{ v.rules }}</p>
          <label class="muted"><input v-model="accepted" type="checkbox" style="width:auto;margin-right:8px" />J'ai lu et j'accepte ces conditions</label>

          <label class="muted" style="display:block;margin-top:10px">Moyen de paiement</label>
          <select v-model="provider">
            <option value="WAVE">Wave</option>
            <option value="ORANGE_MONEY" disabled>Orange Money (bientôt)</option>
            <option v-if="sandbox" value="SANDBOX">Paiement de test (sandbox)</option>
          </select>
          <p v-if="msg" class="err">{{ msg }}</p>
          <button class="btn" :disabled="!accepted || busy" @click="book">{{ busy ? 'Patientez…' : `Payer l'avance ${fcfa(deposit)}` }}</button>
          <p class="muted">Le créneau est bloqué {{ settings.pending_payment_ttl_minutes }} min pendant le paiement. Vous pourrez modifier la réservation {{ settings.max_modifications }} fois au maximum.</p>
        </template>
      </div>

      <h2>Avis</h2>
      <div v-if="!reviews.length" class="empty">Aucun avis pour le moment.</div>
      <div v-for="(r, i) in reviews" :key="i" class="card">
        <span class="badge">★ {{ r.rating }}</span> <span v-if="r.comment">{{ r.comment }}</span>
      </div>
    </template>
  </main>
</template>
<script setup lang="ts">
// Hypothèse Kaolack : Africa/Dakar = UTC+0 toute l'année, donc heure locale = heure UTC.
// Pour ajouter une ville à fuseau différent, convertir ici selon cities.timezone.
const sb = useSb(); const { user } = useAuth(); const route = useRoute()
const sandbox = useRuntimeConfig().public.sandbox
const id = route.params.id as string
const v = ref<any>(null); const photos = ref<string[]>([]); const reviews = ref<any[]>([]); const opening = ref<any[]>([]); const busy_ = ref<any[]>([])
const settings = ref<any>({ cancellation_rules: '', no_show_rules: '', deposit_percent: 30, pending_payment_ttl_minutes: 15, max_modifications: 2 })
const error = ref(''); const msg = ref(''); const busy = ref(false); const accepted = ref(false)
const pad = (n: number) => String(n).padStart(2, '0')
const today = new Date().toISOString().slice(0, 10)
const date = ref(today); const hours = ref(1); const pick = ref<number | null>(null)
const provider = ref('WAVE')

const equip = computed(() => v.value ? [
  v.value.has_lighting && 'Éclairage', v.value.has_lockers && 'Vestiaires', v.value.has_showers && 'Douches',
  v.value.has_parking && 'Parking', ...(v.value.amenities ?? [])].filter(Boolean) : [])

onMounted(async () => {
  const { data, error: e } = await sb.from('venues').select('*,venue_photos(storage_path,position)').eq('id', id).single()
  if (e || !data) return (error.value = 'Terrain introuvable.')
  v.value = data
  photos.value = [...(data.venue_photos ?? [])].sort((a: any, b: any) => a.position - b.position)
    .map((p: any) => sb.storage.from('venue-photos').getPublicUrl(p.storage_path).data.publicUrl)
  reviews.value = (await sb.from('reviews').select('rating,comment').eq('venue_id', id).eq('status', 'APPROVED').order('created_at', { ascending: false }).limit(20)).data ?? []
  opening.value = (await sb.from('venue_opening_hours').select('weekday,opens_at,closes_at').eq('venue_id', id)).data ?? []
  const s = (await sb.from('platform_settings').select('key,value')).data ?? []   // réservé aux connectés (RLS)
  for (const r of s) settings.value[r.key] = r.value
  if (!sandbox) provider.value = 'WAVE'
  await loadBusy()
})

async function loadBusy() {
  const { data } = await sb.rpc('get_busy_ranges', { p_venue: id, p_from: `${date.value}T00:00:00Z`, p_to: `${date.value}T23:59:59Z` })
  busy_.value = data ?? []
}
const openHours = computed(() => {
  const wd = new Date(`${date.value}T00:00:00Z`).getUTCDay()
  const o = opening.value.find((x) => x.weekday === wd)
  if (!o) return []
  const a = parseInt(o.opens_at), b = parseInt(o.closes_at)
  return Array.from({ length: Math.max(0, b - a) }, (_, i) => a + i)
})
function slotFree(h: number) {
  const s = Date.parse(`${date.value}T${pad(h)}:00:00Z`), e = s + 3600e3
  return s > Date.now() && !busy_.value.some((r) => Date.parse(r.starts_at) < e && Date.parse(r.ends_at) > s)
}
const validStart = (h: number) => Array.from({ length: hours.value }, (_, i) => h + i).every((x) => openHours.value.includes(x) && slotFree(x))
const total = computed(() => (v.value?.price_per_hour ?? 0) * hours.value)
const deposit = computed(() => Math.floor((total.value * Number(settings.value.deposit_percent) + 99) / 100)) // affichage ; le serveur fait foi

async function book() {
  msg.value = ''
  if (!user.value) return navigateTo(`/connexion?redirect=${route.fullPath}`)
  busy.value = true
  const { data, error: e } = await sb.functions.invoke('create-booking', {
    body: { venue_id: id, start_at: `${date.value}T${pad(pick.value!)}:00:00Z`, hours: hours.value, provider: provider.value } })
  busy.value = false
  if (e) { msg.value = await fnError(e); await loadBusy(); pick.value = null; return }
  window.location.href = data.checkout_url
}
</script>
