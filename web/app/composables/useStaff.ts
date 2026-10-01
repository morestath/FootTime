export const useStaff = () => {
  const sb = useSb(); const { user } = useAuth()
  const venues = useState<any[]>('staffVenues', () => []); const sel = useState<string>('proVenue', () => '')
  const loaded = useState('staffLoaded', () => false)
  async function load(force = false) {
    if (loaded.value && !force) return
    if (!user.value) { venues.value = []; return }
    const uid = user.value.id; const list: any[] = []
    const { data: o } = await sb.from('owners').select('id,status').eq('profile_id', uid).maybeSingle()
    if (o?.status === 'ACTIVE')
      for (const v of (await sb.from('venues').select('id,name').eq('owner_id', o.id)).data ?? []) list.push({ ...v, owner: true, perms: { finance: true } })
    const ms = (await sb.from('venue_managers').select('permissions,venues(id,name)').eq('profile_id', uid).eq('status', 'ACTIVE')).data ?? []
    for (const m of ms as any[]) if (m.venues && !list.some((x) => x.id === m.venues.id)) list.push({ ...m.venues, owner: false, perms: m.permissions ?? {} })
    venues.value = list; if (!list.some((v) => v.id === sel.value)) sel.value = list[0]?.id ?? ''
    loaded.value = true
  }
  const current = computed(() => venues.value.find((v) => v.id === sel.value))
  const finance = computed(() => !!(current.value?.owner || current.value?.perms?.finance))
  return { venues, sel, current, finance, load }
}
