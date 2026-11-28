// 总览 (V1-FINAL §8.1, r5-1 option A): three layers from top to bottom. 1 the alert rows (tightest first, four lines at
// most, "+N ▸" for the rest); 2 the totals row (the range's ≈cost large, its tokens beside it, ≈cost per day on the right,
// "since MM-DD" instead of the range when the record is shorter); 3 one bar per day (per hour for Today), stacked in the
// subscription colours, its height the day's ≈cost from zero. No price data means no bars: there is no token fallback.
// The Grid key switches layer 3 to the day-by-hour heatmap (D390). Pure view (spec 2.6).
import {t} from '../i18n.js';
import {chartPalette} from '../chart-colours.js';
import {esc, tok, unit, md, mon, tip, fill} from './fmt.js';
import {accountsIn, rangeKey} from './scope.js';
import {statusItems,statusRow} from './public-helpers.js';
import {bullet} from './alerts.js';

// The same local wall time `back` calendar days earlier: a day across a DST change is 23 or 25 hours, so fixed 24-hour
// steps would date a bucket a day off (audit F 6). The series are indexed by local calendar day (prototype-history.ts).
const daysBefore = (ms, back) => { const x = new Date(ms); return new Date(x.getFullYear(), x.getMonth(), x.getDate() - back, x.getHours(), x.getMinutes(), x.getSeconds(), x.getMilliseconds()).getTime(); };

export function alertList(d, {max = 4} = {}) {
  let a = statusItems(d.alerts);
  // Three or more subscriptions that cannot be read merge into one grey line (V1-FINAL §8.1). A retained (stale) reading is
  // not unreadable: it keeps its own line with the reading's age.
  const grey = a.filter(x => x.level === 'grey' && x.kind === 'unreadable');
  if (grey.length >= 3) a = [...a.filter(x => !grey.includes(x)), {level: 'grey', kind: 'unreadable', text: t('mfd.ovUnreadN', {n: grey.length})}];
  if (!a.length) return '';
  const shown = a.length > max ? a.slice(0, max - 1) : a;
  return `<ul class="mfd-alerts">${shown.map(x => statusRow(x)||`<li class="al-${x.level}"${x.news ? ` data-news="${esc(x.news)}"` : ''} data-tip="${esc(x.text)}">${bullet(x)}<span>${esc(x.text)}</span></li>`).join('')}${
    a.length > shown.length ? `<li class="al-more"><button data-mfd="alerts">${t('mfd.moreAlerts', {n: a.length - shown.length})}</button></li>` : ''}</ul>`;
}

const series = (d, ui) => accountsIn(d, ui).map(a => ({a, daily: d.daily.find(x => x.accountId === a.id)})).filter(x => x.daily);
// The ≈cost series of the selected subscriptions, in the same shape as the token series (the values are US dollars).
const costSeries = (d, ui) => accountsIn(d, ui).map(a => ({a, daily: d.cost?.daily.find(x => x.accountId === a.id)})).filter(x => x.daily);

// §0: "≈$64". Below $100 two significant digits, from $100 whole dollars, from $1000 "≈$1.2k". The same in both languages.
export function usd(v) {
  if (!Number.isFinite(v) || v < 0) return '--';
  if (v === 0) return '≈$0';
  if (v < .01) return '<$0.01';
  if (v < 100) return `≈$${Number(v.toPrecision(2))}`;
  if (v < 999.5) return `≈$${Math.round(v)}`;
  const k = v / 1000;
  return k < 999.5 ? `≈$${Number(k.toPrecision(k < 100 ? 2 : 3))}k` : `≈$${Number((k / 1000).toPrecision(2))}M`;
}
const startOfDay = ms => { const x = new Date(ms); return new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime(); };
const mmdd = ms => { const x = new Date(ms); return `${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`; };
const sums = (costs, n) => {
  let recorded = false, usdSum = 0, priced = 0, unpriced = 0;
  for (const {daily} of costs) daily.values.slice(-n).forEach((v, i, all) => {
    const at = daily.values.length - all.length + i;
    if (v != null) { recorded = true; usdSum += v; }
    priced += daily.priced?.[at] ?? (v > 0 ? 1 : 0); unpriced += daily.unpriced?.[at] ?? 0;
  });
  return {recorded, usd: priced > 0 ? usdSum : null, tokens: priced + unpriced, unpricedShare: priced + unpriced > 0 ? unpriced / (priced + unpriced) : null};
};
// The range's cost figures for the selected subscriptions. Today is the local calendar day's daily bucket, not the last
// 24 hourly ones (a producer may have day-only cost); a range without priced usage has no cost at all.
const rangeCost = (costs, ui) => costs.length ? sums(costs, ui.days === 24 ? 1 : ui.days) : null;

