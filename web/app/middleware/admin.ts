// Confort d'interface uniquement : la vraie protection est la RLS côté Supabase.
export default defineNuxtRouteMiddleware(async () => {
  const { user, init } = useAuth(); await init()
  if (!user.value) return navigateTo('/connexion?redirect=/admin')
  const { data } = await useSb().from('profiles').select('role').eq('id', user.value.id).single()
  if (data?.role !== 'ADMIN_FOOTTIME') return navigateTo('/')
})
