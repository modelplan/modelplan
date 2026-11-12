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
const star = (x, y, r, extra = '') => { let d = ''; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .45 : r; d += (i ? 'L' : 'M') + (x + rr * Math.cos(a)).toFixed(2) + ' ' + (y + rr * Math.sin(a)).toFixed(2); }
  return `<path class="pc-star" d="${d}Z"${extra}/>`; };
const BAR_H = 58;

// Two stereo-lane bars, ability (white) and cost (violet); full length = top effort (100 %). The whole 0-100 % track is
// always drawn (a faint tint of the bar colour inside a 1 px outline) and ends in a bright 100 % stop; notches every
// 10 % are cut into the tube, the one at 50 % at full height. No trial: one solid bar to the current effort. A trial
// splits the tube into two lanes from 0: real on top (solid, the bar's colour), trial below (solid blue). ★ is a thin
// gold line through the bar with a small ★ above it; white number = current, blue = trial, equal = one number with a
// blue "="; a fast value past 100 % pins to the end with › and prints the exact number. Every effort segment is a
// control (hover previews it, click tries it). Demo v12 (owner 11-12: option B with the notch divisions).
let barUid = 0;
const STAR_MODE = 'a';
const clamp01 = v => Math.max(0, Math.min(1, v));
const BAR_RECT = (x, y, w, h, cls, extra = '') => w > .05 ? `<rect${cls ? ` class="${cls}"` : ''} x="${(+x).toFixed(2)}" y="${(+y).toFixed(2)}" width="${(+w).toFixed(2)}" height="${(+h).toFixed(2)}"${extra}/>` : '';
// One number with a small %, centred on x; pre = a small blue "=" (the trial equals the current).
const pctNum = (x, y, v, role, pre) => { const n = String(Math.round(v * 100)), w = n.length * 6 + 4.5 + (pre ? 7 : 0);
  return `<text class="pc-num pc-${role}" data-role="${role}"${pre ? ' data-equal="true"' : ''} x="${n1(x - w / 2)}" y="${y}">${pre ? `<tspan class="pc-eq">=</tspan><tspan dx="1">${n}</tspan>` : n}<tspan class="pc-unit" dx=".5">%</tspan></text>`; };

