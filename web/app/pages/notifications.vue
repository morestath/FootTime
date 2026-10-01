<template>
  <main>
    <h1>Notifications</h1>
    <div v-if="!user" class="empty">Connectez-vous pour voir vos notifications.</div>
    <div v-else-if="!list.length" class="empty">Aucune notification.</div>
    <template v-else>
      <button class="btn alt" style="margin-bottom:12px" @click="readAll">Tout marquer comme lu</button>
      <div v-for="n in list" :key="n.id" class="card" @click="read(n)">
        <div class="row"><b>{{ n.title }}</b><span v-if="!n.read_at" class="badge">Nouveau</span></div>
        <div class="muted">{{ n.body }}</div>
        <div class="muted">{{ fmtDT(Date.parse(n.created_at)) }}</div>
      </div>
    </template>
  </main>
</template>
<script setup lang="ts">
const sb = useSb(); const { user } = useAuth(); const list = ref<any[]>([])
const load = async () => { if (user.value) list.value = (await sb.from('notifications').select('id,title,body,read_at,created_at').order('created_at', { ascending: false }).limit(50)).data ?? [] }
async function read(n: any) { if (!n.read_at) { await sb.from('notifications').update({ read_at: new Date().toISOString() }).eq('id', n.id); await load() } }
async function readAll() { await sb.from('notifications').update({ read_at: new Date().toISOString() }).is('read_at', null); await load() }
onMounted(load)
</script>
