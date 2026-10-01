export const useAuth = () => {
  const sb = useSb()
  const user = useState<any>('user', () => null)
  const ready = useState('authReady', () => false)
  async function init() {
    if (ready.value) return
    user.value = (await sb.auth.getSession()).data.session?.user ?? null
    sb.auth.onAuthStateChange((_e, s) => { user.value = s?.user ?? null })
    ready.value = true
  }
  const signOut = async () => { await sb.auth.signOut(); navigateTo('/') }
  return { user, init, signOut }
}
