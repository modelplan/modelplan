// 总览 (spec 6.1): the alert list on top (red / amber / blue, most urgent first), today's and the 30-day totals, then
// one chart, 曲线 (the r5 7/30-day lines, 分 | 叠) or 点阵 (a 26-week heatmap). Pure view (spec 2.6).
import {t} from '../i18n.js';
import {chartPalette} from '../chart-colours.js';
import {esc, tok, unit, md, mon, tip, fill} from './fmt.js';
import {accountsIn} from './scope.js';
import {statusItems,statusRow} from './public-helpers.js';

const DAY = 864e5;

export function alertList(d, {max = 3} = {}) {
  const a = statusItems(d.alerts);
  if (!a.length) return '';
  const shown = a.length > max ? a.slice(0, max - 1) : a;
  return `<ul class="mfd-alerts">${shown.map(x => statusRow(x)||`<li class="al-${x.level}" data-tip="${esc(x.text)}"><i>●</i><span>${esc(x.text)}</span></li>`).join('')}${
    a.length > shown.length ? `<li class="al-more"><button data-mfd="alerts">${t('mfd.moreAlerts', {n: a.length - shown.length})}</button></li>` : ''}</ul>`;
}

const series = (d, ui) => accountsIn(d, ui).map(a => ({a, daily: d.daily.find(x => x.accountId === a.id)})).filter(x => x.daily);

