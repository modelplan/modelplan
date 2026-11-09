// SPDX-License-Identifier: MIT
// Ported from the opus-r7 study (rocket-r1/mfd-pages/views.js, round D1): the comparison view a fader trial opens
// (spec 6.4). Only the comparison is ported; the alert list and the session view live in prototype-deck.ts.
// Pure view: current / try / ★ columns, ability / cost / time rows, the ratio chart and the effort ladder; its own
// bottom keys (‹ back, ⚡ fast). Nothing is applied to a session.
import {websiteWords,modelUrl,methodologyUrl,secondaryLink} from './public-helpers.js';
import {t} from '../i18n.js';
import '../strings/review49.js';
import {esc, sign, times, fill, bolt} from './fmt.js';
import {modelOf, rowOf, currentOf} from './scope.js';

const POOL_TOOL = {codex: 'Codex', claude: 'Claude Code'};

/* ---------- comparison view (spec 6.4; round D1, owner 2026-10-23) ---------- */
// args {modelId, current, trial, fast, currentFast}. Fixed current / trial / ★
// slots; static backlights and equality tags identify matching configurations. Rows compare
// against current; unreported current never falls back to ★. Chart ratios use the same current configuration. Effort keys set the trial.
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
  return {m, cur, base, tier, curFast, trialFast, trial};
}
const numeric = v => typeof v === 'number' && Number.isFinite(v);
const ratio = (value, reference) => numeric(value) && numeric(reference) && reference > 0 ? value / reference : null;
const colOf = (m, tier, label, fast) => { const r = rowOf(m, label), f = !!(fast && tier); return {label, r, fast: f, cost: numeric(r[2]) && (!f || numeric(tier.cost)) ? r[2] * (f ? tier.cost : 1) : null,
  time: r[3] == null || (f && tier.taskTimeUnknown) ? null : r[3] / (f ? tier.speed : 1)}; };

// A10: one current reference for the table and chart, including fast cost/time.
// The table keeps ability Δ; the chart uses 1 + Δ/current on its ratio axis.
function comparisonValues(c, current) {
  return {abilityDelta: current && numeric(c.r[1]) && numeric(current.r[1]) ? c.r[1] - current.r[1] : null,
    ratios: [c.r[1], c.cost, c.time].map((v, i) => current ? ratio(v, [current.r[1], current.cost, current.time][i]) : null)};
}

