// SPDX-License-Identifier: MIT
// Ported from the opus-r7 study (rocket-r1/mfd-pages/views.js, round D1): the comparison view a fader trial opens
// (spec 6.4). Only the comparison is ported; the alert list and the session view live in prototype-deck.ts.
// Pure view (v8, CKP-MFD-33): ability and cost bars as shares of the top effort, the share line chart and the effort
// ladder; its own bottom keys (‹ back, ⚡ fast). Nothing is applied to a session.
import {websiteWords,modelUrl,methodologyUrl,secondaryLink} from './public-helpers.js';
import {t} from '../i18n.js';
import '../strings/review49.js';
import {esc, fill, bolt} from './fmt.js';
import {modelOf, rowOf, currentOf} from './scope.js';

const POOL_TOOL = {codex: 'Codex', claude: 'Claude Code'};

/* ---------- comparison view (spec 6.4; round D1, owner 2026-10-23) ---------- */
// args {modelId, current, trial, fast, currentFast}. White = current, blue = trial, gold ★ = recommended. An
// unreported current is never stood in for by ★ (CKP-MFD-19): no white tick, number or column, and the note says
// "current unknown"; the chart is still drawn (build 14c). Effort keys and chart columns set the trial.
// The bottom key row is the view's own (compareKeys): ‹ 返回 <page>, ⚡ 快速 关 | 开.

// One reading of the comparison for the card, its keys and its clicks, so the three always agree.
export function cmpState(d, ui, args) {
  const m = modelOf(d, args.modelId);
  if (!m) return null;
  const now = currentOf(d, {...ui, scope: null}, m.id), tool = now?.tool || POOL_TOOL[m.pool];
  const reported = args.current !== undefined ? args.current : now?.effort ?? null;
  const cur = rowOf(m, reported) ? reported : null, base = cur || m.rec;
  const tier = d.speedTiers[`${tool}|${m.id}`] || d.speedTiers[`${tool}|${m.pool}`] || null, curFast = !!tier && !!(args.currentFast ?? now?.fast ?? false);
  const trialFast = !!tier && !!(args.fast ?? curFast), trial = args.trial && rowOf(m, args.trial) ? args.trial : base;
  // G3-87: a trial only when the tried configuration differs from the real one (current, or ★ when unreported).
  const trying = trial !== base || trialFast !== curFast;
  return {m, cur, base, tier, curFast, trialFast, trial, trying};
}
const numeric = v => typeof v === 'number' && Number.isFinite(v);
const ratio = (value, reference) => numeric(value) && numeric(reference) && reference > 0 ? value / reference : null;
const colOf = (m, tier, label, fast) => { const r = rowOf(m, label), f = !!(fast && tier); return {label, r, fast: f, cost: numeric(r[2]) && (!f || numeric(tier.cost)) ? r[2] * (f ? tier.cost : 1) : null,
  time: r[3] == null || (f && tier.taskTimeUnknown) ? null : r[3] / (f ? tier.speed : 1)}; };

// v8 (CKP-MFD-33; D165, D177, D190, D201, demo v8): every number is a share of the model's own top effort, the
// published effort with the highest ability (= 100 %, "Max"). Cost and time are shares of that effort's cost and
// time; a fast configuration multiplies its own cost and time, so a fast trial may go past 100 %.
const topRow = m => m.e.filter(r => numeric(r[1])).reduce((a, b) => !a || b[1] > a[1] ? b : a, null);
export function shareOfTop(m, c) {
  const top = topRow(m);
  return top ? {abl: ratio(c.r[1], top[1]), cost: ratio(c.cost, top[2]), time: ratio(c.time, top[3])} : {abl: null, cost: null, time: null};
}
// One configuration (effort + fast mode) as shares of the top effort: the helper the bars, the chart and a later
// fast-mode view read. Fast multiplies cost by the tier's cost ratio and divides time by its speed (unknown when the
// tier does not state it).
export const configShare = (m, tier, label, fast = false) => rowOf(m, label) ? shareOfTop(m, colOf(m, tier, label, fast)) : null;
const n1 = v => (+v).toFixed(1);
const pctText = v => v == null ? '--' : Math.round(v * 100) + '%';
// The bars and the chart share one left edge (after the bar labels) and one right edge; the effort keys sit under the
// chart's columns.
const edges = (ui, W) => ({L: /^en/.test(ui.lang || '') ? 50 : 36, E: W - 8});
const box = (x, y, w, h, cls, extra = '') => `<rect class="${cls}" x="${n1(x)}" y="${n1(y)}" width="${n1(Math.max(0, w))}" height="${h}"${extra}/>`;
const label = (x, y, s, cls, anchor = 'start') => `<text class="${cls}" x="${n1(x)}" y="${n1(y)}" text-anchor="${anchor}">${esc(s)}</text>`;
// A number with a small %; x is its centre. Never next to a ★: the ★ sits above the bar, numbers below it.
const pctNum = (x, y, v, role) => { const n = String(Math.round(v * 100)), w = n.length * 6 + 4.5;
  return `<text class="pc-num pc-${role}" data-role="${role}" x="${n1(x - w / 2)}" y="${y}">${n}<tspan class="pc-unit" dx=".5">%</tspan></text>`; };
