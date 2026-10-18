export const esc = (v: unknown): string =>
  String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string);

export const finite = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

export const gain = (v: number | null | undefined): string => (finite(v) ? (v >= 0 ? '+' : '') + v.toFixed(1) : '—');

export const times = (v: number | null | undefined): string => (finite(v) ? '×' + v.toFixed(2) : '—');

// toneOf: green with 30% or more left, amber from 10%, red below; amber too when the pace says
// tight while plenty is left (as the status line colours it).
export function toneOf(left: number, pace: string): 'ok' | 'tight' | 'warn' {
  if (left < 10 || pace === 'exhausted') return 'warn';
  if (left < 30 || pace === 'tight') return 'tight';
  return 'ok';
}

export const headroomTone = (h: string): string => ({ spend: 'ok', normal: 'ok', conserve: 'tight', exhausted: 'warn' } as Record<string, string>)[h] ?? 'dim';

// age: minutes since an ISO time, or null.
export function ageMinutes(iso: string | undefined, now: number): number | null {
  const t = Date.parse(iso ?? '');
  return Number.isFinite(t) ? Math.max(0, Math.round((now - t) / 60000)) : null;
}
