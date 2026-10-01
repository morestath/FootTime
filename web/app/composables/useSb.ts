import { createClient, type SupabaseClient } from '@supabase/supabase-js'
let client: SupabaseClient
export const useSb = () => {
  const c = useRuntimeConfig().public
  return (client ??= createClient(c.supabaseUrl as string, c.supabaseAnonKey as string))
}
// Message d'erreur lisible d'une Edge Function (corps JSON { error }).
export async function fnError(error: any): Promise<string> {
  try { return (await error.context.json()).error ?? 'Erreur' } catch { return error?.message ?? 'Erreur' }
}
export const fcfa = (n: number) => new Intl.NumberFormat('fr-FR').format(n) + ' FCFA'
