// Owner decision 2026-10-23: critical red is #EF4444; jets consume this same token.
// Round E: quota fills always express status. Vendor colour belongs only to identity marks.
export const STATUS_HEX = {ok: '#5ad9ba', mid: '#eac17b', low: '#ef4444'};
const ALIAS = {teal: 'ok', amber: 'mid', red: 'low'};
export function fillColour(level) {
  const lv = ALIAS[level] || level;
  return lv === 'grey' ? 'var(--lcd-muted)' : STATUS_HEX[lv] ? `var(--st-${lv})` : null;
}
export const flameColour = level => STATUS_HEX[ALIAS[level] || level] || null;
// Round G: healthy stays white, tight and critical numbers share the bar's status.
export const numberColour = level => level === 'mid' || level === 'low' ? fillColour(level) : null;
