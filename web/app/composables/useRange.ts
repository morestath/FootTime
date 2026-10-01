// PostgREST renvoie tstzrange en texte : ["2026-10-03 18:00:00+00","2026-10-03 21:00:00+00")
const toMs = (s: string) => Date.parse(s.replace(' ', 'T').replace(/([+-]\d\d)$/, '$1:00'))
export function rangeParts(d: string) {
  const m = String(d).match(/"([^"]+)","([^"]+)"/)
  return { startMs: m ? toMs(m[1]) : NaN, endMs: m ? toMs(m[2]) : NaN }
}
export const fmtDT = (ms: number) => new Date(ms).toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Africa/Dakar' })