// The totals row. Today's tokens are known only when every selected subscription has a reading; an unknown one is not a
// zero, and an unknown total is left out rather than written "--".
function totals(d, ui, list, costs) {
  const todays = accountsIn(d, ui).map(a => a.todayTokens), todayTokens = todays.length && todays.every(Number.isFinite) ? todays.reduce((s, v) => s + v, 0) : null;
  // Without any daily record only Today's reading exists: the row then says Today, whatever the range key shows.
  const n = ui.days, today = n === 24 || !list.length;
  const c = rangeCost(costs, {days: today ? 24 : n});
  // With a cost section the tokens are the ones the cost counts (priced or not, input and output); else the output tokens.
  const tokens = c?.recorded ? c.tokens : today ? todayTokens : list.length ? list.reduce((s, x) => s + x.daily.values.slice(-n).reduce((p, v) => p + (v || 0), 0), 0) : null;
  const money = c?.usd ?? null;
  const since = !today && d.recordStart != null && d.recordStart > daysBefore(startOfDay(d.now), n - 1) ? d.recordStart : null;
  const covered = since == null ? n : Math.max(1, Math.round((startOfDay(d.now) - since) / 864e5) + 1);
  if (money == null && tokens == null) return '';
  const label = since != null ? t('mfd.ovSince', {d: mmdd(since)}) : t(today ? 'mfd.ovToday' : n === 7 ? 'mfd.ov7d' : 'mfd.ov30d');
  return `<div class="ov-top"><span class="lbl">${esc(label)}</span><b class="ov-total">${esc(money != null ? usd(money) : tok(tokens))}</b>${money != null && tokens != null ? `<span class="ov-tok">${tok(tokens)}</span>` : ''}<span class="sp"></span>${
    money != null && !today ? `<span class="ov-per">${t('mfd.ovPerDay', {c: usd(money / covered)})}</span>` : ''}</div>`;
}