function totals(d,ui,list){
 // Every selected subscription must have a Today reading; an unknown one is not a zero.
 const todays=accountsIn(d,ui).map(a=>a.todayTokens),today=todays.length&&todays.every(Number.isFinite)?todays.reduce((s,v)=>s+v,0):null,d30=list.reduce((s,x)=>s+x.daily.values.slice(-30).reduce((p,v)=>p+(v||0),0),0);
 return `<div class="ov-top"><span class="lbl">${t('mfd.today')}</span><b class="ov-total">${today===null?'--':tok(today)}</b><span class="sp"></span><span class="lbl">${t('mfd.d30')}</span><span class="ov-sum">${tok(d30)}</span></div>`;
}
// Equal width buckets, no interpolation. Gaps consume display pixels, never data height.
export function overviewBars(d,ui,list){
 const {w:W,h:H}=fill(ui,'ov',{w:260,h:110}),hourly=ui.days===24,instants=d.hourly?.[0]?.instants,n=hourly?(instants?.length||24):ui.days;
 const palette=chartPalette(d.accounts.filter(a=>d.daily.some(x=>x.accountId===a.id))),byId=new Map(palette.map(x=>[x.id,x]));
 const ser=list.map((x,j)=>({a:x.a,fill:byId.get(x.a.id).fill,v:hourly?d.hourly?.find(h=>h.accountId===x.a.id)?.values||Array(24).fill(null):x.daily.values.slice(-n),imp:hourly?[]:(x.daily.imported||[]).slice(-n)}));
 // Imported history (older, read once from the tools' logs) is drawn lighter in the same hue; a live figure is never replaced by it.
 const hasImport=ser.some(x=>x.imp.some(v=>v>0)),coverage=Math.min(...list.map(x=>x.daily.coverageStart)),from=hasImport&&!hourly?Math.round((coverage-(startOfDay(d.now)-(n-1)*DAY))/DAY):-1;
 const total=Array.from({length:n},(_,i)=>ser.reduce((s,x)=>s+(x.v[i]||0),0));
 const max=Math.max(...(ui.stack?total:ser.flatMap(x=>x.v.map(v=>v||0))),1),base=Math.max(12,H-15),top=3;
 const pitch=W/n,bw=Math.max(.5,pitch-2),height=base-top,scale=(height-(ui.stack?Math.max(0,ser.length-1)*2:0))/max;
 let body='';
 for(let i=0;i<n;i++){
  const at=instants?.[i], stamp=hourly?(at!=null?new Date(at).toLocaleTimeString(ui.lang,{hour:'2-digit',minute:'2-digit',hour12:false,timeZoneName:'shortOffset'}):`${String(i).padStart(2,'0')}:00`):md(d.now-(n-1-i)*DAY,ui);
  const per=ser.filter(x=>x.v[i]!=null),lines=[`${stamp} · ${per.length?tok(total[i]):t('mfd.noRecord')}`,...per.map(x=>`${x.a.short} ${tok(x.v[i])}${importNote(x.imp[i],x.v[i])}`)],imported=ser.reduce((s,x)=>s+(x.imp[i]||0),0);
  let y=base;
  const active=ser.filter(x=>(x.v[i]||0)>0),last=active.at(-1);
  const rects=ser.map((x,j)=>{const value=x.v[i];if(!(value>0))return '';const bh=value*scale;
   const xx=ui.stack?i*pitch+1:i*pitch+1+j*bw/Math.max(1,ser.length),ww=ui.stack?bw:Math.max(.2,bw/Math.max(1,ser.length)-.5);
   const yy=ui.stack?y-bh:base-value/max*height; if(ui.stack)y=yy-2;
   const h=ui.stack?bh:value/max*height,rad=ui.stack&&x!==last?0:Math.min(1.5,h/2,ww/2);
   // Only top corners are rounded. Small values retain their true height.
   const path=`M${xx},${yy+h}V${yy+rad}Q${xx},${yy} ${xx+rad},${yy}H${xx+ww-rad}Q${xx+ww},${yy} ${xx+ww},${yy+rad}V${yy+h}Z`;
   const lighter=x.imp[i]>0&&x.imp[i]>=value;
   return `<path class="ov-bar${lighter?' imp':''}" data-sub="${esc(x.a.id)}" data-value="${value}" d="${path}" fill="${x.fill}"/>`;
  }).join('');
  body+=`<g class="ov-bucket${imported>0?' has-imported':''}" data-hour="${hourly?i:''}" data-total="${total[i]}"${imported>0?` data-imported="${imported}"`:''} data-tip="${tip(lines)}"><rect class="ov-hit" x="${i*pitch}" y="0" width="${pitch}" height="${base}"/>${rects}</g>`;
 }
 const ticks=hourly?[[0,'0'],[6,'6'],[12,'12'],[18,'18'],[n-1,`${n}h`]]:[[0,`−${n-1}d`],[Math.floor(n/2),`−${n-1-Math.floor(n/2)}d`],[n-1,t('mfd.todayAxis')]];
 return `<svg class="ov-chart" data-mode="${ui.stack?'stack':'split'}" data-buckets="${n}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t(hourly?'mfd.hourChartAria':'mfd.chartAria',{d:n})}${hasImport?' '+t('mfd.importedAria'):''}">
 ${[.5,1].map(v=>`<path class="ov-grid" d="M0 ${base-height*v}H${W}"/>`).join('')}<path class="ov-base" d="M0 ${base+.5}H${W}"/>${body}${from>0&&from<n?dataFromMark(from,pitch,base,W,n,coverage,ui):''}${ticks.map(([i,label])=>`<text class="ov-ax" x="${i===0?0:i===n-1?W:(i+.5)*pitch}" y="${H-2}" text-anchor="${i===0?'start':i===n-1?'end':'middle'}">${esc(label)}</text>`).join('')}</svg>`;
}
const startOfDay=ms=>{const x=new Date(ms);return new Date(x.getFullYear(),x.getMonth(),x.getDate()).getTime();};
const importNote=(imp,v)=>imp>0&&imp<v?` · ${t('mfd.importedPart',{v:tok(imp)})}`:imp>0&&imp>=v?` · ${t('mfd.importedDay')}`:'';
// Where the data starts: a quiet rule and a label, only while imported days are on the chart.
function dataFromMark(k,pitch,base,W,n,coverage,ui){const x=k*pitch;return `<path class="ov-from" d="M${x} 3V${base}"/>`;}
// The label sits in the legend row below the chart, so a bucket's tooltip (drawn from the chart's top) never covers it.
function dataFromLabel(d,ui,list){
  if(ui.days===24)return '';
  const n=ui.days,coverage=Math.min(...list.map(x=>x.daily.coverageStart));
  if(!list.some(x=>(x.daily.imported||[]).slice(-n).some(v=>v>0)))return '';
  const k=Math.round((coverage-(startOfDay(d.now)-(n-1)*DAY))/DAY);
  return k>0&&k<n?`<span class="ov-from-l">${esc(t('mfd.dataFrom',{d:md(coverage,ui)}))}</span>`:'';
}
function legend(d,ui,list){const colours=new Map(chartPalette(d.accounts.filter(a=>d.daily.some(x=>x.accountId===a.id))).map(x=>[x.id,x]));return `<div class="ov-legend">${list.map((x,i)=>`<span data-sub="${esc(x.a.id)}" title="${esc(x.a.name)}"><i style="background:${colours.get(x.a.id).fill}"></i>${esc(x.a.short)}</span>`).join('')}${dataFromLabel(d,ui,list)}</div>`;}

/* 点阵: 26 weeks × 7 days (Monday on top), five steps. Neutral LCD ink in 全部, the vendor colour in a subscription
   scope. Hover: the date and the tokens per subscription. Days before the record began have no cell. */
