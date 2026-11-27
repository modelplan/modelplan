// Faders (r7 P3, spec 5): the pure model and views. faderModel(d, ui) turns the adapter's data (fader-adapter.js) and
// the UI state into one model per channel; the view functions turn a channel into markup. No state, no fixtures and
// no DOM here: faders.js is the controller and the one DOM writer (spec 2.6). Every visible string goes through t().
// Colours carry one meaning each (spec 2.1): vendor colour = who (strip), white = real (current effort, real
// cap, a real fast session), blue = a trial, gold = ★. Round D1 (owner 2026-10-23): gold ★ is the one recommended
// marker (◉ is gone), and fast mode uses the single status indicator above the LCD. Synthetic study; nothing is applied to a session.
import {shortLabel} from './short-label.js';
import {t} from './i18n.js';
import {tokShort, approxCost} from './mfd-pages/fmt.js';
import './strings/faders.js';

export const LADDER = ['Low', 'Med', 'High', 'XHigh', 'Max'];
// D405 (owner 11-24): the lever tier is one tilted face seen in perspective, slightly narrower and more compressed at the far
// (top) end. TIER_Q is the face's width at the Max row relative to the Low row; everything on the face (slots, detent dashes,
// effort names, ★, levers) takes its position from this one geometry, so the slots converge together and the detent spacing
// shrinks evenly towards the top (by TIER_Q² there). No CSS 3D: positions only, text stays sharp.
export const TIER_Q = 0.955;
// The face's horizontal scale at screen fraction y of the travel (0 = Max row, 1 = Low row); linear in y, as on a tilted plane.
export const tierScale = y => TIER_Q + (1 - TIER_Q) * y;
// Screen fraction of an evenly spaced detent t (0 Max .. 1 Low) on that face: the vertical scale goes as tierScale², so
// t = ∫dy/s(y)² normalised, inverted here.
export function tierY(t) {
  const q = TIER_Q, a = 1 / q, inv = a - t * (a - 1);
  return Math.min(1, Math.max(0, (1 / inv - q) / (1 - q)));
}
// Where a level sits on the travel: 0 = Max at the top … 1 = Low at the bottom (faders.css places it), on the tilted face.
export const levelK = label => tierY((4 - LADDER.indexOf(label)) / 4);
// The code-drawn slot of channel `off` (channel offset from the lever-area centre in pitches: -1, 0, 1), as SVG in the
// channel's own pixels: a dark core --slot-w wide on the face, a 1 px shadow on its upper end and inner edge, a 1 px faint
// highlight on its lower lip. It runs 8 u past the Max and Low rows, so it is .367 of the column
// height long as on the direction 06 prototype (D419, measured: 161 px slot over a 439 px column) and follows the shared face geometry (it is not a bitmap).
export function slotSvg({width, height, pad, slotW, off, pitch}) {
  const u = (height - 2 * pad) / 97, rows = height - 2 * pad, y0 = pad - 8 * u, y1 = height - pad + 8 * u;
  const at = y => { const f = (y - pad) / rows, s = tierScale(f); return {x: width / 2 + off * pitch * (s - 1), w: slotW * s}; };
  const top = at(y0), bot = at(y1), r = n => +n.toFixed(2);
  const poly = (a, b, ya, yb) => `${r(a.x - a.w / 2)},${r(ya)} ${r(a.x + a.w / 2)},${r(ya)} ${r(b.x + b.w / 2)},${r(yb)} ${r(b.x - b.w / 2)},${r(yb)}`;
  const inner = off < 0 ? -1 : 1; // the inner edge faces the lever-area centre (right edge on the left slot); the centre slot shades its left edge
  const edge = (a, b) => { const sx = w => (inner < 0 ? w.x + w.w / 2 - 1 : w.x - w.w / 2); return `${r(sx(a))},${r(y0)} ${r(sx(a) + 1)},${r(y0)} ${r(sx(b) + 1)},${r(y1)} ${r(sx(b))},${r(y1)}`; };
  return `<svg class="fd-slotsvg" width="${width}" height="${r(height)}" viewBox="0 0 ${width} ${r(height)}" aria-hidden="true">`
    + `<polygon class="sl-core" points="${poly(top, bot, y0, y1)}"/>`
    + `<polygon class="sl-shade" points="${edge(top, bot)}"/>`
    + `<polygon class="sl-shade" points="${poly(top, top, y0, y0 + 1)}"/>`
    + `<polygon class="sl-lip" points="${poly(bot, bot, y1 - 1, y1)}"/></svg>`;
}
export const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]));
const dhm = m => m == null ? '--' : m < 60 ? `${Math.round(m)}m` : m < 1440 ? `${Math.floor(m / 60)}h${String(Math.round(m % 60)).padStart(2, '0')}` : `${Math.floor(m / 1440)}d${Math.floor(m % 1440 / 60)}h`;
// Multiples on a 56 px LCD: ×2.8, ×1.5, ×2, ×0.7, ×13 (one decimal below 10, whole numbers bare).
export function times(v) {
  if (v == null || !isFinite(v)) return '×--';
  return '×' + (v >= 9.95 ? v.toFixed(0) : v >= .095 ? v.toFixed(1) : v.toFixed(2)).replace(/\.0+$/, '');
}
// LCD cost ratios: at most two significant digits; missing costs stay missing.
const costFormat = new Intl.NumberFormat('en-US', {maximumSignificantDigits: 2, useGrouping: false});
export const costMultiple = v => typeof v === 'number' && Number.isFinite(v) && v >= 0 ? '×' + costFormat.format(v) : null;
const costRatio = (a, b) => a != null && b != null && b > 0 ? a / b : null;
// Ability against the current effort: +4.7, −2.9, ±0.
export const delta = v => v == null || !Number.isFinite(v) ? '--' : v > .05 ? '+' + v.toFixed(1) : v < -.05 ? '−' + Math.abs(v).toFixed(1) : '±0';
// A session's age for tooltips (the record strip uses it too): "running 12m" or −6m.
export const agoText = x => x.running ? t('fad.running', {t: dhm(x.startedMin)}) : `−${dhm(x.endedMin)}`;

