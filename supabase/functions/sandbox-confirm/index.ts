// Sandbox uniquement : confirme un paiement de test. Refusé dès que PAYMENTS_SANDBOX != 'true' ou APP_ENV = 'production'.
import { handle, json, readJson, HttpError } from '../_shared/http.ts'
import { admin, requireUser } from '../_shared/supabase.ts'
import { sandboxAllowed } from '../_shared/providers.ts'

Deno.serve(handle(async (req) => {
  if (!sandboxAllowed()) throw new HttpError(403, 'Mode sandbox désactivé')
  const user = await requireUser(req)
  const body = await readJson(req)
  const ref = String(body.reference ?? '')
  if (!/^SBX-[0-9a-f-]{36}$/i.test(ref)) throw new HttpError(400, 'Référence invalide')

  const { data: pay } = await admin.from('payments')
    .select('amount, bookings!inner(player_id)').eq('provider', 'SANDBOX').eq('provider_reference', ref).single()
  // deno-lint-ignore no-explicit-any
  if (!pay || (pay as any).bookings.player_id !== user.id) throw new HttpError(404, 'Paiement introuvable')

  const { data: outcome, error } = await admin.rpc('settle_payment', {
    p_provider: 'SANDBOX', p_reference: ref, p_status: body.fail ? 'FAILED' : 'SUCCEEDED',
    p_amount: pay.amount, p_raw: { sandbox: true },
  })
  if (error) throw new HttpError(500, error.message)
  return json({ outcome })
}))