const star = (x, y, r, extra = '') => { let d = ''; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .45 : r; d += (i ? 'L' : 'M') + (x + rr * Math.cos(a)).toFixed(2) + ' ' + (y + rr * Math.sin(a)).toFixed(2); }
  return `<path class="pc-star" d="${d}Z"${extra}/>`; };
const BAR_H = 58;

// Two bars, ability (white) and cost (violet); full length = top effort. The bar is filled to the current effort (white
// tick, number below); a trial adds a blue tick, a blue number and a blue segment between the two; ★ is a thin gold
// line with a small ★ above the bar.
function barsSvg(m, s, cols, W, ui) {
  const {L, E} = edges(ui, W), X = v => L + (E - L) * Math.min(1, Math.max(0, v));
  const cur = s.cur ? shareOfTop(m, cols.C) : null, trial = s.trying ? shareOfTop(m, cols.T) : null, rec = shareOfTop(m, cols.R);
  let g = '';
  [['abl', 'mfd.pctAbility'], ['cost', 'mfd.pctCost']].forEach(([k, name], i) => {
    const top = i * 29, by = top + 12, vc = cur?.[k] ?? null, vt = trial?.[k] ?? null, vr = rec[k];
    let b = box(0, by - 2.5, 5, 5, 'pc-chip', ' rx="1"') + label(8, by + 3.2, t(name), 'pc-label');
    b += box(L, by - 1.5, E - L, 3, 'pc-track', ' rx="1.5"');
    if (vc != null) b += box(L, by - 1.5, X(vc) - L, 3, 'pc-fill', ` rx="1.5" data-v="${vc}"`);
    if (vt != null) { const a = vc != null ? X(vc) : L, z = X(vt); b += box(Math.min(a, z), by - 1.5, Math.abs(z - a), 3, 'pc-seg'); }
    if (vr == null || E - X(vr) > 24) b += label(E, top + 6.5, t('mfd.pctMax'), 'pc-max', 'end');
    if (vr != null) { const xr = X(vr); b += box(xr - 1.5, by - 5, 3, 10, 'pc-halo') + box(xr - .5, by - 4.5, 1, 9, 'pc-rec', ` data-role="rec" data-v="${vr}"`) + star(xr, top + 4.2, 3.6, ' data-role="rec"'); }
    const nums = [];
    if (vc != null) { b += box(X(vc) - 1, by - 5, 2, 10, 'pc-tick pc-current', ` data-role="current" data-v="${vc}"`); nums.push({x: X(vc), v: vc, role: 'current'}); }
    if (vt != null) { b += box(X(vt) - 1, by - 5, 2, 10, 'pc-tick pc-trial', ` data-role="trial" data-v="${vt}"`); nums.push({x: X(vt), v: vt, role: 'trial'}); }
    // Two numbers are kept 24 px apart, each pushed away from the other by half the overlap.
    if (nums.length === 2) { const [p, q] = nums, dx = q.x - p.x, need = 24; if (Math.abs(dx) < need) { const sh = (need - Math.abs(dx)) / 2, sg = dx >= 0 ? 1 : -1; q.x += sg * sh; p.x -= sg * sh; } }
    for (const o of nums) b += pctNum(Math.max(L + 9, Math.min(E - 9, o.x)), top + 25, o.v, o.role);
    g += `<g class="pc-bar pc-${k}" data-series="${k}">${b}</g>`;
  });
  const shown = cur ? [s.cur, cur] : trial ? [s.trial, trial] : [m.rec, rec];
  const aria = t('mfd.pctBarsAria', {m: m.short, e: shown[0], a: pctText(shown[1].abl), c: pctText(shown[1].cost)});
  return `<svg class="cmp-bars" viewBox="0 0 ${W} ${BAR_H}" width="${W}" height="${BAR_H}" role="img" aria-label="${esc(aria)}">${g}</svg>`;
}

