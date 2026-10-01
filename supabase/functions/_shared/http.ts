export const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message) }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    try {
      if (req.method !== 'POST') throw new HttpError(405, 'Méthode non autorisée')
      return await fn(req)
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status)
      console.error(e)
      return json({ error: 'Erreur interne' }, 500)
    }
  }
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try { return await req.json() } catch { throw new HttpError(400, 'Corps JSON invalide') }
}

export function parseFutureDate(v: unknown): string {
  if (typeof v !== 'string') throw new HttpError(400, 'Date invalide')
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) throw new HttpError(400, 'Date invalide')
  return d.toISOString()
}
