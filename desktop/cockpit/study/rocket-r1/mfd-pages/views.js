// SPDX-License-Identifier: MIT
// Ported from the opus-r7 study (rocket-r1/mfd-pages/views.js, round D1): the comparison view a fader trial opens
// (spec 6.4). Only the comparison is ported; the alert list and the session view live in prototype-deck.ts.
// Pure view (v8, CKP-MFD-33; v1 final bar version, CKP-MFD-50…54): ability and cost bars as shares of the top effort, the
// share line chart, the effort keys with two numbers under each, the hint row; its own bottom keys (‹ back, ⚡ fast).
// Nothing is applied to a session: there is no Enter-to-apply.
import {websiteWords,modelUrl,methodologyUrl,secondaryLink} from './public-helpers.js';
import {t} from '../i18n.js';
import '../strings/review49.js';
import {esc, fill, bolt, tokShort} from './fmt.js';
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

// v8 (CKP-MFD-33; D165, D177, D190, D201, demo v8) as amended for v1 final (V1-FINAL §8.5, LATER, CKP-MFD-52): cost and
// time are shares of the model's top effort (the published top of the ladder, = 100 %, "Max"); a fast configuration
// multiplies its own cost and time, so a fast trial may go past 100 %. Ability is a share of the model's HIGHEST-SCORING
// effort (which need not be the top one; the page then names it), each metric's reference independent of the others.
// Ability is ModelPlan's own published score (row[1]), never the AA score (row[4], a tooltip reference only; D292 as amended
// by the owner 11-17). Only ratios are used: no threshold, axis top or "average" text depends on the score's scale, so the
// planned AA-aligned display scale (34.185 + 8.150·q) changes the numbers, not the page.
const ORDER = ['Low', 'Med', 'High', 'XHigh', 'Max'];
const topRow = m => m.e.reduce((a, b) => !a || ORDER.indexOf(b[0]) >= ORDER.indexOf(a[0]) ? b : a, null);
// The highest published ability score of the model (ties: the higher effort); null when no effort has a score.
export const bestRow = m => m.e.reduce((a, b) => numeric(b[1]) && b[1] > 0 && (!a || b[1] > a[1] || (b[1] === a[1] && ORDER.indexOf(b[0]) > ORDER.indexOf(a[0]))) ? b : a, null);
export function shareOfTop(m, c) {
  const top = topRow(m), best = bestRow(m);
  return top ? {abl: best ? ratio(c.r[1], best[1]) : null, cost: ratio(c.cost, top[2]), time: ratio(c.time, top[3])} : {abl: null, cost: null, time: null};
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

// Two stereo-lane bars, ability (white) and cost (mid-grey #8d97a1); full length = top effort (100 %). The whole 0-100 % track is
// always drawn (a faint tint of the bar colour inside a 1 px outline) and ends in a bright 100 % stop; notches every
// 10 % are cut into the tube, the one at 50 % at full height. No trial: one solid bar to the current effort. A trial
// splits the tube into two lanes from 0: real on top (solid, the bar's colour), trial below (solid blue). ★ is a thin
// gold line through the bar with a small ★ above it; white number = current, blue = trial, equal = one number with a
// blue "="; a fast value past 100 % pins to the end with › and prints the exact number. Every effort segment is a
// control (hover previews it, click tries it). Demo v12 (owner 11-12: option B with the notch divisions).
let barUid = 0;
const STAR_MODE = 'a', LANE_MODE = '3';
// Lane treatment (ui.laneMode): 1 = lanes separated only by the track tint, 2 = 1 px glass gap, 3 = 1.5 px glass gap and a deeper trial blue, 4 = 1 px gap and a dark hairline on the trial lane's top edge.
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
  const starMode = ui.starMode || STAR_MODE, laneMode = ui.laneMode || LANE_MODE, speedFast = s.trying ? s.trialFast : s.curFast;
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
      const gap = laneMode === '3' ? 1.5 : 1, lr = laneMode === '3' ? (cmp ? 3.5 : 4.5) : cmp ? 4 : 5, lt = ih - lr - gap;
      if (vb != null) { glow += gl(ix0, xc, iy, lr, 'real'); f += BAR_RECT(ix0, iy, xc - ix0, lr, 'pc-fill', ` fill="url(#${id}${k})" data-v="${vb}"`) + BAR_RECT(ix0, iy, xc - ix0, 1, 'pc-hi') + BAR_RECT(xc - 1, iy, 1, lr, 'pc-cap'); }
      glow += gl(ix0, xt, iy + lr + gap, lt, 'trial');
      f += BAR_RECT(ix0, iy + lr + gap, xt - ix0, lt, 'pc-lane-trial', ` fill="url(#${id}t)" data-v="${vt}"`) + BAR_RECT(xt - 1, iy + lr + gap, 1, lt, 'pc-cap-trial')
        + (laneMode === '1' ? '' : BAR_RECT(ix0, iy + lr, Math.max(xc, xt) - ix0, gap, 'pc-gap')) + (laneMode === '4' ? BAR_RECT(ix0, iy + lr + gap, xt - ix0, 1, 'pc-shade') : '');
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
    // "100%" above the ability bar's end; when the best-scoring effort is not the top one it is named: "100% = XHigh"
    const best = i === 0 ? bestRow(m) : null, named = best && best[0] !== topRow(m)?.[0];
    if (i === 0 && (named || xr == null || (E - xr > 30 && !over))) b += label(E, top + (cmp ? 5.5 : 6), named ? t('mfd.pctMaxAt', {e: best[0]}) : t('mfd.pctMax'), 'pc-max', 'end');
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
  return `<svg class="cmp-bars lane-${laneMode}" viewBox="0 0 ${W} ${BAR_H}" width="${W}" height="${BAR_H}" role="img" aria-label="${esc(aria)}"><defs>${defs}</defs>${g}${hit}</svg>`;
}

