<template>
  <main>
    <h1>{{ signup ? 'Créer un compte' : 'Connexion' }}</h1>
    <template v-if="signup">
      <input v-model="first" placeholder="Prénom" /><input v-model="last" placeholder="Nom" />
      <input v-model="phone" placeholder="Téléphone" inputmode="tel" />
    </template>
    <input v-model="email" type="email" placeholder="Email" />
    <input v-model="password" type="password" placeholder="Mot de passe (8 caractères min.)" />
    <p v-if="msg" class="err">{{ msg }}</p>
    <button class="btn" :disabled="busy" @click="submit">{{ signup ? 'Créer mon compte' : 'Me connecter' }}</button>
    <p class="muted" style="text-align:center;cursor:pointer" @click="signup = !signup">
      {{ signup ? "J'ai déjà un compte" : 'Pas de compte ? Inscription' }}</p>
  </main>
</template>
<script setup lang="ts">
const sb = useSb(); const route = useRoute()
const signup = ref(false); const busy = ref(false); const msg = ref('')
const email = ref(''), password = ref(''), first = ref(''), last = ref(''), phone = ref('')
async function submit() {
  msg.value = ''
  if (!email.value || password.value.length < 8) return (msg.value = 'Email et mot de passe (8 caractères min.) requis.')
  if (signup.value && (!first.value || !last.value || !phone.value)) return (msg.value = 'Prénom, nom et téléphone requis.')
  busy.value = true
  const res = signup.value
    ? await sb.auth.signUp({ email: email.value, password: password.value,
        options: { data: { first_name: first.value, last_name: last.value, phone: phone.value } } })
    : await sb.auth.signInWithPassword({ email: email.value, password: password.value })
  busy.value = false
  if (res.error) return (msg.value = res.error.message)
  if (signup.value && !res.data.session) return (msg.value = 'Compte créé : confirmez votre email puis connectez-vous.')
  navigateTo((route.query.redirect as string) || '/reservations')
}
</script>