// Glyphs drawn as SVG, so their width is the same on every platform and ⚡ never turns into a colour emoji.
const STAR = '<svg class="g-star" viewBox="0 0 10 10" aria-hidden="true"><path d="M5 .5L6.18 3.68 9.57 3.82 6.9 5.92 7.82 9.18 5 7.3 2.18 9.18 3.1 5.92 .43 3.82 3.82 3.68Z"/></svg>';

/* ---------- model ---------- */
// d = faderData(), ui = faderUi() + {bankSize}. Returns {bank, banks, size, channels (this bank, null = empty slot),
// all (every fader), target (the fader the level labels act on: the selected one on this bank, else the first)}.
export function faderModel(d, ui) {
  const size = ui.bankSize, banks = Math.max(1, Math.ceil(d.faders.length / size)), bank = Math.max(0, Math.min(banks - 1, ui.bank | 0));
  const colour = new Map(d.accounts.map(a => [a.id, a.colour]));
  const all = d.faders.map(f => channel(f, ui, colour));
  const shown = all.slice(bank * size, bank * size + size), channels = Array.from({length: size}, (_, i) => shown[i] || null);
  const target = shown.find(c => c.id === ui.selModel) || shown[0] || null;
  return {bank, banks, size, channels, all, target: target?.id ?? null};
}