// Equal width buckets, no interpolation. `list` holds ≈cost series (US dollars per day, or per hour for Today); a null day
// has no record and draws nothing, a recorded zero draws the 3 px base. Gaps consume display pixels, never data height.
export function overviewBars(d,ui,list){
 const {w:W,h:H}=fill(ui,'ov',{w:260,h:110}),hourly=ui.days===24,instants=d.cost?.hourly?.[0]?.instants,n=hourly?(instants?.length||24):ui.days;
 const palette=chartPalette(d.accounts.filter(a=>list.some(x=>x.a.id===a.id))),byId=new Map(palette.map(x=>[x.id,x]));
 const ser=list.map(x=>({a:x.a,fill:byId.get(x.a.id).fill,v:hourly?(d.cost?.hourly?.find(h=>h.accountId===x.a.id)?.values||Array(24).fill(null)).map((v,i)=>instants?.[i]!=null&&instants[i]<startOfDay(d.now)?null:v):x.daily.values.slice(-n)}));
 const total=Array.from({length:n},(_,i)=>ser.reduce((s,x)=>s+(x.v[i]||0),0));
 const max=Math.max(...(ui.stack?total:ser.flatMap(x=>x.v.map(v=>v||0))),0),top=12,base=Math.max(top+12,H-15);
 const pitch=W/n,bw=Math.max(.5,pitch-2),height=base-top;
 // The 2 px gaps between layers belong to each day's own stack. The scale makes the tallest stack, gaps included, over all days
 // exactly as high as the dashed line.
 let scale=0;
 if(max>0){const fits=total.map((v,i)=>v>0?(height-(ui.stack?Math.max(0,ser.filter(x=>(x.v[i]||0)>0).length-1)*2:0))/v:Infinity);scale=ui.stack?Math.min(...fits):height/max;}
 let body='';
 for(let i=0;i<n;i++){
  const at=instants?.[i], stamp=hourly?(at!=null?new Date(at).toLocaleTimeString(ui.lang,{hour:'2-digit',minute:'2-digit',hour12:false,timeZoneName:'shortOffset'}):`${String(i).padStart(2,'0')}:00`):md(daysBefore(d.now,n-1-i),ui);
  const per=ser.filter(x=>x.v[i]!=null),lines=[`${stamp} · ${per.length?usd(total[i]):t('mfd.noRecord')}`,...per.map(x=>`${x.a.short} ${usd(x.v[i])}`)];
  let y=base;
  const active=ser.filter(x=>(x.v[i]||0)>0),last=active.at(-1);
  const rects=ser.map((x,j)=>{const value=x.v[i];if(!(value>0))return '';const bh=value*scale;
   const xx=ui.stack?i*pitch+1:i*pitch+1+j*bw/Math.max(1,ser.length),ww=ui.stack?bw:Math.max(.2,bw/Math.max(1,ser.length)-.5);
   const yy=ui.stack?y-bh:base-value*scale; if(ui.stack)y=yy-2;
   const h=ui.stack?bh:value*scale,rad=ui.stack&&x!==last?0:Math.min(1.5,h/2,ww/2);
   // Only top corners are rounded. Small values retain their true height.
   const path=`M${xx},${yy+h}V${yy+rad}Q${xx},${yy} ${xx+rad},${yy}H${xx+ww-rad}Q${xx+ww},${yy} ${xx+ww},${yy+rad}V${yy+h}Z`;
   return `<path class="ov-bar" data-sub="${esc(x.a.id)}" data-value="${value}" d="${path}" fill="${x.fill}"/>`;
  }).join('');
  // A recorded day that cost nothing keeps a 3 px base; a day before the record has nothing.
  const stub=per.length&&!active.length?`<rect class="ov-stub" x="${i*pitch+1}" y="${base-3}" width="${bw}" height="3"/>`:'';
  body+=`<g class="ov-bucket${i===n-1?' ov-last':''}" data-hour="${hourly?i:''}" data-total="${total[i]}" data-tip="${tip(lines)}"><rect class="ov-hit" x="${i*pitch}" y="0" width="${pitch}" height="${base}"/>${rects}${stub}</g>`;
 }
 // The two ends, and the middle only at 30 days; the one dashed line carries the highest value (no other scale).
 const ticks=hourly?[[0,'0'],[n-1,`${n}h`]]:n>=30?[[0,`−${n-1}d`],[Math.floor(n/2),`−${n-1-Math.floor(n/2)}d`],[n-1,t('mfd.todayAxis')]]:[[0,`−${n-1}d`],[n-1,t('mfd.todayAxis')]];
 return `<svg class="ov-chart" data-mode="${ui.stack?'stack':'split'}" data-buckets="${n}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t(hourly?'mfd.ovHourAria':'mfd.ovChartAria',{d:n})}">
 ${max>0?`<path class="ov-grid" d="M0 ${top}H${W}"/><text class="ov-max" x="${W}" y="${top-3}" text-anchor="end">${esc(usd(max))}</text>`:''}<path class="ov-base" d="M0 ${base+.5}H${W}"/>${body}${ticks.map(([i,label])=>`<text class="ov-ax" x="${i===0?0:i===n-1?W:(i+.5)*pitch}" y="${H-2}" text-anchor="${i===0?'start':i===n-1?'end':'middle'}">${esc(label)}</text>`).join('')}</svg>`;
}
const importNote=(imp,v)=>imp>0&&imp<v?` · ${t('mfd.importedPart',{v:tok(imp)})}`:imp>0&&imp>=v?` · ${t('mfd.importedDay')}`:'';

/* 点阵 (D390): the current range as a day-by-hour grid. Columns are the days of the range, rows are six four-hour bands
   (Today: one row of 24 hours). Only hours the hourly series records have a cell; the wire keeps hourly rows for 30 days (D402),
   so 7天 and 30天 fill, and a range without any hourly record says so. Neutral LCD ink in 全部, the vendor
   colour in a subscription scope. Hover: the day, the hours and the tokens per subscription. */
