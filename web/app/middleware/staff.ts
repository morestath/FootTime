// Confort d'interface : l'accès réel aux données est limité par la RLS.
export default defineNuxtRouteMiddleware(async () => {
  const { user, init } = useAuth(); await init()
  if (!user.value) return navigateTo('/connexion?redirect=/pro')
  const s = useStaff(); await s.load()
  if (!s.venues.value.length) return navigateTo('/')
})