function channel(f, ui, colour) {
  const row = l => f.e.find(r => r[0] === l) || null, levels = f.e.map(r => r[0]);
  const cur = f.current && row(f.current) ? f.current : null, base = cur || f.rec;
  const tier = f.tier, costOf = (l, fast) => { const n = row(l)?.[2], factor = fast && tier ? tier.cost : 1; return typeof n === 'number' && Number.isFinite(n) && n >= 0 && typeof factor === 'number' && Number.isFinite(factor) ? n * factor : null; }, speedOf = fast => fast && tier ? tier.speed : 1;
  // The trial: the effort being tried (S.previews, the ghost cap) and/or ⚡ being tried (the comparison view's args).
  // G3-87 (build 14c, owner): an open comparison alone is not a trial. Pressing the LCD only selects the model for the
  // comparison; a trial exists only while the ghost sits on another effort than the real cap (current, or ★ when
  // current is unreported) or ⚡ is being tried. Moving the fader back onto the real cap ends it (CKP-FAD-09, -17).
  const v = ui.view && ui.view.modelId === f.id ? ui.view : null, pv = ui.previews[f.id];
  const tEff = pv && row(pv) && pv !== base ? pv : null;
  const tFast = tier && v && v.fast != null && !!v.fast !== f.currentFast ? !!v.fast : null;
  let trial = null;
  const trialEff = v && row(v.trial) && v.trial !== base ? v.trial : tEff;
  if (trialEff || tFast != null) {
    const e = trialEff || base, fast = tFast ?? f.currentFast;
    trial = {effort: e, fast: tFast, matchesCurrent: e === cur && fast === f.currentFast, matchesRec: e === f.rec && !fast, cost: costRatio(costOf(e, fast), costOf(base, f.currentFast)), abl: row(e)[1] == null || row(base)[1] == null ? null : row(e)[1] - row(base)[1], speed: speedOf(fast) / speedOf(f.currentFast)};
  }
  const others = Object.entries(f.others).filter(([e]) => row(e)).sort((a, b) => b[1] - a[1] || LADDER.indexOf(b[0]) - LADDER.indexOf(a[0]));
  const from = v ? v.from : null; // the source of this model's comparison view, lit (spec 2.5)
  const name = f.name || f.short, segments = f.accounts.map(id => colour.get(id)).filter(Boolean);
  const ch = {id: f.id, unlisted: !!f.unlisted, name, label: cardLabel(name), levels, current: f.current, cur, rec: f.rec, base, live: f.live, pinned: f.pinned, used: f.sessions.length > 0,
    currentFast: f.currentFast, tier, follows: !!cur && cur === f.rec && !f.currentFast,
    recX: cur ? costRatio(costOf(cur, f.currentFast), costOf(f.rec, false)) : null, // the current cost against ★ (fast included); aria only
    others, segments,
    lamp: !tier ? null : tFast != null ? 'try' : f.currentFast ? 'on' : 'off',
    trial, tEff, tFast, src: from,
    capK: levelK(base), parked: !cur, recK: levelK(f.rec), ticks: levels.map(levelK),
    // CKP-FAD-53: a white dot beside the slot for another effort with a notable share of the last 15 minutes.
    dots: (f.notable || []).filter(e => row(e) && e !== cur).map(e => ({k: levelK(e), e})),
    ghostK: tEff ? levelK(tEff) : null,
    leds: f.sessions.slice(0, 6).map(x => ({...x, colour: colour.get(x.sub) || null})),
    fast: tier ? {state: from === 'fast' ? 'try' : f.currentFast ? 'on' : 'off', std: f.currentFast} : null,
    sel: ui.selModel === f.id};
  // CKP-FAD-55: one session lamp. Lit in the subscription colour = a session is running; dim = used in this range; off.
  // macrevb-1052-2: from every verified session (f.lamps), not the six the tooltip lists; the colour is a bound session's
  // subscription, never another subscription's (an unbound running session lights the lamp in the neutral ink).
  const lamps = f.lamps || f.sessions, running = lamps.find(x => x.active && x.sub) || lamps.find(x => x.active);
  ch.session = running ? 'live' : f.live || f.recorded || f.use || lamps.length ? 'used' : 'off';
  ch.lampColour = running && running.sub ? colour.get(running.sub) || null : null;
  ch.card = card(ch, f);
  return ch;
}

