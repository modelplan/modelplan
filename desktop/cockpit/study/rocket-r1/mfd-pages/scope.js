import {scopeSelection} from './public-helpers.js';
// Scope helpers for the public-screen views (r7 P4). Pure: they read only (d = mfdData(), ui = mfdUi()).
export const accountsIn = (d, ui) => ui.scope ? d.accounts.filter(a => a.id === ui.scope) : d.accounts;
export const accountOf = (d, id) => d.accounts.find(a => a.id === id) || null;
export const poolsIn = (d, ui) => [...new Set(accountsIn(d, ui).map(a => a.pool).filter(Boolean))];
export const modelOf = (d, id) => d.models.find(m => m.id === id) || null;
export const rowOf = (m, label) => m?.e.find(e => e[0] === label) || null;
export const recRow = m => rowOf(m, m.rec) || m.e.at(-1);
const midnight = now => { const x = new Date(now); x.setHours(0, 0, 0, 0); return x.getTime(); };
// Sessions in scope: today (since local midnight) or the last 7 days.
export function sessionsIn(d, ui, period = 'today') {
  const ids = new Set(accountsIn(d, ui).map(a => a.id)), from = period === '7d' ? d.now - 7 * 864e5 : midnight(d.now);
  return d.sessionRanking.filter(x => ids.has(x.sub) && (x.running || x.endedAt >= from || x.startedAt >= from));
}
// The effort the latest session of a model in scope used (white = real, spec 2.1), or null.
export function currentOf(d, ui, modelId) {
  const list = sessionsIn(d, ui).filter(x => x.model === modelId).sort((a, b) => (b.running - a.running) || (b.endedAt ?? b.startedAt) - (a.endedAt ?? a.startedAt));
  return list[0] ? {effort: list[0].effort, fast: list[0].fast, tool: list[0].tool} : null;
}
// Same ordered ten-model scope as the HUD/field. Older-in-use is automatic;
// the old manual include-legacy option cannot add retired releases.
export function chartModels(d, ui) {
  if(d.selection&&d.selection.scope===(ui.scope||null))return d.selection.field;
  return scopeSelection({models:d.models,accounts:d.accounts,sessions:d.sessionRanking,
    now:d.now,scope:ui.scope||null,lineup:d.lineup}).field;
}