// The line chart under the bars: ability (white), cost (mid-grey) and time (grey dotted) across the published efforts,
// each as a share of the top effort. Current column tinted white, trial column blue; ★ on the ability line.
function lineSvg(m, s, cols, {w: W, h: H}, ui) {
  const {L, E} = edges(ui, W), T0 = 13, B0 = 4, efforts = m.e.map(r => r[0]), bw = (E - L) / efforts.length;
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
  // Fast on: a fixed 0-150 % domain (the whole lines rise); a point past it is pinned to the top edge with a small ▲ and its exact value.
  const span = fastOn ? 1.5 : Math.max(1, ...all), X = i => L + (i + .5) * bw, Y = v => T0 + (1 - Math.min(v, span) / span) * (H - T0 - B0);
  const band = (i, cls) => box(X(i) - bw / 2 + 3, 1, bw - 6, H - 2, cls, ` rx="2" data-effort="${esc(efforts[i])}"`);
  // column backgrounds, bottom to top: a pale white haze on the current effort, a pale blue haze with its border on the trial
  let g = (ci >= 0 ? band(ci, 'pc-band pc-band-current') : '') + (ti >= 0 ? band(ti, 'pc-band pc-band-trial') : '');
  // hover preview: a dashed blue box on the column of the effort under the pointer (any other effort than the trial)
  g += efforts.map((l, i) => l === s.trial ? '' : band(i, 'pc-band pc-band-hover')).join('');
  // Gridlines at every step; a tick label only where it keeps 10 px from the labels already placed (0 first, then 100 %,
  // then the fast top, then 50 %), so a short chart (the compact shell, V1-FINAL §13.3) never stacks them.
  const tickYs = [], tickY = v => Math.max(8, Math.min(H - 1, Y(v) + 3));
  for (const v of [0, 1, ...(span > 1 ? [span] : []), .5]) if (tickYs.every(y => Math.abs(y - tickY(v)) >= 10)) tickYs.push(tickY(v));
  for (const v of span > 1 ? [span, 1, .5, 0] : [1, .5, 0]) { const y = Y(v); g += `<line class="pc-grid${v === 1 ? ' unit' : ''}" x1="${L}" x2="${n1(E)}" y1="${n1(y)}" y2="${n1(y)}"/>` + (tickYs.includes(tickY(v)) ? label(L - 5, tickY(v), v ? pctText(v) : '0', 'pc-tick-l', 'end') : ''); }
  const upBoxes = [];
  const dot = (cls, x, y, r, extra = '') => `<circle class="${cls}" cx="${n1(x)}" cy="${n1(y)}" r="${r}"${extra}/>`;
  const path = (vs, runs) => runs.filter(r => r.length > 1).map(r => `<polyline points="${r.map(i => n1(X(i)) + ',' + n1(Y(vs[i]))).join(' ')}"/>`).join('');
  const runsOf = vs => { const runs = []; vs.forEach((v, i) => { if (!numeric(v)) return; if (!runs.length || !numeric(vs[i - 1])) runs.push([]); runs.at(-1).push(i); }); return runs; };
  if (fastOn) for (const k of ['time', 'cost']) {
    const pairs = efforts.map((_, i) => [standard[i][k], rows[i][k]]).map(([a, b], i) => numeric(a) && numeric(b) ? {i, a, b} : null);
    const known = pairs.filter(Boolean);
    if (known.length < 2 || known.every(q => Math.abs(q.a - q.b) < 1e-9)) continue;
    // one band per run of consecutive known efforts: a missing effort is a gap, never bridged (like the lines)
    const runs = [];
    pairs.forEach((q, i) => { if (!q) return; if (!runs.length || !pairs[i - 1]) runs.push([]); runs.at(-1).push(q); });
    const d = runs.filter(r => r.length > 1).map(r => r.map((q, j) => `${j ? 'L' : 'M'}${n1(X(q.i))} ${n1(Y(q.b))}`).join(' ') + [...r].reverse().map(q => ` L${n1(X(q.i))} ${n1(Y(q.a))}`).join('') + ' Z').join(' ');
    if (d) g += `<path class="pc-fastband pc-${k}" data-series="${k}" d="${d}"/>`;
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
      const val = numeric(own) ? own : v;
      if (val > span + 1e-9) { const right = X(i) + 5 + 24 > W; upBoxes.push(right ? [X(i) - 29, X(i) - 5] : [X(i) + 5, X(i) + 29]);
        p += `<path class="pc-up" d="M${n1(X(i) - 2.6)} ${n1(T0 + 5.6)}l2.6-4.2 2.6 4.2Z"/>` + (right ? label(X(i) - 5, T0 + 6.5, pctText(val), 'pc-up-l', 'end') : label(X(i) + 5, T0 + 6.5, pctText(val), 'pc-up-l')); }
      if (k === 'abl' && i === ri) { if (i === ti) p += dot('pc-ring pc-ring-rec', X(i), y, 5.6, ' data-role="trial"'); p += star(X(i), y, 4, ' data-role="rec"'); }
      else if (i === ti) p += dot('pc-ring', X(i), y, 2.6, ' data-role="trial"');
      else if (i === ci) p += dot('pc-dot pc-dot-current', X(i), y, 2.5, ' data-role="current"');
      else p += dot('pc-dot', X(i), y, 1.3);
    });
    g += `<g class="pc-line pc-${k}" data-series="${k}">${p}</g>`;
  }
  // Time is the one series the bars do not name: its legend sits bottom right inside the plot.
  // On a short chart it would meet a ▲ value label at the top right; then the legend is left out (the dotted time line itself stays).
  if (rows.some(r => numeric(r.time))) {
    const word = t('mfd.pctTime'), lw = [...word].reduce((w, ch) => w + (/[　-鿿]/.test(ch) ? 8.5 : 4.8), 0) + 14, lx = E - lw, ly = H - B0 - 4;
    if (!(ly - 10 < T0 + 8.5 && upBoxes.some(([a, z]) => a < E && z > lx))) g += `<g class="pc-legend"><line class="pc-legend-time" x1="${n1(lx)}" x2="${n1(lx + 9)}" y1="${n1(ly - 3)}" y2="${n1(ly - 3)}"/>${label(lx + 12, ly, word, 'pc-legend-l')}</g>`;
  }
  // a small label at the top of each highlighted column names it (the same effort carries one label for both); the plot starts below it
  const colLabel = (i, role, key) => `<text class="pc-col-l pc-col-${role}" data-role="${role}" data-effort="${esc(efforts[i])}" x="${n1(X(i))}" y="8.6" text-anchor="middle">${esc(t(key))}${i === ri ? '<tspan class="pc-col-star"> ★</tspan>' : ''}</text>`;
  if (ci >= 0 && ci === ti) g += colLabel(ci, 'both', 'mfd.colBoth');
  else { if (ci >= 0) g += colLabel(ci, 'current', 'mfd.colCurrent'); if (ti >= 0) g += colLabel(ti, 'trial', 'mfd.colTrial'); }
  g += efforts.map((l, i) => box(L + i * bw, 0, bw, H, 'pc-hit', ` data-mfd="try:${esc(l)}" data-hover="${esc(l)}"`)).join('');
  return `<svg class="cmp-chart" data-scale="share" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(aria)}">${g}</svg>`;
}