// CKP-FAD-52 / §14: every card line is at most 9 characters in every language.
export const CARD_LINE = 9;
const fits = s => [...s].length <= CARD_LINE;
const USE_FIT = 7;
// macrevb-1052-1: a visible line is never longer than the limit; the full text stays in the accessible name (stripAria).
const clip = s => fits(s) ? s : [...s].slice(0, CARD_LINE - 1).join('') + '…';
// The model name in at most 9 characters ("Sonnet 5.5" → "Sonnet5.5"); a name no alias shortens keeps its full text and
// is set tighter (class "long") rather than turned into a generic word.
function cardLabel(name) {
  const short = shortLabel(name, 'model', fits);
  return clip(short === 'Model' && name !== 'Model' ? shortLabel(name) : short);
}
// The effort line: "High ★Med"; current = ★ → "★Med"; "XHigh ★High" does not fit → the current effort alone.
export function effortLine(cur, rec) {
  if (!cur) return {cur: '', rec};
  if (cur === rec) return {cur: '', rec};
  return fits(`${cur} ★${rec}`) ? {cur, rec} : {cur, rec: ''};
}
// G3-145: the large slot is 52 px wide, so a small cost has a short form: "<$0.01" under a cent, two decimals under a dollar
// ("≈$0.004" and "≈$0.012" are seven characters and clipped). The accessible text keeps the full estimate (bigFull).
const cardCost = v => v < 0.01 ? '<$0.01' : v < 1 ? `≈$${v.toFixed(2)}` : approxCost(v);
const pctOf = share => Math.max(share > 0 ? 1 : 0, Math.round(share * 100));
/** The card's lines as plain text (V1-FINAL §7 table), the source for both the view and the 9-character check.
 * state: normal | unused | norecord | try. big: the large slot. bar: share 0..1 or null. use: [tokens, share %] or null.
 * eff: {cur, rec, note}: the small last line (note replaces it: 档位未报告 / 试算中). */
export function card(c, f = {}) {
  const use = f.use && f.use.tokens > 0 ? f.use : null;
  const lines = {name: c.label, state: 'normal', big: '', bigKind: '', bar: null, use: null, eff: null, tryLine: '', nowLine: ''};
  // G3-134: a model the publication does not list has no efforts, no ★ and no lever; the card says so.
  if (c.unlisted) { lines.state = 'unlisted'; lines.big = t('fad.cardUnlisted'); lines.bigKind = 'note'; return lines; }
  if (c.trial) {
    const tr = c.trial, fastOnly = tr.fast != null && tr.effort === c.base;
    lines.state = 'try';
    lines.tryLine = t('fad.cardTry', {e: fastOnly ? t(tr.fast ? 'fad.tryFast' : 'fad.tryStd') : tr.effort});
    // G3-182 (owner row 35, build 2): the trial line names the effort being tried; with no reported current tier a
    // "档位未报告" line under it read as a contradiction, so the second line is simply left out.
    lines.nowLine = c.cur ? t('fad.cardNow', {e: c.cur}) : '';
    // D444: the short cockpit's share line (D337, "A92 C55") is retired with the short layout; the full figures stay
    // in the strip's accessible label.
    lines.eff = {cur: '', rec: '', note: t('fad.cardTrying')};
    return lines;
  }
  if (use) {
    const priced = typeof use.cost === 'number' && Number.isFinite(use.cost) && use.cost > 0;
    lines.bigFull = priced ? approxCost(use.cost) : tokShort(use.tokens); lines.big = clip(priced ? cardCost(use.cost) : lines.bigFull); lines.bigKind = priced ? 'cost' : 'tokens';
    // "1000B 100%" is 10 characters: the share (also drawn by the bar) drops off before the tokens are cut.
    const tok = tokShort(use.tokens), pct = pctOf(use.share) + '%';
    // D405: the token count is set larger than the share, so the share stays on the line only while both fit the 52 px slot
    // (seven characters together); otherwise the bar alone shows it, and the accessible name keeps it.
    lines.bar = Math.max(0, Math.min(1, use.share)); lines.useFull = [tok, pct]; lines.use = [...tok].length + [...pct].length <= USE_FIT ? [tok, pct] : [clip(tok)];
  } else if (f.live || f.recorded) {
    lines.state = 'norecord'; lines.big = t('fad.cardNoRecord'); lines.bigKind = 'note';
  } else {
    lines.state = 'unused'; lines.big = t('fad.cardUnused'); lines.bigKind = 'note';
    lines.eff = {cur: '', rec: c.rec, note: ''};
    return lines;
  }
  lines.eff = !c.cur && f.live ? {cur: '', rec: '', note: t('fad.cardUnreported')} : {...effortLine(c.cur, c.rec), note: ''};
  return lines;
}
/** Every visible text line of a card, for the 9-character rule (★ counts as one character). */
export function cardText(k) {
  const eff = !k.eff ? '' : k.eff.note || [k.eff.cur, k.eff.rec ? '★' + k.eff.rec : ''].filter(Boolean).join(' ');
  return [k.name, k.big, k.use ? k.use.join(' ') : '', k.tryLine, k.nowLine, eff].filter(Boolean);
}

