// Pure study clock: minutes until reset divided by the window's duration, never quota remaining.
// The fixtures use these nominal periods; a real reader must supply an exact duration for a calendar month.
const MINUTES = {'5h': 300, day: 1440, daily: 1440, week: 10080, weekly: 10080, month: 43200, monthly: 43200};
const clamp = n => Math.max(0, Math.min(1, n));
// Shared d/h/m formatter: preserve the cockpit's existing reset wording exactly.
export const duration = m => m == null ? '--' : m < 60 ? `${Math.round(m)}m` : m < 1440 ? `${Math.floor(m / 60)}h${String(Math.round(m % 60)).padStart(2, '0')}` : `${Math.floor(m / 1440)}d${Math.floor(m % 1440 / 60)}h`;
export function timeLeft(w) {
  if (!w || !Number.isFinite(w.resetIn)) return null;
  if (w.resetIn <= 0) return 0;
  const duration = w.durationMinutes ?? MINUTES[w.period || w.kind];
  if (Number.isFinite(duration) && duration > 0) return clamp(w.resetIn / duration);
  return Number.isFinite(w.elapsed) ? clamp(1 - w.elapsed) : null;
}
// Any positive time retains one point. Zero only means reset reached; null means unknown, not zero.
export const litTimeDots = f => f == null ? null : f <= 0 ? 0 : Math.max(1, Math.min(10, Math.round(f * 10)));