// The line chart under the bars: ability (white), cost (violet) and time (grey dotted) across the published efforts,
// each as a share of the top effort. Current column tinted white, trial column blue; ★ on the ability line.
function lineSvg(m, s, cols, {w: W, h: H}, ui) {
  const {L, E} = edges(ui, W), T0 = 6, B0 = 4, efforts = m.e.map(r => r[0]), bw = (E - L) / efforts.length;
  const rows = efforts.map(l => shareOfTop(m, colOf(m, s.tier, l, false)));
  const ci = s.cur ? efforts.indexOf(s.cur) : -1, ti = s.trying ? efforts.indexOf(s.trial) : -1, ri = efforts.indexOf(m.rec);
  const at = {[ci]: s.cur ? shareOfTop(m, cols.C) : null, [ti]: s.trying ? shareOfTop(m, cols.T) : null};
  const all = [...rows, ...Object.values(at).filter(Boolean)].flatMap(r => [r.abl, r.cost, r.time]).filter(numeric);
  const aria = t('mfd.pctChartAria', {m: m.short, efforts: efforts.join(' → ')});
  if (!all.length) return `<svg class="cmp-chart" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(aria)}"></svg>`;
  const span = Math.max(1, ...all), X = i => L + (i + .5) * bw, Y = v => T0 + (1 - v / span) * (H - T0 - B0);
  const band = (i, cls) => box(X(i) - bw / 2 + 3, 1, bw - 6, H - 2, cls, ` rx="2" data-effort="${esc(efforts[i])}"`);
  let g = (ci >= 0 ? band(ci, 'pc-band pc-band-current') : '') + (ti >= 0 ? band(ti, 'pc-band pc-band-trial') : '');
  for (const v of [1, .5, 0]) { const y = Y(v); g += `<line class="pc-grid${v === 1 ? ' unit' : ''}" x1="${L}" x2="${n1(E)}" y1="${n1(y)}" y2="${n1(y)}"/>` + label(L - 5, Math.max(8, Math.min(H - 1, y + 3)), v ? pctText(v) : '0', 'pc-tick-l', 'end'); }
  const dot = (cls, x, y, r, extra = '') => `<circle class="${cls}" cx="${n1(x)}" cy="${n1(y)}" r="${r}"${extra}/>`;
  for (const k of ['time', 'cost', 'abl']) {
    const vs = rows.map(r => r[k]);
    if (!vs.some(numeric)) continue;
    const runs = [];
    vs.forEach((v, i) => { if (!numeric(v)) return; if (!runs.length || !numeric(vs[i - 1])) runs.push([]); runs.at(-1).push(i); });
    let p = runs.filter(r => r.length > 1).map(r => `<polyline points="${r.map(i => n1(X(i)) + ',' + n1(Y(vs[i]))).join(' ')}"/>`).join('');
    if (k !== 'time') vs.forEach((v, i) => {
      const own = at[i]?.[k], y = numeric(own) ? Y(own) : numeric(v) ? Y(v) : null;
      if (y == null) return;
      if (k === 'abl' && i === ri) { if (i === ti) p += dot('pc-ring pc-ring-rec', X(i), y, 5.6, ' data-role="trial"'); p += star(X(i), y, 4, ' data-role="rec"'); }
      else if (i === ti) p += dot('pc-ring', X(i), y, 2.6, ' data-role="trial"');
      else if (i === ci) p += dot('pc-dot pc-dot-current', X(i), y, 2.5, ' data-role="current"');
      else p += dot('pc-dot', X(i), y, 1.3);
    });
    g += `<g class="pc-line pc-${k}" data-series="${k}">${p}</g>`;
  }
  // Time is the one series the bars do not name: its legend sits bottom right inside the plot.
  if (rows.some(r => numeric(r.time))) {
    const word = t('mfd.pctTime'), lw = [...word].reduce((w, ch) => w + (/[　-鿿]/.test(ch) ? 8.5 : 4.8), 0) + 14, lx = E - lw, ly = H - B0 - 4;
    g += `<g class="pc-legend"><line class="pc-legend-time" x1="${n1(lx)}" x2="${n1(lx + 9)}" y1="${n1(ly - 3)}" y2="${n1(ly - 3)}"/>${label(lx + 12, ly, word, 'pc-legend-l')}</g>`;
  }
  g += efforts.map((l, i) => box(L + i * bw, 0, bw, H, 'pc-hit', ` data-mfd="try:${esc(l)}"`)).join('');
  return `<svg class="cmp-chart" data-scale="share" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(aria)}">${g}</svg>`;
}