/* ---------- views ---------- */
// V1-FINAL §7 / CKP-FAD-50…52 (WP-08): the card is about use. Subscription-colour top edge, model name, ≈cost large
// (tokens when there is no public price), a share bar in the subscription colour, "212M 17%", and a small effort line
// "High ★Med". A trial swaps the middle for blue "试 XHigh / 当前 High". The five ability bars are gone (CKP-FAD-04).
const STAR_TEXT = rec => `<span class="cd-rec">${STAR}${esc(rec)}</span>`;
export function lcdView(c) {
  if (!c) return '';
  const k = c.card;
  // G3-181 (owner row 33, build 2): an unused card's top edge stays dark; the subscription-colour strip marks cards
  // with use in the range (or live ones), not a model the range shows as unused.
  const strip = k.state === 'unused' ? '' : `<i class="st-vend" aria-hidden="true">${c.segments.map(v => `<b style="--v:${esc(v)}"></b>`).join('')}</i>`;
  // A 9-character name ("Terra 6.1") is set 1 px smaller and tighter so it never clips on the 52 px card.
  const name = `<b class="st-name ${[...c.label].length > 8 ? 'long' : ''}">${esc(c.label)}</b>${c.pinned ? `<i class="st-pin" role="img" aria-label="${esc(t('fad.pinnedAria'))}"></i>` : ''}`;
  const eff = !k.eff ? '' : k.eff.note ? `<span class="cd-eff cd-note">${esc(k.eff.note)}</span>`
    : `<span class="cd-eff${k.eff.cur ? '' : ' cd-follows'}">${k.eff.cur ? `<span class="cd-cur">${esc(k.eff.cur)}</span>` : ''}${k.eff.rec ? STAR_TEXT(k.eff.rec) : ''}</span>`;
  if (k.state === 'try') return strip + name + `<span class="cd-try">${esc(k.tryLine)}</span>` + (k.nowLine ? `<span class="cd-now">${esc(k.nowLine)}</span>` : '') + eff;
  const bar = k.bar == null ? '' : `<i class="cd-bar" aria-hidden="true" style="--s:${(k.bar * 100).toFixed(1)}%;--v:${esc(c.segments[0] || '')}"></i>`;
  const use = k.use ? `<span class="cd-use"><b class="cd-tok">${esc(k.use[0])}</b>${k.use[1] ? ` <span class="cd-pct">${esc(k.use[1])}</span>` : ''}</span>` : '';
  return strip + name + `<span class="cd-big ${k.bigKind}">${esc(k.big)}</span>` + bar + use + eff;
}

