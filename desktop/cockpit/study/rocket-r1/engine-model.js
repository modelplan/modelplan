// Engine table model (r7 P2, spec 4). Pure (spec 2.6): engineModel(data, ui) → everything the table shows. It reads
// only its arguments: data = engineData() and ui = engineUi() from engine-adapter.js, shaped like the CLI snapshot
// (accounts[] with windows/cards/credits, the red/amber alerts behind the master caution, now). No state, no
// fixtures, no DOM and no strings; engine-view.js turns the model into markup. Synthetic study.

import {timeLeft, litTimeDots} from './window-time.js';

export const PER = 6; // columns per page (spec 4); base.js pages its lights with the same number (through engine.js)
export const KINDS = ['5h', 'day', 'week', 'month']; // window kinds by length
const CYCLE_MIN = {'5h': 300, day: 1440, week: 7 * 1440, month: 30 * 1440};
const H = 3600e3;
const RANK = {amber: 1, red: 2};
const GREY = new Set(['stale', 'error', 'error-lastgood']); // readings without a current status colour
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

/* ---------- rules ---------- */
// Width classes (spec 4), by the columns on the page: wide for 1–2 (cells ≥ 240 px: the bar with the number and one
// compact line beside it; round D2 removed the road bar), medium for 3–4, narrow for 5–6 (one line over a full-width bar).
export const widthClass = n => n <= 2 ? 'wide' : n <= 4 ? 'medium' : 'narrow';
// Quota status (spec 2.1): ok ≥ 41 %, mid above threshold to 40 %, low at/below "turn red below" (settings, default 16); used up is low.
export const levelOf = (r, redAt = 25) => r == null ? 'none' : r <= redAt ? 'low' : r <= 50 ? 'mid' : 'ok';
// Lit segments of the 10-segment bar: tens, rounded, but a window with anything left keeps one segment lit, so only a
// used-up window shows an empty bar.
export const litSegments = r => r == null || r <= 0 ? 0 : clamp(Math.round(r / 10), 1, 10);
export const pageCount = n => Math.max(1, Math.ceil(n / PER));
// An extra quota's period as the study's window kinds name it (the snapshot says weekly / monthly).
const PERIODS = {'5h': '5h', day: 'day', daily: 'day', week: 'week', weekly: 'week', month: 'month', monthly: 'month'};
const worse = (a, b) => (RANK[b] || 0) > (RANK[a] || 0) ? b : a;
// Each subscription's status from the alerts that light the master caution (red / amber; blue lines never count). The
// column tint, the page LEDs and the caution lamp all come from this one state.
export function statusBySub(alerts) {
  const out = new Map();
  for (const a of alerts || []) if (RANK[a.level]) out.set(a.sub, worse(out.get(a.sub) || null, a.level));
  return out;
}
// The window whose text becomes the forecast: the first one the pace says runs out before its reset, and only when
// the source gives a run-out time (the same rule as P1's hover card and P4's 订阅 page).
export const runOutWindow = a => a.forecast ? a.windows.find(w => w.trend != null && w.trend < 0) || null : null;

