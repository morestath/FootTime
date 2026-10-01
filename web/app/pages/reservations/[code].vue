<template>
  <main>
    <p v-if="!b" class="muted">Chargement…</p>
    <template v-else>
      <h1>{{ b.status === 'CONFIRMED' ? 'Réservation confirmée' : 'Réservation ' + b.code }}</h1>
      <p v-if="b.status === 'PENDING_PAYMENT'" class="muted">Nous attendons la confirmation de votre paiement…</p>
      <div class="card">
        <div class="row"><span>Code</span><b>{{ b.code }}</b></div>
        <div class="row"><span>Terrain</span><span>{{ b.venues?.name }}</span></div>
        <div class="row"><span>Date et heure</span><span>{{ fmtDT(startMs) }}</span></div>
        <div class="row"><span>Durée</span><span>{{ b.duration_hours }} h</span></div>
        <div class="row"><span>Total</span><span>{{ fcfa(b.total_amount) }}</span></div>
        <div class="row"><span>Avance</span><span>{{ fcfa(b.deposit_amount) }}</span></div>
        <div class="row total"><span>Reste à payer</span><span>{{ fcfa(b.balance_amount) }}</span></div>
      </div>
      <span class="badge" :class="{ warn: b.status !== 'CONFIRMED' }">{{ b.status }}</span>

      <template v-if="b.status === 'CONFIRMED'">
        <h2>Modifier</h2>
        <p class="muted">Modifications restantes : {{ remaining }} sur {{ max }}</p>
        <button v-if="remaining > 0 && !showMod" class="btn alt" @click="openMod">Changer l'horaire ({{ b.duration_hours }} h)</button>
        <div v-if="showMod" class="card">
          <input v-model="mdate" type="date" :min="today" @change="mpick = null; loadBusy()" />
          <p v-if="!openHours.length" class="empty">Terrain fermé ce jour-là.</p>
          <div class="chips"><button v-for="h in openHours" :key="h" class="chip" :class="{ on: mpick === h }" :disabled="!validStart(h)" @click="mpick = h">{{ h }} h</button></div>
          <p v-if="msg" :class="ok ? 'muted' : 'err'">{{ msg }}</p>
          <button class="btn" :disabled="mpick === null || busy" @click="modify">Confirmer le changement</button>
          <p class="muted">Cette modification compte dans votre limite.</p>
        </div>
        <p v-else-if="msg" :class="ok ? 'muted' : 'err'">{{ msg }}</p>
      </template>

      <template v-if="b.status === 'COMPLETED'">
        <h2>Votre avis</h2>
        <p v-if="review" class="muted">Merci ! Votre avis ({{ review.rating }}/5) est {{ review.status === 'APPROVED' ? 'publié' : 'en attente de modération' }}.</p>
        <div v-else class="card">
          <select v-model.number="rating"><option v-for="n in [5, 4, 3, 2, 1]" :key="n" :value="n">{{ n }} / 5</option></select>
          <input v-model="comment" placeholder="Commentaire (facultatif)" />
          <p v-if="msg" class="err">{{ msg }}</p>
          <button class="btn" @click="sendReview">Publier mon avis</button>
        </div>
      </template>
    </template>
  </main>
</template>
<script setup lang="ts">
// Le retour du prestataire ne prouve rien : on lit le statut écrit par le serveur.
const sb = useSb(); const { user } = useAuth(); const code = useRoute().params.code as string
const b = ref<any>(null); const max = ref(2); let timer: any
const startMs = computed(() => (b.value ? rangeParts(b.value.during).startMs : 0))
const remaining = computed(() => max.value - (b.value?.modification_count ?? 0))
const msg = ref(''); const ok = ref(false); const busy = ref(false)
const review = ref<any>(null); const rating = ref(5); const comment = ref('')
// modification
const showMod = ref(false); const opening = ref<any[]>([]); const busyR = ref<any[]>([])
const pad = (n: number) => String(n).padStart(2, '0'); const today = new Date().toISOString().slice(0, 10)
const mdate = ref(today); const mpick = ref<number | null>(null)

async function load() {
  const { data } = await sb.from('bookings').select('id,code,venue_id,status,during,duration_hours,modification_count,total_amount,deposit_amount,balance_amount,venues(name)').eq('code', code).single()
  b.value = data
  if (data && data.status !== 'PENDING_PAYMENT') clearInterval(timer)
  if (data?.status === 'COMPLETED')
    review.value = (await sb.from('reviews').select('rating,status').eq('booking_id', data.id).maybeSingle()).data
}
async function loadBusy() {
  busyR.value = (await sb.rpc('get_busy_ranges', { p_venue: b.value.venue_id, p_from: `${mdate.value}T00:00:00Z`, p_to: `${mdate.value}T23:59:59Z` })).data ?? []
}
async function openMod() {
  msg.value = ''
  opening.value = (await sb.from('venue_opening_hours').select('weekday,opens_at,closes_at').eq('venue_id', b.value.venue_id)).data ?? []
  await loadBusy(); showMod.value = true
}
const openHours = computed(() => {
  const o = opening.value.find((x) => x.weekday === new Date(`${mdate.value}T00:00:00Z`).getUTCDay())
  if (!o) return []
  const a = parseInt(o.opens_at), z = parseInt(o.closes_at)
  return Array.from({ length: Math.max(0, z - a) }, (_, i) => a + i)
})
function free(h: number) {
  const s = Date.parse(`${mdate.value}T${pad(h)}:00:00Z`), e = s + 3600e3
  return s > Date.now() && !busyR.value.some((r) => Date.parse(r.starts_at) < e && Date.parse(r.ends_at) > s)
}
const validStart = (h: number) => Array.from({ length: b.value.duration_hours }, (_, i) => h + i).every((x) => openHours.value.includes(x) && free(x))
async function modify() {
  msg.value = ''; busy.value = true
  const { error } = await sb.functions.invoke('modify-booking', { body: { booking_id: b.value.id, new_start_at: `${mdate.value}T${pad(mpick.value!)}:00:00Z` } })
  busy.value = false
  if (error) { ok.value = false; msg.value = await fnError(error); return loadBusy() }
  showMod.value = false; mpick.value = null; ok.value = true; msg.value = 'Réservation modifiée.'; await load()
}
async function sendReview() {
  msg.value = ''
  const { error } = await sb.from('reviews').insert({ booking_id: b.value.id, venue_id: b.value.venue_id, player_id: user.value.id, rating: rating.value, comment: comment.value.trim() || null, status: 'PENDING' })
  if (error) return (msg.value = "Impossible d'enregistrer votre avis."); await load()
}
onMounted(async () => {
  const m = (await sb.from('platform_settings').select('value').eq('key', 'max_modifications').single()).data
  if (m) max.value = Number(m.value)
  await load(); timer = setInterval(() => b.value?.status === 'PENDING_PAYMENT' && load(), 3000)
})
onBeforeUnmount(() => clearInterval(timer))
</script>