export function stripAria(c) {
  if (c.unlisted) return `${c.name}: ${t('fad.cardUnlisted')}`;
  const current = t('fad.stripAria', {m: c.name, cur: c.cur || t('fad.unreportedAria'), rec: c.rec, x: c.recX != null ? t('fad.stripAriaX', {x: times(c.recX)}) : '',
    more: c.others.length ? t('fad.stripAriaMore', {more: c.others.map(([e, n]) => `${e}×${n}`).join(' ')}) : '',
    use: c.card && c.card.use ? t('fad.stripAriaUse', {u: [c.card.bigKind === 'cost' ? c.card.bigFull : '', c.card.useFull.join(' ')].filter(Boolean).join(' · ')}) : ''});
  if (!c.trial) return current;
  const tr = c.trial, fastOnly = tr.fast != null && tr.effort === c.base;
  return current + ' · ' + t('fad.stripTrialAria', {m: c.name, e: fastOnly ? t(tr.fast ? 'fad.tryFast' : 'fad.tryStd') : tr.effort + (tr.fast ? ' ⚡' : ''),
    cost: t('fad.cost', {x: times(tr.cost)}), d: fastOnly ? t('fad.speed', {x: times(tr.speed)}) : t('fad.abl', {d: delta(tr.abl)})});
}
// CKP-FAD-55 (WP-08): one session lamp per card, under the row label 会话 / Sessions: lit in the subscription colour while
// a session runs, dim when the model was used in this range, off otherwise. The ⚡ beside it is fast mode (CKP-FAD-24).
// Selection and trial are shown on the card (frame, blue lines), not on the lamp.
export function indicatorView(c) {
  if (!c) return '';
  const trying = !!c.trial, fast = !!c.tier && !!(c.tFast ?? c.currentFast);
  const tone = c.session || 'off';
  const label = t('fad.indicatorAria', {m: c.name, s: t(tone === 'live' ? 'fad.sessionLive' : tone === 'used' ? 'fad.sessionUsed' : 'fad.sessionNone'),
    fast: c.tier ? t('fad.fastLampAria', {s: trying ? t(fast ? 'fad.tryFast' : 'fad.tryStd') : t(fast ? 'fad.lampOn' : 'fad.lampOff')}) : ''});
  const sessions = c.leds.map(x => `${x.account ? x.account + ' · ' : ''}${x.tool} · ${x.project} · ${agoText(x)}`).join('\n');
  // CKP-FAD-24 / owner 11-12: fast mode is a ⚡ beside the lamp, symbol only: white = the real configuration is fast, solid blue =
  // a trial turns it on, blue outline = a trial turns it off. The lamp itself stays a dot. Nothing for a tool without a fast mode.
  const state = !c.tier ? '' : c.tFast === true ? 'try' : c.tFast === false ? 'off' : c.currentFast ? 'on' : '';
  const bolt = state ? `<svg class="fd-fast ${state}" data-fast-state="${state}" viewBox="0 0 6 9" role="img" aria-label="${esc(t(state === 'on' ? 'fad.lampOn' : state === 'try' ? 'fad.tryFast' : 'fad.tryStd'))}"><path d="M3.9 0 .3 5.1h2.4L2 9l3.7-5.4H3.3z"/></svg>` : '';
  return `<span class="fd-indicator ${tone}" data-state="${tone}" data-fast="${fast}"${c.lamp ? ` data-fast-mode="${c.lamp}"` : ''} role="img" aria-label="${esc(label + (sessions ? '\n' + sessions : ''))}"></span>${bolt}`;
}
// The travel's fixed marks: a tick per level the model has, the ★ detent (round D1: this fader's own ★ level, a short
// gold notch beside the cap's lane and a tiny gold ★, because the shared scale cannot show each model's ★), and white
// dots for another effort with a notable share of the last 15 minutes (CKP-FAD-53).
export const marksView = c => !c ? '' : `${c.ticks.map(k => `<i class="fd-tick" style="--k:${k}"></i>`).join('')}${c.unlisted ? '' : `<i class="fd-rec" data-l="${esc(c.rec)}" style="--k:${c.recK}">${STAR}</i>`}${c.dots.map(d => `<i class="fd-dot" data-l="${esc(d.e)}" style="--k:${d.k}"></i>`).join('')}`;
// Round D1: the ⚡ lit push button above the travel is gone (the owner could not tell what it was); fast mode is tried
// with the comparison view's own ⚡ key; its state shares the indicator above the LCD.
// D405 (owner 2026-11-24): the effort names are printed in the two gaps between the three levers, shown twice, like the
// detent labels on a thrust-lever quadrant; 会话 / Sessions heads the lamp row. Both columns set the same trial.
const scaleColumn = gap => `<span class="sc-travel" data-gap="${gap}">${LADDER.map(l => `<button class="silk sc-l" data-level="${l}" tabindex="-1" style="--k:${levelK(l)}">${l}</button>`).join('')}</span>`;
export const scaleView = () => `<span class="silk sc-led">${t('fad.status')}</span>${scaleColumn(1)}${scaleColumn(2)}`;
export const bankView = M => M.banks > 1 ? `<button class="key sm" data-bank="-1" data-mat="part" aria-label="${esc(t('fad.bankPrevAria'))}">◀</button><span class="bank-lcd" data-mat="well">${esc(t('fad.bank', {i: M.bank + 1, n: M.banks}))}</span><button class="key sm" data-bank="1" data-mat="part" aria-label="${esc(t('fad.bankNextAria'))}">▶</button>` : '';