// rows: [{k, vb (current or null), vt (trial or null), vr (★), eff: [{l, v}] (every effort at the shown speed)}]
function barsSvg(m, s, cols, W, ui) {
  const {L, E} = edges(ui, W), cmp = !!ui.compact, TH = cmp ? 9 : 11, inset = 1, rT = 3, ix0 = L + inset, ix1 = E - inset;
  const X = v => ix0 + (ix1 - ix0) * clamp01(v), id = 'eb' + (++barUid), rowH = BAR_H / 2;
  const cur = s.cur ? shareOfTop(m, cols.C) : null, trial = s.trying ? shareOfTop(m, cols.T) : null, rec = shareOfTop(m, cols.R);
  const starMode = ui.starMode || STAR_MODE, speedFast = s.trying ? s.trialFast : s.curFast;
  const at = l => shareOfTop(m, colOf(m, s.tier, l, speedFast));
  let defs = '', g = '', hit = '';
  [['abl', 'mfd.pctAbility'], ['cost', 'mfd.pctCost']].forEach(([k, name], i) => {
    const top = i * rowH, cy = top + (cmp ? 13 : 13.5), y0 = cy - TH / 2, iy = y0 + inset, ih = TH - 2 * inset;
    const vb = cur?.[k] ?? null, vt = trial?.[k] ?? null, vr = rec[k], tr = vt != null;
    const up = tr && vb != null && Math.round(vt * 100) > Math.round(vb * 100), down = tr && vb != null && Math.round(vt * 100) < Math.round(vb * 100), eq = tr && vb != null && !up && !down;
    const xc = vb != null ? X(vb) : ix0, xt = tr ? X(vt) : xc, over = Math.max(vb ?? 0, vt ?? 0) > 1;
    const clip = `${id}c${i}`;
    defs += `<clipPath id="${clip}"><rect x="${ix0}" y="${n1(iy)}" width="${n1(ix1 - ix0)}" height="${n1(ih)}" rx="${rT - inset}"/></clipPath>`
      + `<linearGradient id="${id}${k}" x1="0" y1="0" x2="0" y2="1"><stop class="pc-g-${k}0" offset="0"/><stop class="pc-g-${k}1" offset="1"/></linearGradient>`;
    if (i === 0) defs += `<linearGradient id="${id}t" x1="0" y1="0" x2="0" y2="1"><stop class="pc-t0" offset="0"/><stop class="pc-t1" offset="1"/></linearGradient><filter id="${id}g" x="-5%" y="-200%" width="110%" height="500%"><feGaussianBlur stdDeviation="1.3"/></filter>`;
    let b = box(0, y0 + inset, 5, ih, 'pc-chip', ' rx="1"') + label(8, cy + 3.2, t(name), 'pc-label');
    // the track: the whole 0-100 % length, tinted, with a dark top edge and a 1 px outline
    b += `<rect class="pc-track" x="${L}" y="${n1(y0)}" width="${n1(E - L)}" height="${TH}" rx="${rT}" data-v="1"/>`
      + box(L + rT, y0, E - L - 2 * rT, 1, 'pc-edge') + `<rect class="pc-outline" x="${L + .5}" y="${n1(y0 + .5)}" width="${n1(E - L - 1)}" height="${TH - 1}" rx="${rT - .5}"/>`;
    // the fills, clipped to the inside of the tube
    let f = '', glow = '';
    const gl = (a, z, y, h, cls) => `<g class="pc-glow ${cls}" filter="url(#${id}g)">${BAR_RECT(a, y, z - a, h, '')}</g>`;
    if (tr) {
      const lr = cmp ? 4 : 5, lt = ih - lr - 1;
      if (vb != null) { glow += gl(ix0, xc, iy, lr, 'real'); f += BAR_RECT(ix0, iy, xc - ix0, lr, 'pc-fill', ` fill="url(#${id}${k})" data-v="${vb}"`) + BAR_RECT(ix0, iy, xc - ix0, 1, 'pc-hi') + BAR_RECT(xc - 1, iy, 1, lr, 'pc-cap'); }
      glow += gl(ix0, xt, iy + lr + 1, lt, 'trial');
      f += BAR_RECT(ix0, iy + lr + 1, xt - ix0, lt, 'pc-lane-trial', ` fill="url(#${id}t)" data-v="${vt}"`) + BAR_RECT(xt - 1, iy + lr + 1, 1, lt, 'pc-cap-trial');
    } else if (vb != null) {
      glow += gl(ix0, xc, iy, ih, 'real');
      f += BAR_RECT(ix0, iy, xc - ix0, ih, 'pc-fill', ` fill="url(#${id}${k})" data-v="${vb}"`) + BAR_RECT(ix0, iy, xc - ix0, 1, 'pc-hi');
    }
    // notches every 10 % (50 % at full height): cut into the tube, glass where the fill is, tinted where it is not
    const fillEnd = Math.max(vb != null ? xc : 0, tr ? xt : 0), nh = cmp ? 1.5 : 2;
    for (let p = 1; p < 10; p++) { const x = X(p / 10), on = x < fillEnd - .5, c = `pc-notch${on ? ' on' : ''}${p === 5 ? ' mid' : ''}`;
      f += p === 5 ? box(x - .5, iy, 1, ih, c, ` data-p="${p * 10}"`) : box(x - .5, iy, 1, nh, c, ` data-p="${p * 10}"`) + box(x - .5, iy + ih - nh, 1, nh, c, ` data-p="${p * 10}"`); }
    b += glow + `<g clip-path="url(#${clip})">${f}</g>`;
    // the 100 % stop: the end of the scale is never in doubt
    b += box(E - 2, y0 - 1.5, 2, TH + 3, 'pc-end', ' rx=".5" data-v="1"');
    // ★ (standard speed; the recommendation never includes fast): the gold line through the bar and a small ★ above it
    const xr = vr != null ? X(vr) : null;
    if (i === 0 && (xr == null || (E - xr > 30 && !over))) b += label(E, top + (cmp ? 5.5 : 6), t('mfd.pctMax'), 'pc-max', 'end');
    if (xr != null) {
      // ★ placement is switchable (ui.starMode): a = above the tube on the tick, b = tick through the tube and ★ below it, c = ★ centred on the tube at the tick
      const sy0 = starMode === 'a' ? top + 6.5 : y0 - 2, tick = (a, z) => box(xr - 1.5, a, 3, z - a, 'pc-halo') + box(xr - .5, a, 1, z - a - .5, 'pc-rec', ` data-role="rec" data-v="${vr}"`);
      b += tick(sy0, y0 + TH + 2) + (starMode === 'a' ? star(xr, top + 3.9, 3.6, ' data-role="rec"') : starMode === 'b' ? star(xr, y0 + TH + 6, 3.2, ' data-role="rec"') : star(xr, cy, 3.6, ' data-role="rec"'));
    }
    // fast can pass the full bar: the value pins to the end, a chevron marks the overflow, the number is exact
    if (over) b += `<path class="pc-over${(vt ?? 0) > 1 && tr ? ' trial' : ''}" d="M${E + 2} ${n1(cy - 3)}l3 3-3 3"/>`;
    // hover previews: a dashed line at every other effort's value, shown while the pointer is on that effort anywhere
    for (const l of m.e.map(r => r[0])) { if (l === s.trial) continue; const v = at(l)[k]; if (v == null) continue;
      const xh = X(v); b += `<line class="pc-preview" data-effort="${esc(l)}" x1="${n1(xh)}" x2="${n1(xh)}" y1="${n1(y0 - 3.5)}" y2="${n1(y0 + TH + 3.5)}"/>`; }
    // the numbers under the bar: ink = current, blue = trial; equal = one number with a blue "="
    const labs = []; if (vb != null) labs.push({x: xc, v: vb, role: 'current', pre: eq}); if (tr && !eq) labs.push({x: xt, v: vt, role: 'trial'});
    if (labs.length === 2) { const [p, q] = labs, d = q.x - p.x, need = 27; if (Math.abs(d) < need) { const sh = (need - Math.abs(d)) / 2, sg = d >= 0 ? 1 : -1; q.x += sg * sh; p.x -= sg * sh; }
      const lo = L + 10, hi = E - 12; if (q.x > hi) { p.x -= q.x - hi; q.x = hi; } if (p.x > hi) { q.x -= p.x - hi; p.x = hi; } if (p.x < lo) { q.x += lo - p.x; p.x = lo; } if (q.x < lo) { p.x += lo - q.x; q.x = lo; } }
    for (const o of labs) b += pctNum(Math.max(L + 10 + (o.pre ? 3 : 0), Math.min(E - 12, o.x)), n1(top + (cmp ? 26.5 : 27.5)), o.v, o.role, o.pre);
    g += `<g class="pc-bar pc-${k}" data-series="${k}">${b}</g>`;
    // the bar is a control: each effort's segment (from the effort below it to this one) tries that effort
    const eff = m.e.map(r => ({l: r[0], x: X(at(r[0])[k] ?? 0)})).sort((p, q) => p.x - q.x); eff.forEach((e, j) => { e.x0 = j ? eff[j - 1].x : L; });
    let h = `<rect class="pc-hit" data-hk="${k}" x="0" y="${n1(top)}" width="${L}" height="${rowH}"/>`;
    for (const e of eff) if (e.x - e.x0 >= 1) h += `<rect class="pc-hit pc-seg-hit" data-mfd="try:${esc(e.l)}" data-hover="${esc(e.l)}" data-hk="${k}" x="${n1(e.x0 - .5)}" y="${n1(top)}" width="${n1(e.x - e.x0 + 1)}" height="${rowH}"><title>${esc(e.l)}</title></rect>`;
    h += `<rect class="pc-hit" data-hk="${k}" x="${n1(eff.at(-1).x + .5)}" y="${n1(top)}" width="${n1(Math.max(0, E - eff.at(-1).x))}" height="${rowH}"/>`;
    hit += h;
  });
  const shown = cur ? [s.cur, cur] : trial ? [s.trial, trial] : [m.rec, rec];
  const aria = t('mfd.pctBarsAria', {m: m.short, e: shown[0], a: pctText(shown[1].abl), c: pctText(shown[1].cost)});
  return `<svg class="cmp-bars" viewBox="0 0 ${W} ${BAR_H}" width="${W}" height="${BAR_H}" role="img" aria-label="${esc(aria)}"><defs>${defs}</defs>${g}${hit}</svg>`;
}

