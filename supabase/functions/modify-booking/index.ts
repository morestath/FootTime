import { handle, json, readJson, parseFutureDate, HttpError, UUID_RE } from '../_shared/http.ts'
import { admin, requireUser, rpcError } from '../_shared/supabase.ts'

Deno.serve(handle(async (req) => {
  const user = await requireUser(req)
  const body = await readJson(req)
  const bookingId = String(body.booking_id ?? '')
  if (!UUID_RE.test(bookingId)) throw new HttpError(400, 'Réservation invalide')
  const newStart = parseFutureDate(body.new_start_at)

  const { data: b, error } = await admin.rpc('modify_booking', {
    p_player: user.id, p_booking: bookingId, p_new_start: newStart,
  })
  if (error) throw rpcError(error.message)

  const { data: max } = await admin.from('platform_settings').select('value').eq('key', 'max_modifications').single()
  return json({
    booking: { id: b.id, code: b.code, status: b.status, start_at: newStart, hours: b.duration_hours },
    modifications_used: b.modification_count,
    modifications_remaining: Number(max?.value ?? 2) - b.modification_count,
  })
}))