export function comparison(d, ui, args) {
  const s = cmpState(d, ui, args);
  if (!s) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const {m, cur, base, tier, trial} = s;
  const C = colOf(m, tier, base, s.curFast), T = colOf(m, tier, trial, s.trialFast), R = colOf(m, tier, m.rec, false);
  // Equality includes fast mode. Roles always retain their own fixed slot.
  const equal = (a, b) => a.label === b.label && a.fast === b.fast;
  const tc = !!cur && equal(T, C), tr = equal(T, R), cr = !!cur && equal(C, R);
  const columns = [
    {c: C, role: t('mfd.cCur'), id: 'current', cls: `now cmp-panel`, light: !cur ? 'dim' : cr ? 'gold' : 'white', known: !!cur, tag: cr ? '= ★' : ''},
    {c: T, role: t('mfd.cTrial'), id: 'trial', cls: 'blue cmp-panel', light: tc ? 'off' : tr ? 'gold' : 'blue', known: true, unlit: tc,
      tag: tc ? t('mfd.equalCurrent') : tr ? '= ★' : ''},
    {c: R, role: t('mfd.cRec'), id: 'rec', cls: 'gold cmp-panel', light: 'gold', known: true, tag: ''},
  ];
  for (const col of columns) col.values = comparisonValues(col.c, cur ? C : null);
  const cells = f => columns.map(({values, id, cls, light, known, unlit}) => `<td data-role="${id}" data-light="${light}" class="${cls}"><span class="cmp-value"${unlit ? ' aria-hidden="true"' : ''}>${known ? f(values) : '--'}</span></td>`).join('');
  const rows = [
    [t('mfd.rAbility'), v => v.abilityDelta == null ? '—' : sign(v.abilityDelta)],
    [t('mfd.rCost'), v => times(v.ratios[1])],
    [t('mfd.rTime'), v => times(v.ratios[2])],
  ];
  // Fixed role slots; the chart uses these same configurations and CURRENT reference.
  const head = `<tr><th></th>${columns.map(({c, role, id, cls, light, known, tag, unlit}) => `<th scope="col" data-role="${id}" data-light="${light}" class="${cls}"><span class="cmp-role">${esc(role)}</span>${tag ? `<small class="cmp-equal">${esc(tag).replaceAll('★','<span class="cmp-equal-star">★</span>')}</small>` : ''}<b${unlit ? ' aria-hidden="true"' : ''}>${known ? esc(c.label) : '--'}${known && c.fast ? ` ${bolt(t('mfd.fastRow'))}` : ''}</b></th>`).join('')}</tr>`;
  const table = `<table class="cmp" aria-label="${esc(t('mfd.cmpAria', {m: m.short}))}"><colgroup><col class="cmp-label"><col span="3"></colgroup><thead>${head}</thead><tbody>${rows.map(([l, f]) => `<tr><td>${l}</td>${cells(f)}</tr>`).join('')}</tbody></table>`;
  const fastShown = !!tier && (C.fast || T.fast);
  const note = [!cur ? `<em>${t('mfd.currentUnknown')}</em>` : '', fastShown ? `<em role="img" aria-label="${esc(t('mfd.fastLine', {s: tier.speed, c: tier.cost}))}">${bolt()}</em>` : ''].filter(Boolean).join('');
  const words=websiteWords(ui.lang),size=fill(ui,'cmp',{w:300,h:60}),title=t('mfd.cmpTitle',{m:m.short});
  const howFits=textW(title)*1.2+textW(words.compare+' ↗')+textW(words.how+' ↗')+36<=size.w;
  const links=`<span class="cmp-header-links">${secondaryLink(modelUrl(m.id),words.compare)}${howFits?secondaryLink(methodologyUrl('cost-basis'),words.how):''}</span>`;
  const g = ladderGeom(ui), levels = m.e.map(r => r[0]);
  const ladder = `<div class="cmp-lad" style="--cl:${g.L}px;--cr:${g.R}px">${levels.map(l => `<button class="lad ${l === base && cur ? 'cur' : ''} ${l === trial && (trial !== base || T.fast !== C.fast) ? 'try' : ''} ${l === m.rec ? 'rec' : ''}" data-mfd="try:${l}" aria-label="${esc(t('mfd.ladderAria', {e: l}))}">${l === m.rec ? '★' : ''}${l}</button>`).join('')}</div>`;
  return `<div class="cmp-h"><b class="mfd-title">${esc(title)}</b>${note ? `<span class="cmp-note">${note}</span>` : ''}${links}</div>
    ${table}<div class="mfd-fill" data-fill="cmp">${chartIfRoom(m, columns, tier, s.trialFast, size)}</div>${ladder}`;
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

// Retain the existing effort-key row's geometry as the comparison content changes.
const textW = s => [...s].reduce((w, ch) => w + (/[　-鿿＀-￯]/.test(ch) ? 10 : 5.6), 0);
const LINES = [['abl', 'mfd.rAbility'], ['cost', 'mfd.rCost'], ['time', 'mfd.rTime']];
const ladderGeom = () => ({L: 36, R: Math.ceil(Math.max(...LINES.map(([, k]) => textW(t(k))))) + 10});
// Task 85 review: symmetric ratio spacing around ×1, fixed across both speed ladders.
const plottable = v => Number.isFinite(v) && v > 0;
function ratioDomain(values) {
  const powers = [0, ...values.filter(plottable).map(Math.log2)];
  let min = Math.floor(Math.min(...powers)), max = Math.ceil(Math.max(...powers));
  if (min === max) { min--; max++; }
  return {min, max, ticks: Array.from({length:max-min+1}, (_,i) => 2 ** (min+i))};
}
const ratioText = v => '×' + (v >= .25 ? String(v) : '1/' + (1/v));
// Three metric names remain readable in the 34 px minimum slot. Short leaders keep
// each name attached to its actual endpoint when neighbouring ratios coincide.
function endLabelPositions(ends, height) {
  const sorted = ends.filter(Boolean).sort((a,b) => a.y-b.y || a.metric-b.metric);
  const gap = height < 44 ? 11 : 13, low = 6, high = height-6;
  sorted.forEach((p,i) => {p.labelY=Math.max(low,p.y,i ? sorted[i-1].labelY+gap : low);});
  for(let i=sorted.length-1;i>=0;i--)sorted[i].labelY=Math.min(sorted[i].labelY,i===sorted.length-1 ? high : sorted[i+1].labelY-gap);
  return ends;
}
// polish A: on a short screen the chart's area can be too small to read; it is left out then instead of being clipped
// (the table and the ladder carry the comparison).
const chartIfRoom = (m, cols, tier, fast, size) => size.h >= 34 && size.w >= 160 ? configurationChart(m, cols, tier, fast, size) : '';
// Task 85: one metric trace across ALL published efforts, relative to CURRENT (A10).
// Standard traces always stay in place. The fixed domain also includes every Fast effort.
// Fast cost/time overlays appear when either actual/trial configuration is Fast (A10).
function configurationChart(m, columns, tier, fast, {w: W, h: H}) {
  const {L, R} = ladderGeom(), top = 6, bottom = 8, end = W - R;
  const efforts = m.e.map(r => r[0]), current = columns[0].known ? columns[0].c : null;
  const rows = efforts.map(l => comparisonValues(colOf(m, tier, l, false), current).ratios);
  const fastRows = tier ? efforts.map(l => comparisonValues(colOf(m, tier, l, true), current).ratios) : [];
  const showFast=!!tier&&(fast||current?.fast);
  const configs = [];
  for (const {c, id, known, unlit, values} of columns) {
    if (!known || unlit || values.ratios.every(v => v == null)) continue;
    const same = configs.find(x => x.c.label === c.label && x.c.fast === c.fast);
    if (same) same.roles.push(id);
    else configs.push({c, roles: [id], values: values.ratios});
  }
  const available = [...rows,...fastRows].some(r => r.some(plottable));
  const description = t(!current ? 'mfd.cmpChartUnknownAria' : available ? 'mfd.cmpChartAria' : 'mfd.cmpChartUnavailableAria', {m: m.short, efforts: efforts.join(' → ')});
  if (!available) return `<svg class="cmp-chart" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(description)}"></svg>`;
  // Current/★ points can be off the Fast trace. Their values are fixed, never trial-dependent.
  const dom = ratioDomain([...rows.flat(),...fastRows.flat(), ...columns.filter(c => c.id !== 'trial' && c.known).flatMap(c => c.values.ratios)]), plotH = H - top - bottom;
  const X = i => L + (i + .5) * (end - L) / efforts.length, Y = v => top + (dom.max - Math.log2(v)) / (dom.max - dom.min) * plotH;
  const tickLabels = [1];
  for(const v of [dom.ticks[0],dom.ticks.at(-1),...dom.ticks]) {
    if (!tickLabels.includes(v) && textW(ratioText(v)) <= L-4 && tickLabels.every(u => Math.abs(Y(v)-Y(u)) >= 11)) tickLabels.push(v);
  }
  const grid = dom.ticks.map(v => `<line class="cl-grid ${v === 1 ? 'unit' : ''}" data-v="${v}" x1="${L}" x2="${end}" y1="${Y(v)}" y2="${Y(v)}"/>${tickLabels.includes(v) ? `<text class="cl-tick" x="${L-4}" y="${Math.max(10,Math.min(H-3,Y(v)+3.5))}" text-anchor="end">${ratioText(v)}</text>` : ''}`).join('');
  const ends=endLabelPositions(LINES.map(([,name],metric)=>{
    const index=rows.findLastIndex(r=>plottable(r[metric]));
    return index<0 ? null : {metric,name,index,y:Y(rows[index][metric])};
  }),H);
  const trace=(key,name,metric,values,isFast=false)=>{
    const segments = [];
    values.forEach((v, i) => {if (!plottable(v)) return; if (!segments.length || !plottable(values[i-1])) segments.push([]); segments.at(-1).push(i);});
    const paths = segments.filter(s => s.length > 1).map(s => `<polyline points="${s.map(i=>`${X(i)},${Y(values[i])}`).join(' ')}"/>`).join('');
    const points = values.map((v, i) => !plottable(v) ? '' : `<circle class="cl-point" data-effort="${esc(efforts[i])}" data-v="${v}" cx="${X(i)}" cy="${Y(v)}" r="1.2"/>`).join('');
    const label=ends[metric], labelY=label?.labelY;
    const glyph=showFast&&metric>0?`<g class="cl-fast-legend" transform="translate(${end+2} ${labelY-5})" role="img" aria-label="${esc(t('mfd.fastRow'))}"><path fill="currentColor" d="M3.9 0 .3 5.1h2.4L2 9l3.7-5.4H3.3z"/></g>`:'';
    const legend = !isFast && label ? `<path class="cl-end-leader" d="M${X(label.index)+2} ${label.y}H${end-2}L${end+8} ${labelY}"/>${glyph}<text class="cl-name" data-endpoint="${esc(efforts[label.index])}" x="${end+12}" y="${labelY+3}">${esc(t(name))}</text>` : '';
    return `<g class="cl cl-${key}${isFast?' cl-fast':''}" data-series="${key}" data-mode="${isFast?'fast':'standard'}">${paths}${points}${legend}</g>`;
  };
  const traces=LINES.map(([key,name],metric)=>trace(key,name,metric,rows.map(r=>r[metric]))).join('')+(showFast?LINES.slice(1).map(([key,name],i)=>trace(key,name,i+1,fastRows.map(r=>r[i+1]),true)).join(''):'');
  const markers = configs.map(({c, roles, values}) => {
    const x = X(efforts.indexOf(c.label));
    const ink = roles.includes('current') ? 'current' : roles.includes('rec') ? 'rec' : 'trial';
    const marks = roles.slice().sort((a,b)=>['rec','current','trial'].indexOf(a)-['rec','current','trial'].indexOf(b)).map(role => `<line class="cfg-rule cfg-${role}" x1="${x}" x2="${x}" y1="${top}" y2="${H-bottom}"/>`+(c.fast?`<g class="cfg-fast cfg-${role}" transform="translate(${x-3} 0)" aria-label="${esc(t('mfd.fastRow'))}"><path d="M3.9 0 .3 5.1h2.4L2 9l3.7-5.4H3.3z"/></g>`:'')+values.map((v, i) => !plottable(v) ? '' : `<circle class="cfg-mark cfg-${role}" data-metric="${LINES[i][0]}" cx="${x}" cy="${Y(v)}" r="${{current:2,rec:3.3,trial:4.6}[role]}"/>`).join('')).join('');
    return `<g class="cfg cfg-${ink}" data-config="${esc(c.label)}:${c.fast?'fast':'normal'}" data-roles="${roles.join(' ')}">${marks}</g>`;
  }).join('');
  return `<svg class="cmp-chart" data-scale="log2" data-compact="${H<44}" data-efforts="${esc(efforts.join('|'))}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(description)}">${grid}${traces}${markers}</svg>`;
}

export const compareView = {render: comparison, keys: compareKeys, pageless: true, ownTitle: true, onClick: cmpClick};
