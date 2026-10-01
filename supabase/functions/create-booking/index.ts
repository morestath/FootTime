import { handle, json, readJson, parseFutureDate, HttpError, UUID_RE } from '../_shared/http.ts'
import { admin, requireUser, rpcError } from '../_shared/supabase.ts'
import { getProvider } from '../_shared/providers.ts'

Deno.serve(handle(async (req) => {
  const user = await requireUser(req)
  const body = await readJson(req)

  const venueId = String(body.venue_id ?? '')
  const hours = Number(body.hours)
  if (!UUID_RE.test(venueId)) throw new HttpError(400, 'Terrain invalide')
  if (!Number.isInteger(hours) || hours < 1 || hours > 8) throw new HttpError(400, 'Durée invalide')
  const startAt = parseFutureDate(body.start_at)

  // Échec rapide si le moyen de paiement n'est pas configuré : on ne bloque pas de créneau pour rien.
  const provider = getProvider(body.provider)
  provider.assertConfigured()

  // Création atomique (horaires, fermetures, anti-chevauchement) côté base.
  const { data: booking, error } = await admin.rpc('create_pending_booking', {
    p_player: user.id, p_venue: venueId, p_start: startAt, p_hours: hours,
  })
  if (error) throw rpcError(error.message)
  if (booking.deposit_amount <= 0) {
    await admin.from('bookings').update({ status: 'CANCELLED' }).eq('id', booking.id)
    throw new HttpError(422, 'Montant d\'avance non configuré')
  }

  const { data: payment, error: payErr } = await admin.from('payments')
    .insert({ booking_id: booking.id, provider: provider.name, amount: booking.deposit_amount })
    .select().single()
  if (payErr) {
    await admin.from('bookings').update({ status: 'CANCELLED' }).eq('id', booking.id)
    throw payErr
  }

  try {
    const appUrl = Deno.env.get('APP_URL') ?? ''
    const back = `${appUrl}/reservations/${booking.code}`
    const checkout = await provider.createCheckout({
      paymentId: payment.id, bookingCode: booking.code, amount: payment.amount,
      successUrl: `${back}?retour=1`, errorUrl: `${back}?erreur=1`,
    })
    await admin.from('payments').update({ provider_reference: checkout.reference }).eq('id', payment.id)
    return json({
      booking: {
        id: booking.id, code: booking.code, status: booking.status,
        start_at: startAt, hours,
        total_amount: booking.total_amount, deposit_amount: booking.deposit_amount,
        balance_amount: booking.balance_amount, expires_at: booking.expires_at,
      },
      payment_id: payment.id,
      checkout_url: checkout.checkoutUrl,
    }, 201)
  } catch (e) {
    console.error('checkout error', e)
    await admin.from('payments').update({ status: 'FAILED' }).eq('id', payment.id)
    await admin.from('bookings').update({ status: 'CANCELLED' }).eq('id', booking.id)
    throw new HttpError(502, 'Le prestataire de paiement est indisponible, réessayez')
  }
}))
