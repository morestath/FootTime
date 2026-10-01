// Déployer avec --no-verify-jwt : l'authenticité vient de la signature du prestataire.
import { handle, json, HttpError } from '../_shared/http.ts'
import { admin } from '../_shared/supabase.ts'
import { getProvider } from '../_shared/providers.ts'

Deno.serve(handle(async (req) => {
  const providerName = new URL(req.url).searchParams.get('provider')
  const provider = getProvider(providerName)
  const raw = await req.text()               // corps brut : nécessaire à la vérification de signature

  const event = await provider.parseWebhook(raw, req.headers)   // 401 si signature invalide
  if (!event) return json({ ok: true, ignored: true })

  const { data: outcome, error } = await admin.rpc('settle_payment', {
    p_provider: provider.name,
    p_reference: event.reference,
    p_status: event.status,
    p_amount: event.amount,
    p_raw: event.raw,
  })
  if (error) throw new HttpError(500, error.message)            // 5xx => le prestataire réessaiera
  if (outcome === 'AMOUNT_MISMATCH' || outcome === 'NEEDS_REFUND' || outcome === 'UNKNOWN_PAYMENT')
    console.error('payment-webhook à examiner', outcome, event.reference)
  return json({ ok: true, outcome })
}))