export function comparison(d, ui, args) {
  const s = cmpState(d, ui, args);
  if (!s) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const {m, cur, base, tier, trial} = s;
  const cols = {C: colOf(m, tier, base, s.curFast), T: colOf(m, tier, trial, s.trialFast), R: colOf(m, tier, m.rec, false)};
  const note = [!cur ? `<em>${t('mfd.currentUnknown')}</em>` : '', !bestRow(m) ? `<em class="cmp-no-abl">${t('mfd.noAbility')}</em>` : ''].filter(Boolean).join('');
  const words = websiteWords(ui.lang), size = fill(ui, 'cmp', {w: 300, h: 60}), title = t('mfd.cmpTitle', {m: m.short});
  // CKP-MFD-50 (V1-FINAL §8.5, §14): right of the title, the model's own 7-day use; the ≈$ part only when an estimated
  // cost exists. The website links moved to the hint row at the bottom right (at least one is always kept).
  const use = useText(m.u7);
  const {L, E} = edges(ui, size.w), levels = m.e.map(r => r[0]);
  // CKP-FAD-18 / CKP-MFD-54: one quiet hint, bottom right: how to try while idle, "trial only" while trying. The compact
  // shell has no height for it, so it collapses to an info mark outside the key row (CSS picks one by the profile); the
  // full text is its accessible name.
  // §14: the long form first, then the short one, then none (the bare ↗ link stays); the ⓘ always names the long form.
  const hintText = s.trying ? (ui.trialNote !== false ? t('mfd.cmpTrialNote') : '') : t('mfd.cmpHintIdle');
  const hintShown = !hintText ? '' : [hintText, t(s.trying ? 'mfd.cmpTrialNoteShort' : 'mfd.cmpHintIdleShort')].find(x => textW(x) * 1.05 + 26 <= size.w) ?? '';
  const hint = hintShown ? `<p class="cmp-hint${s.trying ? ' cmp-trial-note' : ''}"${hintShown !== hintText ? ` title="${esc(hintText)}"` : ''}>${esc(hintShown)}</p>` : '';
  const hintMark = hintText ? `<button type="button" class="cmp-trial-i" aria-label="${esc(hintText)}">ⓘ</button>` : '';
  // The website link sits left of the hint (§14: one link is always kept). When the full words do not fit beside the hint
  // (English, compact) the link is a bare ↗ named by its tooltip; "how it's worked out" joins only when everything fits.
  const href = modelUrl(m.publishedId ?? m.id), room = size.w - textW(hintShown) * 1.05 - 12;
  const full = !ui.compact && textW(words.compare + ' ↗') <= room, how = full && textW(words.compare + ' ↗') + textW(words.how + ' ↗') + 8 <= room;
  const links = `<span class="cmp-links">${full ? secondaryLink(href, words.compare) + (how ? secondaryLink(methodologyUrl('cost-basis'), words.how) : '')
    : `<a class="website-link cmp-link-i" href="${href}" target="_blank" rel="noopener noreferrer" title="${esc(words.compare)}" aria-label="${esc(words.compare)}">↗</a>`}</span>`;
  const keyCls = l => `${l === base && cur ? 'cur' : ''} ${l === trial && s.trying ? 'try' : ''}`.trim();
  const ladder = `<div class="cmp-lad">${levels.map(l => `<button class="lad ${keyCls(l)} ${l === m.rec ? 'rec' : ''}" data-mfd="try:${esc(l)}" data-hover="${esc(l)}" aria-label="${esc(t('mfd.ladderAria', {e: l}))}">${l === m.rec ? '★' : ''}${esc(l)}</button>`).join('')}</div>`;
  // CKP-MFD-51/52: two numbers under every key, ability then cost with a $, at the speed the page shows (fast raises the
  // cost). Ability is OUR published score as a share of the top effort's; a published aaScore (row[4], D292) is only an
  // "AA official" reference in the cell's tooltip. Unknown = "—". White = current, blue = trial, grey = the others.
  const fastShown = !!tier && (s.trying ? s.trialFast : s.curFast);
  const nums = `<div class="cmp-nums">${levels.map(l => {
    const v = shareOfTop(m, colOf(m, tier, l, fastShown)), a = pctOrDash(v.abl), c = v.cost == null ? '—' : '$' + pctText(v.cost), aa = rowOf(m, l)[4];
    const tip = t('mfd.ladNumsAria', {e: l, a, c}) + (numeric(aa) && aa > 0 ? ' · ' + t('mfd.aaRef', {v: aaText(aa)}) : '');
    return `<span class="lad-n ${keyCls(l)}" data-effort="${esc(l)}" title="${esc(tip)}"><b class="lad-a">${a}</b><b class="lad-c">${esc(c)}</b></span>`;
  }).join('')}</div>`;
  // polish A: on a short screen the chart is left out instead of being clipped (the bars and the keys still compare).
  // CKP-MFD-54: a model with a single effort has nothing to chart: "only one effort".
  const chart = levels.length < 2 ? `<p class="cmp-single">${esc(t('mfd.cmpSingle'))}</p>` : size.h >= 34 && size.w >= 160 ? lineSvg(m, s, cols, size, ui) : '';
  return `<div class="cmp-h"><b class="mfd-title">${esc(title)}</b>${note ? `<span class="cmp-note">${note}</span>` : ''}${use ? `<span class="cmp-use">${esc(use)}</span>` : ''}</div>
    <div class="cmp-bars-row" data-trying="${s.trying}">${barsSvg(m, s, cols, size.w, ui)}</div><div class="mfd-fill" data-fill="cmp">${chart}</div><div class="cmp-keys" style="--cl:${L}px;--cr:${size.w - E}px">${ladder}${nums}<div class="cmp-foot">${links}${hint}${hintMark}</div></div>`;
}
const pctOrDash = v => v == null ? '—' : pctText(v);
const aaText = v => Number.isInteger(v) ? String(v) : v.toFixed(1);
// u7 = {tokens, share (0-1), cost? (an already formatted ≈ amount)}; nothing when the model has no 7-day use.
function useText(u) {
  if (!u || !numeric(u.tokens) || !(u.tokens > 0) || !numeric(u.share)) return '';
  const p = Math.max(u.share > 0 ? 1 : 0, Math.round(u.share * 100));
  return typeof u.cost === 'string' && u.cost ? t('mfd.cmpUseCost', {t: tokShort(u.tokens), c: u.cost, p}) : t('mfd.cmpUse', {t: tokShort(u.tokens), p});
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

const textW = s => [...String(s)].reduce((w, ch) => w + (/[　-鿿＀-￯]/.test(ch) ? 10 : 5.6), 0);

export const compareView = {render: comparison, keys: compareKeys, pageless: true, ownTitle: true, onClick: cmpClick};