// The line chart under the bars: ability (white), cost (violet) and time (grey dotted) across the published efforts,
// each as a share of the top effort. Current column tinted white, trial column blue; ★ on the ability line.
function lineSvg(m, s, cols, {w: W, h: H}, ui) {
  const {L, E} = edges(ui, W), T0 = 6, B0 = 4, efforts = m.e.map(r => r[0]), bw = (E - L) / efforts.length;
  const standard = efforts.map(l => shareOfTop(m, colOf(m, s.tier, l, false)));
  // Fast on (the real mode, or the trial's): every effort's cost and time are drawn with the tier applied, the Standard
  // lines stay faint behind them and a band between each pair shows every effort's move (the website's effort page).
  const fastOn = !!s.tier && (s.trying ? s.trialFast : s.curFast);
  const rows = fastOn ? efforts.map(l => shareOfTop(m, colOf(m, s.tier, l, true))) : standard;
  const ci = s.cur ? efforts.indexOf(s.cur) : -1, ti = s.trying ? efforts.indexOf(s.trial) : -1, ri = efforts.indexOf(m.rec);
  const at = {[ci]: s.cur ? shareOfTop(m, cols.C) : null, [ti]: s.trying ? shareOfTop(m, cols.T) : null};
  const all = [...rows, ...standard, ...Object.values(at).filter(Boolean)].flatMap(r => [r.abl, r.cost, r.time]).filter(numeric);
  const aria = t('mfd.pctChartAria', {m: m.short, efforts: efforts.join(' → ')});
  if (!all.length) return `<svg class="cmp-chart" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(aria)}"></svg>`;
  const span = Math.max(1, ...all), X = i => L + (i + .5) * bw, Y = v => T0 + (1 - v / span) * (H - T0 - B0);
  const band = (i, cls) => box(X(i) - bw / 2 + 3, 1, bw - 6, H - 2, cls, ` rx="2" data-effort="${esc(efforts[i])}"`);
  // the recommended effort's column: a very faint gold wash under everything, so it never fights the blue trial / hover boxes
  let g = (ri >= 0 ? band(ri, 'pc-band pc-band-rec') : '') + (ci >= 0 ? band(ci, 'pc-band pc-band-current') : '') + (ti >= 0 ? band(ti, 'pc-band pc-band-trial' + (ti === ci ? ' pc-band-same' : '')) : '');
  // hover preview: a dashed blue box on the column of the effort under the pointer (any other effort than the trial)
  g += efforts.map((l, i) => l === s.trial ? '' : band(i, 'pc-band pc-band-hover')).join('');
  for (const v of [1, .5, 0]) { const y = Y(v); g += `<line class="pc-grid${v === 1 ? ' unit' : ''}" x1="${L}" x2="${n1(E)}" y1="${n1(y)}" y2="${n1(y)}"/>` + label(L - 5, Math.max(8, Math.min(H - 1, y + 3)), v ? pctText(v) : '0', 'pc-tick-l', 'end'); }
  const dot = (cls, x, y, r, extra = '') => `<circle class="${cls}" cx="${n1(x)}" cy="${n1(y)}" r="${r}"${extra}/>`;
  const path = (vs, runs) => runs.filter(r => r.length > 1).map(r => `<polyline points="${r.map(i => n1(X(i)) + ',' + n1(Y(vs[i]))).join(' ')}"/>`).join('');
  const runsOf = vs => { const runs = []; vs.forEach((v, i) => { if (!numeric(v)) return; if (!runs.length || !numeric(vs[i - 1])) runs.push([]); runs.at(-1).push(i); }); return runs; };
  if (fastOn) for (const k of ['time', 'cost']) {
    const pairs = efforts.map((_, i) => [standard[i][k], rows[i][k]]).map(([a, b], i) => numeric(a) && numeric(b) ? {i, a, b} : null).filter(Boolean);
    if (pairs.length < 2 || pairs.every(q => Math.abs(q.a - q.b) < 1e-9)) continue;
    const d = pairs.map((q, j) => `${j ? 'L' : 'M'}${n1(X(q.i))} ${n1(Y(q.b))}`).join(' ') + [...pairs].reverse().map(q => ` L${n1(X(q.i))} ${n1(Y(q.a))}`).join('') + ' Z';
    g += `<path class="pc-fastband pc-${k}" data-series="${k}" d="${d}"/>`;
    g += `<g class="pc-line pc-${k} pc-std" data-series="${k}" data-fast="standard">${path(standard.map(r => r[k]), runsOf(standard.map(r => r[k])))}</g>`;
  }
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
  g += efforts.map((l, i) => box(L + i * bw, 0, bw, H, 'pc-hit', ` data-mfd="try:${esc(l)}" data-hover="${esc(l)}"`)).join('');
  return `<svg class="cmp-chart" data-scale="share" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(aria)}">${g}</svg>`;
}