export function comparison(d, ui, args) {
  const s = cmpState(d, ui, args);
  if (!s) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const {m, cur, base, tier, trial} = s;
  const cols = {C: colOf(m, tier, base, s.curFast), T: colOf(m, tier, trial, s.trialFast), R: colOf(m, tier, m.rec, false)};
  const fastShown = !!tier && ((cur && cols.C.fast) || (s.trying && cols.T.fast));
  const note = [!cur ? `<em>${t('mfd.currentUnknown')}</em>` : '', fastShown ? `<em role="img" aria-label="${esc(t('mfd.fastLine', {s: tier.speed, c: tier.cost}))}">${bolt()}</em>` : ''].filter(Boolean).join('');
  const words = websiteWords(ui.lang), size = fill(ui, 'cmp', {w: 300, h: 60}), title = t('mfd.cmpTitle', {m: m.short});
  const howFits = textW(title) * 1.2 + textW(words.compare + ' ↗') + textW(words.how + ' ↗') + 36 <= size.w;
  const links = `<span class="cmp-header-links">${secondaryLink(modelUrl(m.id), words.compare)}${howFits ? secondaryLink(methodologyUrl('cost-basis'), words.how) : ''}</span>`;
  const {L, E} = edges(ui, size.w), levels = m.e.map(r => r[0]);
  const ladder = `<div class="cmp-lad" style="--cl:${L}px;--cr:${size.w - E}px">${levels.map(l => `<button class="lad ${l === base && cur ? 'cur' : ''} ${l === trial && s.trying ? 'try' : ''} ${l === m.rec ? 'rec' : ''}" data-mfd="try:${l}" aria-label="${esc(t('mfd.ladderAria', {e: l}))}">${l === m.rec ? '★' : ''}${l}</button>`).join('')}</div>`;
  // polish A: on a short screen the chart is left out instead of being clipped (the bars and the keys still compare).
  const chart = size.h >= 34 && size.w >= 160 ? lineSvg(m, s, cols, size, ui) : '';
  return `<div class="cmp-h"><b class="mfd-title">${esc(title)}</b>${note ? `<span class="cmp-note">${note}</span>` : ''}${links}</div>
    <div class="cmp-bars-row" data-trying="${s.trying}">${barsSvg(m, s, cols, size.w, ui)}</div><div class="mfd-fill" data-fill="cmp">${chart}</div>${ladder}`;
}
// The bottom key row while the comparison is shown (round D1): back to the page underneath, fast mode in the trial
// (both states printed, only for a tool with a fast mode; otherwise a dark key) only. The two keys share the footer width.
export function compareKeys(d, ui, args, {back = ''} = {}) {
  const s = cmpState(d, ui, args);
  const fast = s?.tier
    ? `<button class="ok soft vk-fast" data-mfd="fast" data-mat="part" aria-pressed="${s.trialFast}" aria-label="${esc(t('mfd.kFastAria', {on: t(s.trialFast ? 'mfd.fastOn' : 'mfd.fastOff')}))}"><span class="ok-l"><i class="vk-g" aria-hidden="true">${bolt()}</i><span class="vk-n">${t('mfd.kFast')}</span><b class="${s.trialFast ? '' : 'on'}">${t('mfd.fastOff')}</b><i class="ok-sep" aria-hidden="true"></i><b class="${s.trialFast ? 'on' : ''}">${t('mfd.fastOn')}</b></span></button>`
    : `<span class="ok soft off vk-fast" data-mat="part" aria-hidden="true"></span>`;
  return `<div class="mfd-ok mfd-vk" role="toolbar" aria-label="${esc(t('mfd.vkAria'))}"><button class="ok soft vk-back" data-mfd="back" data-mat="part" aria-label="${esc(t('mfd.backAria', {p: back}))}"><span class="ok-l">${esc(t('mfd.kBack', {p: back}))}</span></button>${fast}</div>`;
}
const cmpClick = (act, val, ui, d, args) => {
  if (act === 'try') return {trial: {...args, trial: val}};
  if (act === 'fast') { const s = cmpState(d, ui, args); return s?.tier ? {trial: {...args, fast: !s.trialFast, currentFast: s.curFast}} : null; }
  return null;
};

const textW = s => [...s].reduce((w, ch) => w + (/[　-鿿＀-￯]/.test(ch) ? 10 : 5.6), 0);

export const compareView = {render: comparison, keys: compareKeys, pageless: true, ownTitle: true, onClick: cmpClick};
