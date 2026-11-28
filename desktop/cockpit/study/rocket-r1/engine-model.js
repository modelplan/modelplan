// Engine table model (r7 P2, spec 4). Pure (spec 2.6): engineModel(data, ui) → everything the table shows. It reads
// only its arguments: data = engineData() and ui = engineUi() from engine-adapter.js, shaped like the CLI snapshot
// (accounts[] with windows/cards/credits, the red/amber alerts behind the master caution, now). No state, no
// fixtures, no DOM and no strings; engine-view.js turns the model into markup. Synthetic study.

import {timeLeft, litTimeDots} from './window-time.js';
import {reserveSoon} from './reserve-expiry.js';

export const PER = 6; // columns per page (spec 4); base.js pages its lights with the same number (through engine.js)
export const KINDS = ['5h', 'day', 'week', 'month']; // window kinds by length
const CYCLE_MIN = {'5h': 300, day: 1440, week: 7 * 1440, month: 30 * 1440};
const RANK = {amber: 1, red: 2};
const GREY = new Set(['stale', 'error', 'error-lastgood']); // readings without a current status colour
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

/* ---------- rules ---------- */
// D474 §6.1, one threshold: a column at least 140 pt wide is `wide`, anything narrower `narrow` (no medium). The host
// passes the measured column width, (band width − label column) / slots; without a measure (not laid out yet, tests)
// the band's own geometry decides (588 pt less the label column over the slots): up to 3 columns are wide.
export const WIDE_MIN = 140;
export const widthClass = (n, colWidth = null) => Number.isFinite(colWidth) && colWidth > 0 ? (colWidth >= WIDE_MIN ? 'wide' : 'narrow') : n <= 3 ? 'wide' : 'narrow';
// D474 decision 2 (C9): red (`low`) = at or under "turn red below" (settings, default 25), used up, or drawing points;
// amber (`mid`) = the estimate runs out before the reset (it will be lost); otherwise `ok`. There is no 50 % rule.
export const levelOf = (r, redAt = 25, {runOutBefore = false, drawing = false} = {}) => r == null ? 'none' : r <= redAt || r <= 0 || drawing ? 'low' : runOutBefore ? 'mid' : 'ok';
// Lit segments of the 10-segment bar: tens, rounded, but a window with anything left keeps one segment lit, so only a
// used-up window shows an empty bar.
// In used mode (Settings "used", D130) the bar fills with what is used, 100 - r, by the same rule; colours stay keyed to r.
export const litSegments = (r, used = false) => { const v = r == null ? null : used ? 100 - r : r; return v == null || v <= 0 ? 0 : clamp(Math.round(v / 10), 1, 10); };
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
// D474 §3.4 lapse rule: a kept good reading (失败·2h) lapses when its window's reset time passes (its % is plainly
// wrong then); a window with no reset time lapses 24 h after the reading. The cell turns into `--` + 读不到.
export const lapsed = (a, w) => a.state === 'error-lastgood' && (w.resetPassed === true || (w.resetIn == null && !w.resetPassed && (a.ageMin ?? 0) > 1440));
function cellOf(a, w, ui, runOutW, grey, runOut = null) {
  const gone = lapsed(a, w);
  const r = a.state === 'loading' || a.state === 'error' || gone ? null : w.remaining ?? null;
  const runOutMin = runOut !== null ? runOut : a.forecast && w.trend != null && w.trend < 0 && w.runOutMin != null && r != null && !grey && a.state !== 'stale' ? w.runOutMin : null;
  const runOutBefore = runOutMin != null && r != null && r > 0 && (w.resetIn == null || runOutMin < w.resetIn);
  const drawing = r === 0 && !grey && !!a.credits?.drawing, level = levelOf(r, ui.redAt, {runOutBefore, drawing});
  return {focusIdentity: w.focusIdentity ?? null, kind: w.kind, period: PERIODS[w.kind] || w.kind, remaining: r, value: r == null ? null : ui.pctMode === 'used' ? 100 - r : r, level, lit: litSegments(r, ui.pctMode === 'used'),
    drawing, noData: r == null && a.state === 'ok', lapsed: gone,
    runOutMin: runOutBefore ? runOutMin : null,
    // D474 §3.2: line 2 says 够用到重置 when the window's estimate does not run out before its reset.
    lasts: !runOutBefore && !grey && a.state === 'ok' && r != null && r > 0 && w.resetIn != null && w.lasts === true,
    timeLeft: grey || a.state === 'loading' || a.state === 'error' ? null : timeLeft(w),
    timeLit: grey || a.state === 'loading' || a.state === 'error' ? null : litTimeDots(timeLeft(w)),
    resetIn: w.resetIn ?? null, resetAt: w.resetAt ?? null, resetText: w.resetText ?? null};
}
// An extra quota (专项) as a cell: its own period and run-out time, and its name for the tag (Fable·周). `short` is the
// narrow tag used next to +1: a name of up to three characters as it is, else its initial (which then takes the period).
function extraCell(a, w, ui, grey) {
  const period = PERIODS[w.period || w.kind] || w.kind;
  const own = w.trend != null && w.trend < 0 && w.runOutMin != null && w.remaining != null && !grey && a.state !== 'stale' && a.state !== 'error' && !lapsed(a, w) ? w.runOutMin : null;
  const c = cellOf(a, {...w, kind: period}, ui, null, grey, own);
  const name = w.name || w.scope?.label || '';
  // D417: only a window the engine names (a model scope or MCP) is shown in full, up to 6 characters; an unnamed
  // window's generic label ("Other limit", 其他限额) keeps the compact first-character fallback.
  const full = w.named ? [...name].length <= 6 : [...name].length <= 3;
  return {...c, extra: true, named: !!w.named, period, name, label: w.label || name, tag: full ? name : [...name][0], tagPeriod: !full};
}
// Owner C01, 2026-10-25: headings remain 5小时 / 每周 / 其他. Only matching general windows enter the first two
// rows; every other general window and scoped quota enters Other, tightest first with +N/full details.
// A missing 5h or weekly window is a genuinely blank cell, distinct from an existing window with an unknown reading.
export const ROWS = ['first', 'second', 'other'];
const byLength = list => list.map((w, i) => [w, i]).sort((x, y) => (CYCLE_MIN[PERIODS[x[0].kind]] ?? 1e9) - (CYCLE_MIN[PERIODS[y[0].kind]] ?? 1e9) || x[1] - y[1]).map(x => x[0]);
export function positional(a, ui, grey) {
  const runOutW = runOutWindow(a), general = byLength(a.windows || []);
  const first = general.find(w => PERIODS[w.kind] === '5h'), second = general.find(w => PERIODS[w.kind] === 'week');
  // D466: a quota cell shows only its own facts (reading, reset time, forecast); a public reset announcement is never
  // attached to a cell. Announcements are news on the key dot, the reserve "+1", the strip and the calendar.
  const cell = w => w ? cellOf(a, w, ui, runOutW, grey) : null;
  const rest = [...general.filter(w => w !== first && w !== second).map(cell), ...(a.extras || []).map(w => extraCell(a, w, ui, grey))];
  const rank = c => c.remaining == null ? 1e9 : c.remaining, main = rest.reduce((m, c) => m && rank(m) <= rank(c) ? m : c, null);
  return {first: cell(first), second: cell(second),
    other: main ? {...main, more: rest.length - 1, all: rest} : null};
}
function reserveOf(a, now) {
  const cards = a.cards || [], cr = a.credits;
  if (!cards.length && !cr && !(a.plus > 0)) return null;
  const expiries = cards.map(c => c.expiresAt).filter(v => Number.isFinite(v));
  const first = expiries.length ? Math.min(...expiries) : null;
  const count = cards.some(c => c.count === null) ? null : cards.reduce((n,c) => n + (c.count ?? 1), 0);
  // CKP-ENG-52: a zero carries no information and is not shown; nothing left at all means no reserve.
  const credits = cr && cr.balance !== 0 ? cr.balance ?? null : null, money = cr?.money ?? null;
  if (!(cards.length && count !== 0) && credits == null && money == null) return a.plus > 0 ? {cards: null, warn: false, firstExpiry: null, credits: null, money: null, drawing: false, plus: a.plus, plusMarks: a.plusMarks || ''} : null;
  // D474 §5.1 / C7: the reserve is one quiet line; an item expiring within 48 h (the shared reserveSoon helper, the same
  // rule as the widget and the menu) adds the amber clause. `expiring` counts those items ("1 次 40h 后到期"). `plus` is
  // the "+1" of a banked reset confirmed during its news clock (the only place a banked reset shows outside the calendar).
  const soon = cards.filter(c => reserveSoon(c.expiresAt, now));
  return {cards: cards.length && count !== 0 ? count : null, warn: soon.length > 0, firstExpiry: first, expiring: soon.reduce((n, c) => n + (c.count ?? 1), 0),
    credits, money, drawing: !!cr?.drawing, plus: a.plus > 0 ? a.plus : 0, plusMarks: a.plusMarks || ''};
}
// CKP-ENG-50/54: a stale reading is drawn like a current one; only failed readings are grey. Neither washes its column.
function columnOf(a, i, ui, status, now) {
  const quiet = GREY.has(a.state), grey = quiet && a.state !== 'stale', st = quiet ? null : status.get(a.id) || null;
  // D466: `news` is the key's one blue dot (hollow = announced, solid = confirmed) while a reset announcement is news.
  return {id: a.id, name: a.name, short: a.short, alias:a.alias, colour: a.colour, logo: a.logo, key: i + 1, news: a.news || null, newsMarks: a.newsMarks || '',
    on: ui.scope === a.id, off: !!ui.scope && ui.scope !== a.id,
    state: a.state, grey, ageMin: a.ageMin ?? null, status: st, tint: ui.tint && st ? st : null,
    quotaOnly: a.support === 'quota-only' && (a.state === 'ok' || a.state === 'stale'), noUsage: !!a.noUsage && a.support === 'quota-only' && (a.state === 'ok' || a.state === 'stale'), today: a.todayTokens ?? null,
    cost: a.state === 'ok' || a.state === 'stale' ? a.rangeCost ?? null : null,
    // Never substitute the current/recent-seven-day rate for today's subscription average.
    speed: a.state === 'ok' && a.support !== 'quota-only' ? a.todayAverageGenerationTps ?? null : null,
    usage7: a.state === 'ok' ? a.usage7 ?? null : null,
    cells: positional(a, ui, grey), reserve: reserveOf(a, now)};
}

/* ---------- the table ---------- */
// {empty, pages, page, cls, rows, reserve, cols, leds, caution, used, scoped}. Rows: fixed 5h, Weekly, Other,
// then the combined today row, then reserve when a column on the page has banked resets
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
  return {empty: !list.length, pages, page, slots, rich, cls: widthClass(slots, ui.colWidth), rows, reserve: cols.some(x => x.reserve),
    rowPeriods: {first:'5h', second:'week', other:null}, cols, leds, caution: {level: c.level || null, flash: !!c.level && ui.ack !== c.key}, used: ui.pctMode === 'used', scoped: !!ui.scope, range: ui.range || 'today'};
}