export function heatCells(d, ui, list) {
  const today = new Date(d.now), wdToday = (today.getDay() + 6) % 7, count = 25 * 7 + wdToday + 1;
  const len = Math.max(...list.map(x => x.daily.values.length)), first = d.now - (count - 1) * DAY;
  const cells = Array.from({length: count}, (_, k) => {
    const at = first + k * DAY, per = list.map(x => ({a: x.a, v: x.daily.values[x.daily.values.length - count + k] ?? null, i: (x.daily.imported || [])[x.daily.values.length - count + k] ?? 0}));
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
  for (let col = 0; col < 26; col++) { const at = first + col * 7 * 864e5, prev = at - 7 * 864e5; if (col === 0 || new Date(at).getMonth() !== new Date(prev).getMonth()) months.push({col, at}); }
  const H = top + 7 * pitch - gap, W = 26 * pitch - gap, x0 = Math.max(0, Math.floor((AW - W) / 2)), y0 = Math.max(0, Math.floor((AH - since - H) / 2));
  const rects = cells.map(x => {
    if (x.step == null) return '';
    const lines = [md(x.at, ui), ...(x.per.length ? x.per.map(p => `${p.a.short} ${tok(p.v)}${importNote(p.i, p.v)}`) : [t('mfd.noRecord')])], lighter = x.imported > 0 && x.imported >= x.total;
    return `<rect class="hm s${x.step} ${x.at + 864e5 > d.now ? 'today' : ''}${lighter ? ' imp' : ''}" x="${x.col * pitch}" y="${top + x.row * pitch}" width="${c}" height="${c}" rx="1.2" data-tip="${tip(lines)}"/>`;
  }).join('');
  return `<svg class="ov-heat ${colour ? 'vendor' : ''}" style="left:${x0}px;top:${y0}px;${colour ? `--hv:${colour}` : ''}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t('mfd.heatAria')}${hasImport ? ' ' + t('mfd.importedAria') : ''}">
    ${months.filter((m, i) => !i || m.col - months[i - 1].col >= 3).map(m => `<text class="hm-m" x="${m.col * pitch}" y="9">${esc(mon(m.at, ui))}</text>`).join('')}${rects}</svg>
    ${short ? `<p class="hm-since" style="left:${x0}px">${t(hasImport ? 'mfd.dataFrom' : 'mfd.since', {d: md(coverage, ui)})}</p>` : ''}`;
}

export const overview = {
  id: 'overview', title: 'mfd.pOverview',
  optionKeys: ui => [
    {id: 'chart', a: {value:'bars', text: t('mfd.oBars'), on: ui.chart !== 'grid'}, b: {value:'grid', text: t('mfd.oGrid'), on: ui.chart === 'grid'}},
    ui.chart !== 'grid' ? {id:'days',items:[{value:24,text:'24h',on:ui.days===24},{value:7,text:'7',on:ui.days===7},{value:30,text:'30',on:ui.days===30}]} : null,
    ui.chart !== 'grid' ? {id:'stack',a:{value:'stack', text:t('mfd.oStack'),on:ui.stack},b:{value:'split', text:t('mfd.oSplit'),on:!ui.stack}} : null,
    null],
  render(d, ui) {
    const list = series(d, ui);
    // polish A: the taller screen shows more alert lines before "+N ▸" (3 at 760, 4 at 834, 5 at 890); the chart
    // takes the rest of the height (data-fill), so the page always fills the screen.
    const h = fill(ui, 'page', {w: 330, h: 170}).h - 12, max = h >= 185 ? 5 : h >= 165 ? 4 : 3;
    const chart = !list.length ? `<p class="mp-empty">${t('mfd.quotaOnly')}</p>`
      : `<div class="mfd-fill" data-fill="ov">${ui.chart === 'grid' ? heatmap(d, ui, list) : overviewBars(d, ui, list)}</div>`;
    return `${alertList(d, {max})}${list.length ? totals(d, ui, list) : ''}${chart}${ui.chart==='grid'||!list.length?'':legend(d,ui,list)}`;
  },
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'chart') return {patch: {mfdChart: ui.optionChoice ?? (ui.chart === 'grid' ? 'bars' : 'grid')}};
    if (act === 'opt' && val === 'days') return {patch: {mfdDays: ui.optionChoice != null ? Number(ui.optionChoice) : ui.days === 30 ? 24 : ui.days === 24 ? 7 : 30}};
    if (act === 'opt' && val === 'stack') return {patch: {mfdStack: ui.optionChoice != null ? ui.optionChoice === 'stack' : !ui.stack}};
    if (act === 'alerts') return {open: ['alerts', {from: 'mfd', key: 'alerts'}]};
    return null;
  },
};