const BAND = 4;
const hourlySeries = (d, ui) => accountsIn(d, ui).map(a => ({a, h: (d.hourlyLong || d.hourly || []).find(x => x.accountId === a.id)})).filter(x => x.h).map(x => ({a: x.a, instants: x.h.instants, values: x.h.values}));
export function heatCells(d, ui, list = hourlySeries(d, ui)) {
  const today = ui.days === 24, cols = today ? 24 : ui.days, rows = today ? 1 : 24 / BAND, t0 = startOfDay(d.now);
  const days = Array.from({length: cols}, (_, k) => today ? t0 : daysBefore(t0, cols - 1 - k));
  const cells = [];
  for (let col = 0; col < cols; col++) for (let row = 0; row < rows; row++) cells.push({col, row, at: days[col], from: today ? col : row * BAND, to: today ? col + 1 : (row + 1) * BAND, recorded: false, total: 0, per: []});
  const at = (day, hour) => cells[today ? hour : days.indexOf(day) * rows + Math.floor(hour / BAND)];
  for (const s of list) s.instants.forEach((ms, i) => {
    const v = s.values[i]; if (v == null || ms > d.now) return;
    const x = new Date(ms), day = startOfDay(ms);
    if (today ? day !== t0 : !days.includes(day)) return;
    const c = at(day, x.getHours()); if (!c) return;
    c.recorded = true; c.total += v;
    const p = c.per.find(q => q.a.id === s.a.id) || (c.per.push({a: s.a, v: 0}), c.per.at(-1)); p.v += v;
  });
  // Four linear steps of the busiest cell (the busiest is always the darkest); a recorded zero is step 0.
  const max = Math.max(0, ...cells.filter(c => c.recorded).map(c => c.total));
  for (const c of cells) c.step = !c.recorded ? null : c.total <= 0 ? 0 : Math.min(4, Math.ceil(c.total / max * 4));
  return {cells, cols, rows, today, days, any: cells.some(c => c.recorded)};
}
const p2 = n => String(n).padStart(2, '0');
function heatmap(d, ui) {
  const {w: AW, h: AH} = fill(ui, 'ov', {w: 300, h: 110}), g = heatCells(d, ui);
  if (!g.any) return `<p class="ov-heat-empty">${t('mfd.heatNoHours')}</p>`;
  const gap = 2, top = 12, lab = g.today ? 0 : 16, note = 0;
  const cw = Math.max(4, Math.min(g.today ? 18 : 28, Math.floor((AW - lab + gap) / g.cols - gap))), ch = Math.max(6, Math.min(g.today ? 24 : 20, Math.floor((AH - top - note + gap) / g.rows - gap)));
  const W = lab + g.cols * (cw + gap) - gap, H = top + g.rows * (ch + gap) - gap, x0 = Math.max(0, Math.floor((AW - W) / 2)), y0 = Math.max(0, Math.floor((AH - note - H) / 2));
  const colour = ui.scope ? accountsIn(d, ui)[0]?.colour : null, nowHour = new Date(d.now).getHours();
  const rects = g.cells.map(x => {
    if (x.step == null) return '';
    const day = md(g.days[x.col], ui), hours = g.today ? `${p2(x.from)}:00` : `${p2(x.from)}:00-${p2(x.to)}:00`;
    return `<rect class="hm s${x.step} ${x.col === g.cols - 1 && x.from <= nowHour && nowHour < x.to ? 'today' : ''}" x="${lab + x.col * (cw + gap)}" y="${top + x.row * (ch + gap)}" width="${cw}" height="${ch}" rx="1.2" data-tip="${tip([`${day} ${hours}`, ...x.per.map(p => `${p.a.short} ${tok(p.v)}`)])}"/>`;
  }).join('');
  const label = (i, anchor) => `<text class="hm-m" x="${lab + i * (cw + gap) + (anchor === 'end' ? cw : 0)}" y="9" text-anchor="${anchor}">${esc(g.today ? `${p2(i)}h` : md(g.days[i], ui))}</text>`;
  const marks = g.today ? [0, 6, 12, 18].map(i => label(i, 'start')) : g.cols > 1 ? [label(0, 'start'), label(g.cols - 1, 'end')] : [label(0, 'start')];
  const bands = g.today ? '' : Array.from({length: g.rows}, (_, r) => `<text class="hm-m" x="0" y="${top + r * (ch + gap) + ch / 2 + 3}">${p2(r * BAND)}</text>`).join('');
  return `<svg class="ov-heat ${colour ? 'vendor' : ''}" style="left:${x0}px;top:${y0}px;${colour ? `--hv:${colour}` : ''}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t(g.today ? 'mfd.heatAriaToday' : 'mfd.heatAria', {d: g.cols})}">${marks.join('')}${bands}${rects}</svg>`;
}