export function comparison(d, ui, args) {
  const s = cmpState(d, ui, args);
  if (!s) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const {m, cur, base, tier, trial} = s;
  const cols = {C: colOf(m, tier, base, s.curFast), T: colOf(m, tier, trial, s.trialFast), R: colOf(m, tier, m.rec, false)};
  const note = [!cur ? `<em>${t('mfd.currentUnknown')}</em>` : ''].filter(Boolean).join('');
  const words = websiteWords(ui.lang), size = fill(ui, 'cmp', {w: 300, h: 60}), title = t('mfd.cmpTitle', {m: m.short});
  const howFits = textW(title) * 1.2 + textW(words.compare + ' ↗') + textW(words.how + ' ↗') + 36 <= size.w;
  const links = `<span class="cmp-header-links">${secondaryLink(modelUrl(m.id), words.compare)}${howFits ? secondaryLink(methodologyUrl('cost-basis'), words.how) : ''}</span>`;
  const {L, E} = edges(ui, size.w), levels = m.e.map(r => r[0]);
  const ladder = `<div class="cmp-lad" style="--cl:${L}px;--cr:${size.w - E}px">${levels.map(l => `<button class="lad ${l === base && cur ? 'cur' : ''} ${l === trial && s.trying ? 'try' : ''} ${l === m.rec ? 'rec' : ''}" data-mfd="try:${l}" data-hover="${l}" aria-label="${esc(t('mfd.ladderAria', {e: l}))}">${l === m.rec ? '★' : ''}${l}</button>`).join('')}</div>`;
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