/* ---------- one column ---------- */
// round D2 states beyond the level: `drawing` (used up while credits are being drawn), `noData` (a good reading
// without a value for this window); the column's state (stale, error, loading) and `event` (a public reset) are
// added by the view and positional().
function cellOf(a, w, ui, runOutW, grey) {
  const r = a.state === 'loading' || a.state === 'error' ? null : w.remaining ?? null, level = levelOf(r, ui.redAt);
  return {focusIdentity: w.focusIdentity ?? null, kind: w.kind, period: PERIODS[w.kind] || w.kind, remaining: r, value: r == null ? null : ui.pctMode === 'used' ? 100 - r : r, level, lit: litSegments(r),
    drawing: r === 0 && !grey && !!a.credits?.drawing, noData: r == null && a.state === 'ok',
    runOutMin: w === runOutW && r != null && !grey ? a.forecast.runOutMin : null,
    timeLeft: grey || a.state === 'loading' || a.state === 'error' ? null : timeLeft(w),
    timeLit: grey || a.state === 'loading' || a.state === 'error' ? null : litTimeDots(timeLeft(w)),
    resetIn: w.resetIn ?? null, resetAt: w.resetAt ?? null, resetText: w.resetText ?? null};
}
// An extra quota (专项) as a cell: its own period and run-out time, and its name for the tag (Fable·周). `short` is the
// narrow tag used next to +1: a name of up to three characters as it is, else its initial (which then takes the period).
function extraCell(a, w, ui, grey) {
  const period = PERIODS[w.period || w.kind] || w.kind, c = cellOf(a, {...w, kind: period}, ui, null, grey);
  c.runOutMin = w.trend != null && w.trend < 0 && w.runOutMin != null && c.remaining != null && !grey ? w.runOutMin : null;
  const name = w.name || w.scope?.label || '';
  return {...c, extra: true, period, name, label: w.label || name, tag: name.length <= 3 ? name : [...name][0], tagPeriod: name.length > 3};
}
// Owner C01, 2026-10-25: headings remain 5小时 / 每周 / 其他. Only matching general windows enter the first two
// rows; every other general window and scoped quota enters Other, tightest first with +N/full details.
// A missing 5h or weekly window is a genuinely blank cell, distinct from an existing window with an unknown reading.
export const ROWS = ['first', 'second', 'other'];
const byLength = list => list.map((w, i) => [w, i]).sort((x, y) => (CYCLE_MIN[PERIODS[x[0].kind]] ?? 1e9) - (CYCLE_MIN[PERIODS[y[0].kind]] ?? 1e9) || x[1] - y[1]).map(x => x[0]);
export function positional(a, ui, grey) {
  const runOutW = runOutWindow(a), general = byLength(a.windows || []);
  const first = general.find(w => PERIODS[w.kind] === '5h'), second = general.find(w => PERIODS[w.kind] === 'week');
  const evW = a.event && !grey ? first || general[0] : null;
  const cell = w => w ? {...cellOf(a, w, ui, runOutW, grey), event: w === evW ? a.event : null} : null;
  const rest = [...general.filter(w => w !== first && w !== second).map(cell), ...(a.extras || []).map(w => extraCell(a, w, ui, grey))];
  const rank = c => c.remaining == null ? 1e9 : c.remaining, main = rest.reduce((m, c) => m && rank(m) <= rank(c) ? m : c, null);
  // A public reset stays attached to its window even when that window moves into Other.
  return {first: cell(first), second: cell(second),
    other: main ? {...main, more: rest.length - 1, all: rest} : null};
}
function reserveOf(a, now) {
  const cards = a.cards || [], cr = a.credits;
  if (!cards.length && !cr) return null;
  const expiries = cards.map(c => c.expiresAt).filter(v => Number.isFinite(v));
  const first = expiries.length ? Math.min(...expiries) : null;
  const count = cards.some(c => c.count === null) ? null : cards.reduce((n,c) => n + (c.count ?? 1), 0);
  return {cards: cards.length ? count : null, warn: expiries.some(v => (v - now) / H <= 48), firstExpiry: first,
    credits: cr ? cr.balance : null, drawing: !!cr?.drawing};
}
function columnOf(a, i, ui, status, now) {
  const grey = GREY.has(a.state), st = grey ? null : status.get(a.id) || null;
  return {id: a.id, name: a.name, short: a.short, alias:a.alias, colour: a.colour, logo: a.logo, key: i + 1,
    on: ui.scope === a.id, off: !!ui.scope && ui.scope !== a.id,
    state: a.state, grey, ageMin: a.ageMin ?? null, status: st, tint: ui.tint && st ? st : null,
    quotaOnly: a.support === 'quota-only', today: a.todayTokens ?? null,
    // Never substitute the current/recent-seven-day rate for today's subscription average.
    speed: a.state === 'ok' && a.support !== 'quota-only' ? a.todayAverageGenerationTps ?? null : null,
    usage7: a.state === 'ok' ? a.usage7 ?? null : null,
    cells: positional(a, ui, grey), reserve: reserveOf(a, now)};
}

/* ---------- the table ---------- */
// {empty, pages, page, cls, rows, reserve, cols, leds, caution, used, scoped}. Rows: fixed 5h, Weekly, Other,
// then the combined today row, then reserve when a column on the page has reset cards
// or credits (spec 4). Columns keep the user's order (never by activity); 6 to a page.
export function engineModel(d, ui) {
  const list = d.accounts || [], pages = pageCount(list.length), page = clamp(ui.page | 0, 0, pages - 1);
  const shown = list.slice(page * PER, page * PER + PER), status = statusBySub(d.alerts);
  const cols = shown.map((a, i) => columnOf(a, i, ui, status, d.now));
  // Task 35 prototype: compare six fixed bays with richer columns only for 1–3 total subscriptions.
  const rich = ui.few === 'b' && list.length > 0 && list.length <= 3;
  const slots = rich ? cols.length : ['c', 'c3', 'c4'].includes(ui.few) && list.length <= PER ? Math.max(list.length, ui.few === 'c3' ? 3 : 4) : PER;
  const rows = cols.length ? [...ROWS] : [];
  // A page LED lights in the colour of the worst subscription on its page; the current page's LED is the long one.
  const leds = Array.from({length: pages}, (_, p) => ({page: p, current: p === page, accounts:list.slice(p*PER,p*PER+PER).map(a=>({name:a.name,status:GREY.has(a.state)?null:status.get(a.id)||null})),
    level: list.slice(p * PER, p * PER + PER).reduce((l, a) => GREY.has(a.state) ? l : worse(l, status.get(a.id) || null), null)}));
  const c = d.caution || {level: null, key: ''};
  return {empty: !list.length, pages, page, slots, rich, cls: widthClass(slots), rows, reserve: cols.some(x => x.reserve),
    rowPeriods: {first:'5h', second:'week', other:null}, cols, leds, caution: {level: c.level || null, flash: !!c.level && ui.ack !== c.key}, used: ui.pctMode === 'used', scoped: !!ui.scope};
}
