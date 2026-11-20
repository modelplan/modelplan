// 总览 (V1-FINAL §8.1, r5-1 option A): three layers from top to bottom. 1 the alert rows (tightest first, four lines at
// most, "+N ▸" for the rest); 2 the totals row (the range's ≈cost large, its tokens beside it, ≈cost per day on the right,
// "since MM-DD" instead of the range when the record is shorter); 3 one bar per day (per hour for Today), stacked in the
// subscription colours, its height the day's ≈cost from zero. No price data means no bars: there is no token fallback.
// The 26-week heatmap code stays for v1.1; the Grid key is not lit in v1. Pure view (spec 2.6).
import {t} from '../i18n.js';
import {chartPalette} from '../chart-colours.js';
import {esc, tok, unit, md, mon, tip, fill} from './fmt.js';
import {accountsIn, rangeKey} from './scope.js';
import {statusItems,statusRow} from './public-helpers.js';

// The same local wall time `back` calendar days earlier: a day across a DST change is 23 or 25 hours, so fixed 24-hour
// steps would date a bucket a day off (audit F 6). The series are indexed by local calendar day (prototype-history.ts).
const daysBefore = (ms, back) => { const x = new Date(ms); return new Date(x.getFullYear(), x.getMonth(), x.getDate() - back, x.getHours(), x.getMinutes(), x.getSeconds(), x.getMilliseconds()).getTime(); };

