import { createClient } from 'npm:@supabase/supabase-js@2'
import { HttpError } from './http.ts'

// Client service_role : uniquement côté Edge Functions, jamais exposé au navigateur.
export const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } },
)

export async function requireUser(req: Request) {
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!token) throw new HttpError(401, 'Non authentifié')
  const { data, error } = await admin.auth.getUser(token)
  if (error || !data.user) throw new HttpError(401, 'Session invalide')
  const { data: profile } = await admin.from('profiles').select('status').eq('id', data.user.id).single()
  if (profile?.status !== 'ACTIVE') throw new HttpError(403, 'Compte inactif')
  return data.user
}

// Les fonctions SQL lèvent des messages métier en français : on les renvoie tels quels.
export function rpcError(message: string): HttpError {
  return new HttpError(/déjà réservé/i.test(message) ? 409 : 422, message)
}
