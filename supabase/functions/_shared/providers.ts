import { HttpError } from './http.ts'

export interface CheckoutInput {
  paymentId: string
  bookingCode: string
  amount: number // FCFA, entier
  successUrl: string
  errorUrl: string
}
export interface CheckoutResult { reference: string; checkoutUrl: string }
export interface WebhookEvent {
  reference: string
  status: 'SUCCEEDED' | 'FAILED' | 'CANCELLED'
  amount: number
  raw: unknown
}
export interface PaymentProvider {
  name: string
  assertConfigured(): void
  createCheckout(i: CheckoutInput): Promise<CheckoutResult>
  /** Vérifie l'authenticité (signature + confirmation serveur-à-serveur). null = événement ignoré. */
  parseWebhook(raw: string, headers: Headers): Promise<WebhookEvent | null>
}

const env = (k: string) => Deno.env.get(k)

async function hmacHex(secret: string, data: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data))
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('')
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let r = 0
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return r === 0
}

// ───────── WAVE ─────────
// ⚠ À valider avec la documentation de votre compte marchand Wave et l'environnement de test fourni.
const wave: PaymentProvider = {
  name: 'WAVE',
  assertConfigured() {
    if (!env('WAVE_API_KEY') || !env('WAVE_WEBHOOK_SECRET'))
      throw new HttpError(503, 'Wave n\'est pas configuré (WAVE_API_KEY, WAVE_WEBHOOK_SECRET manquants)')
  },
  async createCheckout(i) {
    const res = await fetch('https://api.wave.com/v1/checkout/sessions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env('WAVE_API_KEY')}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: String(i.amount), currency: 'XOF',
        client_reference: i.paymentId,
        success_url: i.successUrl, error_url: i.errorUrl,
      }),
    })
    if (!res.ok) throw new Error(`Wave checkout ${res.status}: ${await res.text()}`)
    const s = await res.json()
    return { reference: s.id, checkoutUrl: s.wave_launch_url }
  },
  async parseWebhook(raw, headers) {
    const sigHeader = headers.get('wave-signature') ?? ''
    const parts = Object.fromEntries(sigHeader.split(',').map((p) => p.split('=') as [string, string]))
    const t = parts['t']
    const candidates = sigHeader.split(',').filter((p) => p.startsWith('v1=')).map((p) => p.slice(3))
    if (!t || candidates.length === 0) throw new HttpError(401, 'Signature absente')
    if (Math.abs(Date.now() / 1000 - Number(t)) > 300) throw new HttpError(401, 'Signature expirée')
    const expected = await hmacHex(env('WAVE_WEBHOOK_SECRET')!, t + raw)
    if (!candidates.some((c) => safeEqual(c, expected))) throw new HttpError(401, 'Signature invalide')

    const evt = JSON.parse(raw)
    const id = evt?.data?.id
    if (!id) return null
    // Confirmation serveur-à-serveur : on ne fait pas confiance au corps du webhook seul.
    const res = await fetch(`https://api.wave.com/v1/checkout/sessions/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${env('WAVE_API_KEY')}` },
    })
    if (!res.ok) throw new Error(`Wave verify ${res.status}`)
    const s = await res.json()
    let status: WebhookEvent['status'] | null = null
    if (s.payment_status === 'succeeded') status = 'SUCCEEDED'
    else if (s.payment_status === 'cancelled') status = 'CANCELLED'
    else if (s.checkout_status === 'expired') status = 'FAILED'
    if (!status) return null // en cours : on attend le prochain événement
    return { reference: s.id, status, amount: Number(s.amount), raw: s }
  },
}

// ───────── ORANGE MONEY ─────────
// Non implémenté : nécessite un contrat marchand Orange Money Sénégal et sa documentation API.
const orange: PaymentProvider = {
  name: 'ORANGE_MONEY',
  assertConfigured() {
    throw new HttpError(503, 'Orange Money n\'est pas encore intégré (identifiants marchand requis)')
  },
  createCheckout() { throw new HttpError(503, 'Orange Money non intégré') },
  parseWebhook() { throw new HttpError(503, 'Orange Money non intégré') },
}

// ───────── SANDBOX (jamais en production) ─────────
export function sandboxAllowed(): boolean {
  return env('PAYMENTS_SANDBOX') === 'true' && env('APP_ENV') !== 'production'
}
const sandbox: PaymentProvider = {
  name: 'SANDBOX',
  assertConfigured() {
    if (!sandboxAllowed()) throw new HttpError(403, 'Mode sandbox désactivé')
  },
  createCheckout(i) {
    const ref = `SBX-${i.paymentId}`
    return Promise.resolve({ reference: ref, checkoutUrl: `${env('APP_URL')}/sandbox-pay?ref=${ref}` })
  },
  parseWebhook() { throw new HttpError(400, 'Pas de webhook en sandbox') },
}

const registry: Record<string, PaymentProvider> = { WAVE: wave, ORANGE_MONEY: orange, SANDBOX: sandbox }

export function getProvider(name: unknown): PaymentProvider {
  const p = typeof name === 'string' ? registry[name.toUpperCase()] : undefined
  if (!p) throw new HttpError(400, 'Moyen de paiement inconnu')
  return p
}