export function alertList(d, {max = 4} = {}) {
  let a = statusItems(d.alerts);
  // Three or more subscriptions that cannot be read merge into one grey line (V1-FINAL §8.1).
  const grey = a.filter(x => x.level === 'grey');
  if (grey.length >= 3) a = [...a.filter(x => x.level !== 'grey'), {level: 'grey', text: t('mfd.ovUnreadN', {n: grey.length})}];
  if (!a.length) return '';
  const shown = a.length > max ? a.slice(0, max - 1) : a;
  return `<ul class="mfd-alerts">${shown.map(x => statusRow(x)||`<li class="al-${x.level}" data-tip="${esc(x.text)}"><i>●</i><span>${esc(x.text)}</span></li>`).join('')}${
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
const sumLast = (rows, n) => { let any = false, sum = 0; for (const r of rows) for (const v of r.slice(-n)) if (v != null) { any = true; sum += v; } return any ? sum : null; };

// The totals row. Today's tokens are known only when every selected subscription has a reading; an unknown one is not a
// zero, and an unknown total is left out rather than written "--".
function totals(d, ui, list, costs) {
  const todays = accountsIn(d, ui).map(a => a.todayTokens), todayTokens = todays.length && todays.every(Number.isFinite) ? todays.reduce((s, v) => s + v, 0) : null;
  // Without any daily record only Today's reading exists: the row then says Today, whatever the range key shows.
  const n = ui.days, today = n === 24 || !list.length;
  const tokens = today ? todayTokens : list.length ? list.reduce((s, x) => s + x.daily.values.slice(-n).reduce((p, v) => p + (v || 0), 0), 0) : null;
  const ids = new Set(costs.map(c => c.a.id));
  const money = !costs.length ? null : today ? sumLast((d.cost.hourly || []).filter(h => ids.has(h.accountId)).map(h => h.values), 24) : sumLast(costs.map(x => x.daily.values), n);
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
 const ser=list.map(x=>({a:x.a,fill:byId.get(x.a.id).fill,v:hourly?d.cost?.hourly?.find(h=>h.accountId===x.a.id)?.values||Array(24).fill(null):x.daily.values.slice(-n)}));
 const total=Array.from({length:n},(_,i)=>ser.reduce((s,x)=>s+(x.v[i]||0),0));
 const max=Math.max(...(ui.stack?total:ser.flatMap(x=>x.v.map(v=>v||0))),0),top=12,base=Math.max(top+12,H-15);
 const pitch=W/n,bw=Math.max(.5,pitch-2),height=base-top,gaps=ui.stack?Math.max(0,ser.length-1)*2:0,scale=max>0?(height-gaps)/max:0;
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

/* 点阵: 26 weeks × 7 days (Monday on top), five steps. Neutral LCD ink in 全部, the vendor colour in a subscription
   scope. Hover: the date and the tokens per subscription. Days before the record began have no cell. */
export function heatCells(d, ui, list) {
  const today = new Date(d.now), wdToday = (today.getDay() + 6) % 7, count = 25 * 7 + wdToday + 1;
  const len = Math.max(...list.map(x => x.daily.values.length)), first = daysBefore(d.now, count - 1);
  const cells = Array.from({length: count}, (_, k) => {
    const at = daysBefore(d.now, count - 1 - k), per = list.map(x => ({a: x.a, v: x.daily.values[x.daily.values.length - count + k] ?? null, i: (x.daily.imported || [])[x.daily.values.length - count + k] ?? 0}));
    const rec = per.filter(p => p.v != null);
    return {k, at, col: Math.floor(k / 7), row: k % 7, recorded: rec.length > 0, total: rec.reduce((s, p) => s + p.v, 0), imported: rec.reduce((s, p) => s + p.i, 0), per: rec};
  });
  const vals = cells.filter(c => c.recorded && c.total > 0).map(c => c.total).sort((a, b) => a - b);
  const q = p => vals.length ? vals[Math.min(vals.length - 1, Math.floor(p * vals.length))] : Infinity;
  const cut = [q(.25), q(.5), q(.75)];
  for (const c of cells) c.step = !c.recorded ? null : c.total <= 0 ? 0 : c.total <= cut[0] ? 1 : c.total <= cut[1] ? 2 : c.total <= cut[2] ? 3 : 4;
  const coverage = Math.min(...list.map(x => x.daily.coverageStart));
  const hasImport = cells.some(c => c.imported > 0);
  return {cells, first, coverage, short: coverage > first, len, hasImport};
}
// polish A: the square cells take the largest size the measured area allows in both directions (5–14 px), so the
// 26 weeks fill the wider screen at 890 and still fit the shorter one at 760; the block is centred in the area.
function heatmap(d, ui, list) {
  const {w: AW, h: AH} = fill(ui, 'ov', {w: 300, h: 110}), {cells, first, coverage, short, hasImport} = heatCells(d, ui, list);
  const gap = 2, top = 12, since = short ? 14 : 0;
  const c = Math.max(5, Math.min(14, Math.floor((AW + gap) / 26 - gap), Math.floor((AH - top - since + gap) / 7 - gap))), pitch = c + gap;
  const colour = ui.scope ? list[0]?.a.colour : null;
  const months = [];
  for (let col = 0; col < 26; col++) { const at = daysBefore(first, -col * 7), prev = daysBefore(at, 7); if (col === 0 || new Date(at).getMonth() !== new Date(prev).getMonth()) months.push({col, at}); }
  const H = top + 7 * pitch - gap, W = 26 * pitch - gap, x0 = Math.max(0, Math.floor((AW - W) / 2)), y0 = Math.max(0, Math.floor((AH - since - H) / 2));
  const rects = cells.map(x => {
    if (x.step == null) return '';
    const lines = [md(x.at, ui), ...(x.per.length ? x.per.map(p => `${p.a.short} ${tok(p.v)}${importNote(p.i, p.v)}`) : [t('mfd.noRecord')])];
    return `<rect class="hm s${x.step} ${startOfDay(x.at) === startOfDay(d.now) ? 'today' : ''}" x="${x.col * pitch}" y="${top + x.row * pitch}" width="${c}" height="${c}" rx="1.2" data-tip="${tip(lines)}"/>`;
  }).join('');
  return `<svg class="ov-heat ${colour ? 'vendor' : ''}" style="left:${x0}px;top:${y0}px;${colour ? `--hv:${colour}` : ''}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t('mfd.heatAria')}">
    ${months.filter((m, i) => !i || m.col - months[i - 1].col >= 3).map(m => `<text class="hm-m" x="${m.col * pitch}" y="9">${esc(mon(m.at, ui))}</text>`).join('')}${rects}</svg>
    ${short ? `<p class="hm-since" style="left:${x0}px">${t('mfd.since', {d: md(coverage, ui)})}</p>` : ''}`;
}


export const overview = {
  id: 'overview', title: 'mfd.pOverview',
  optionKeys: ui => [
    // v1: the Grid key is shown but not lit and changes nothing (CKP-MFD-62); the heatmap code above is for v1.1.
    {id: 'chart', a: {value:'bars', text: t('mfd.oBars'), on: true}, b: {value:'bars', text: t('mfd.oGrid'), on: false}},
    // CKP-SHELL-50: the app's range; Today is the 24-hour chart (ui.days follows the range in the deck).
    rangeKey(ui),
    {id:'stack',a:{value:'stack', text:t('mfd.oStack'),on:ui.stack},b:{value:'split', text:t('mfd.oSplit'),on:!ui.stack}},
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
    if (!list.length && !todayKnown)
      return `${alerts}<div class="mp-empty ov-empty"><b>${t('mfd.ovNoRecord1')}</b><span>${t('mfd.ovNoRecord2')}</span><span>${t('mfd.ovNoRecord3')}</span></div>`;
    const row = totals(d, ui, list, costs);
    // Bars exist only with ≈cost. The line under them says how much use had no public price and so is not counted.
    const share = d.cost?.unpriced?.[ui.days === 24 ? 'today' : ui.days === 7 ? 'd7' : 'd30'];
    const chart = costs.length && ui.chart !== 'grid' ? `<div class="mfd-fill" data-fill="ov">${overviewBars(d, ui, costs)}</div>${share > 0 ? `<p class="ov-note">${t('mfd.ovUnpriced', {p: share < .01 ? '<1' : Math.round(share * 100)})}</p>` : ''}`
      : ui.chart === 'grid' && list.length ? `<div class="mfd-fill" data-fill="ov">${heatmap(d, ui, list)}</div>` : '';
    return `${alerts}${row}${chart}`;
  },
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'chart') return {patch: {mfdChart: 'bars'}};
    if (act === 'opt' && val === 'range') return {range: ui.optionChoice};
    if (act === 'opt' && val === 'stack') return {patch: {mfdStack: ui.optionChoice != null ? ui.optionChoice === 'stack' : !ui.stack}};
    if (act === 'alerts') return {open: ['alerts', {from: 'mfd', key: 'alerts'}]};
    return null;
  },
};