export const overview = {
  id: 'overview', title: 'mfd.pOverview',
  optionKeys: ui => [
    // CKP-MFD-62 (D390): the key switches between the bars and the day-by-hour heatmap; its hint follows the mode (G3-172:
    // the lit side always names what is drawn).
    {id: 'chart', hint: t(ui.chart === 'grid' ? 'mfd.oGridHint' : 'mfd.oBarsHint'), a: {value:'bars', text: t('mfd.oBars'), on: ui.chart !== 'grid'}, b: {value:'grid', text: t('mfd.oGrid'), on: ui.chart === 'grid'}},
    // CKP-SHELL-50: the app's range; Today is the 24-hour chart (ui.days follows the range in the deck).
    rangeKey(ui),
    // Stack / split shapes the bars only; the heatmap has no layers to split.
    ui.chart === 'grid' ? null : {id:'stack',a:{value:'stack', text:t('mfd.oStack'),on:ui.stack},b:{value:'split', text:t('mfd.oSplit'),on:!ui.stack}},
    null],
  render(d, ui) {
    // The taller screen shows four alert lines, the short one only the tightest plus "+N ▸" (V1-FINAL §13); the chart
    // takes the rest of the height (data-fill), so the page always fills the screen.
    const h = fill(ui, 'page', {w: 330, h: 190}).h - 12, max = h >= 165 ? 4 : 2;
    const alerts = alertList(d, {max}), accounts = accountsIn(d, ui);
    const list = series(d, ui), costs = costSeries(d, ui);
    const todays = accounts.map(a => a.todayTokens), todayKnown = todays.length > 0 && todays.every(Number.isFinite);
    // First read: nothing recorded, no reading yet. A placeholder block stands where the totals will be.
    if (accounts.length && accounts.every(a => a.state === 'loading') && !list.length && !todayKnown)
      return `${alerts}<div class="ov-top ov-skel" aria-busy="true"><i></i></div>`;
    // No usage record: the alert rows stay, and three lines say why the rest is empty.
    // D390 (macrevb-1212-2): the lit Grid key says its own hourly empty state, never the Bars message about future daily bars.
    if (!list.length && !todayKnown && ui.chart === 'grid')
      return `${alerts}<div class="mfd-fill" data-fill="ov">${heatmap(d, ui)}</div>`;
    if (!list.length && !todayKnown)
      return `${alerts}<div class="mp-empty ov-empty"><b>${t('mfd.ovNoRecord1')}</b><span>${t('mfd.ovNoRecord2')}</span><span>${t('mfd.ovNoRecord3')}</span></div>`;
    const row = totals(d, ui, list, costs);
    // Bars exist only with ≈cost for the selected subscriptions and range. The line under them says how much of that use had
    // no public price and so is not counted.
    const c = rangeCost(costs, ui), share = c?.unpricedShare;
    const instants = d.cost?.hourly?.[0]?.instants, ids = new Set(costs.map(x => x.a.id));
    const bars = c?.usd != null && (ui.days !== 24 || (d.cost.hourly || []).some(h => ids.has(h.accountId) && h.values.some((v, i) => v != null && !(instants?.[i] < startOfDay(d.now)))));
    const chart = (ui.chart === 'grid' ? `<div class="mfd-fill" data-fill="ov">${heatmap(d, ui)}</div>` : bars ? `<div class="mfd-fill" data-fill="ov">${overviewBars(d, ui, costs)}</div>` : '')
      + (share > 0 ? `<p class="ov-note">${t('mfd.ovUnpriced', {p: share < .01 ? '<1' : Math.round(share * 100)})}</p>` : '');
    return `${alerts}${row}${chart}`;
  },
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'chart') return {patch: {mfdChart: ui.optionChoice != null ? (ui.optionChoice === 'grid' ? 'grid' : 'bars') : ui.chart === 'grid' ? 'bars' : 'grid'}};
    if (act === 'opt' && val === 'range') return {range: ui.optionChoice};
    if (act === 'opt' && val === 'stack') return {patch: {mfdStack: ui.optionChoice != null ? ui.optionChoice === 'stack' : !ui.stack}};
    if (act === 'alerts') return {open: ['alerts', {from: 'mfd', key: 'alerts'}]};
    return null;
  },
};
