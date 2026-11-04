// Round G, owner-approved task 09. Pure view; positional windows, one aligned number per cell.
import {t,formatCredits} from './i18n.js';
import {esc, dhm, tok, when, hm, relativeMoment} from './mfd-pages/engine-fmt.js';
import {fillColour, numberColour} from './colour-mode.js';
import {emptyKey, emptyColumn} from './empty-bays.js';
import './strings/engine.js';
import './strings/common.js';
import './strings/review49.js';
const TAG = {'5h':'eng.t5h', day:'eng.tDay', week:'eng.tWeek', month:'eng.tMonth'};
const LABEL = {'5h':'eng.row5h', day:'eng.rowDay', week:'eng.rowWeek', month:'eng.rowMonth'};
const H = 3600e3;
export const rowsTemplate = m => [m.rows.length ? `repeat(${m.rows.length},minmax(0,1fr))` : '', '23px', m.reserve ? '32px' : ''].filter(Boolean).join(' ');
const shortTime = n => n >= 1440 ? `${Math.floor(n/1440)}d` : n >= 60 ? `${Math.floor(n/60)}h` : `${Math.floor(n)}m`;
const until = (ms, now) => {const h=Math.max(0,Math.floor((ms-now)/H));return h>48?`${Math.floor(h/24)}d${h%24}h`:`${h}h`;};
const bar = c => `<span class="qmeter"><span class="qbar">${Array.from({length:10},(_,i)=>`<i${i<c.lit?' class="on"':''}></i>`).join('')}</span>${c.timeLit==null?'':`<span class="qtime" data-frac="${c.timeLeft}" aria-hidden="true">${Array.from({length:10},(_,i)=>`<i${i<c.timeLit?' class="on"':''}></i>`).join('')}</span>`}</span>`;
const paint = c => ` style="--qf:${fillColour(c.level)||'var(--lcd-muted)'};--qn:${numberColour(c.level)||'var(--lcd-ink)'}"`;
const periodTag = c => c.extra ? t('extra.name',{n:c.name,p:t('extra.per.'+c.period)}) : t(TAG[c.period]||'eng.other');
function note(col,c,ui) {
  if(col.state==='loading') return {text:t('eng.loading'),short:t('eng.loadingShort')};
  if(col.state==='error') return {text:t('eng.failed')};
  if(col.state==='error-lastgood') return {text:t('eng.failedAge',{a:t('age.hoursShort',{h:Math.round((col.ageMin||0)/60)})}),short:t('eng.failedShort')};
  if(col.grey) return {text:t('age.hoursShort',{h:Math.round((col.ageMin||0)/60)}),short:t('eng.ageCompact',{t:shortTime(col.ageMin||0)})};
  if(c.event) return {text:c.event.status==='confirmed'?t('eng.resetDone'):c.event.at!=null?t('eng.resetAnn',{at:relativeMoment(c.event.at,ui)}):t('eng.resetTba'),
    short:c.event.status==='confirmed'?t('eng.resetDoneShort'):c.event.at!=null?t('eng.resetAnnShort',{at:relativeMoment(c.event.at,ui)}):t('eng.resetTba'),
    small:c.event.status==='announced'&&c.event.at!=null?t('eng.resetAnnCompact',{at:relativeMoment(c.event.at,ui)}):null,event:true};
  if(c.runOutMin!=null) return {text:t('eng.runOutC',{t:dhm(c.runOutMin)}),short:t('eng.runOutShort',{t:shortTime(c.runOutMin)}),warn:true};
  if(c.drawing) return {text:t('eng.drawCell'),crit:true};
  if(c.noData) return {text:t('eng.noData')};
  if(c.resetIn==null) return {text:t('eng.resetUnknown'),short:t('eng.resetUnknownShort')};
  return {text:dhm(c.resetIn),short:shortTime(c.resetIn)};
}
function title(col,c,ui){return [col.name,periodTag(c),c.value==null?t('eng.noReading'):t(ui.used?'eng.used':'eng.left',{v:Math.round(c.value)}),
  c.level==='low'?t('eng.lvLow'):c.level==='mid'?t('eng.lvMid'):'',c.runOutMin!=null?t('eng.runOut',{t:dhm(c.runOutMin)}):'',c.resetIn!=null?t('eng.resetIn',{t:dhm(c.resetIn)}):'',note(col,c,ui).text].filter(Boolean).join(' · ');}
function cell(col,c,row,m,ui,fresh){
  const n=note(col,c,ui), different=c.extra||c.period!==m.rowPeriods[row];
  const tag=different?periodTag(c):'', shortTag=c.extra?(c.name.length>3?t('extra.name',{n:[...c.name][0],p:t('extra.per.'+c.period)}):c.name):tag;
  const meta=(txt,tg)=>[tg,txt,c.more?`+${c.more}`:''].filter(Boolean).join(' ');
  const full=meta(n.warn&&m.cls==='narrow'?(n.short||n.text):n.text,tag), short=meta(n.event&&ui.lang==='zh-CN'?(n.short||n.text).replaceAll(' ',''):(n.short||n.text),shortTag);
  const smallest=[c.extra?[...c.name][0]:tag,n.small||n.short||n.text].filter(Boolean).join(' ')+(c.more?`+${c.more}`:'');
  const tip=c.all?c.all.map(x=>title(col,x,ui)).join('\n'):title(col,c,ui);
  return `<div class="qcell lv-${c.level}${c.extra?' qx':''}${c.drawing?' used':''}${c.noData?' nodata':''}${c.event?' ev':''}" data-row="${row}" data-kind="${c.extra?'extra':c.kind}" data-tag="${esc(tag)}" data-more="${c.more||0}"${paint(c)} ${c.extra||c.all?.some(x=>x.extra)?`tabindex="0" data-tip="${esc(tip)}"`:""} aria-label="${esc(tip)}">
    <span class="qline"><b class="qnum${fresh?' lcd-in':''}"><span class="qvalue">${c.value==null?'--':Math.round(c.value)}</span>${c.value==null?'':'<small>%</small>'}</b><em class="qtxt${n.warn?' warn':''}${n.crit?' crit':''}${n.event?' qev':''}" data-full="${esc(full)}" data-short="${esc(short)}" data-small="${esc(smallest)}">${esc(full)}</em></span>${bar(c)}</div>`;
}
function today(col,m){return `<div class="qrow qrow-t" aria-label="${esc(t('eng.todayBasis'))}">${col.today==null?'':`<span class="qtokens">${tok(col.today)}</span>`}${col.speed==null?'':`<span class="qaverage" aria-label="${esc(t('eng.averageAria',{n:col.speed}))}">${Math.round(col.speed)}<em>${m.cls==='narrow'?'/s':' t/s'}</em></span>`}</div>`;}
function reserve(col,m,ui){
  const r=col.reserve;if(!r)return '<div class="qrow qrow-r"></div>';
  const expiry=r.firstExpiry==null?'':` · ${until(r.firstExpiry,ui.now)}`;
  const full=t(r.cards===1?'eng.resetWordOne':'eng.resetsWords',{n:r.cards})+expiry, short=t(r.cards===1?'eng.resetCompactOne':'eng.resetsCompact',{n:r.cards})+expiry.replaceAll(' ','');
  const points=r.credits==null?'':formatCredits(r.credits,ui.lang).replace('<','&lt;');
  return `<div class="qrow qrow-r" aria-label="${esc([r.cards!=null?full:'',points].filter(Boolean).join(' · '))}">${r.cards!=null?`<span class="qrv-c${r.warn?' warn':''}" data-full="${esc(full)}" data-short="${esc(short)}">${esc(full)}</span>`:''}${points?`<span class="qrv-p">${esc(points)}</span>`:''}</div>`;
}
// Exactly two extra instruments in the wide-column prototype; missing history stays unplotted.
function detail(col, ui) {
 const values=col.usage7, valid=values?.length===7&&values.every(v=>Number.isFinite(v)&&v>=0);
 const max=valid?Math.max(1,...values):1;
 const points=valid?values.map((v,i)=>`${2+i*16},${30-v/max*26}`).join(' '):'';
 const cells=col.state==='ok'?Object.values(col.cells).filter(c=>c&&c.resetIn!=null):[];
 const c=cells.find(c=>c.runOutMin!=null)||cells[0];
 const run=c?.runOutMin, reset=c?.resetIn, known=reset!=null&&reset>0&&run!=null&&run>=0&&run<=reset;
 const runX=known?2+96*run/reset:null;
 const resetLabel=reset==null?'--':dhm(reset);
 return `<div class="eng-detail"><div class="eng-history" role="img" aria-label="${esc(t('eng.usage7'))}"><span>${t('eng.usage7')}</span><svg viewBox="0 0 100 34" preserveAspectRatio="none" aria-hidden="true"><path class="eng-track" d="M2 32H98"/>${valid?`<polyline points="${points}"/>`:''}</svg></div>
 <div class="eng-reset" role="img" aria-label="${esc(t('eng.timelineAria',{reset:resetLabel})+(known?' · '+t('eng.runOut',{t:dhm(run)}):''))}"><span class="eng-endpoints"><span>${t('eng.now')}</span><span aria-label="${esc(t('eng.resetPoint')+' · '+resetLabel)}">${resetLabel}</span></span><svg viewBox="0 0 100 12" preserveAspectRatio="none" aria-hidden="true"><path class="eng-track" d="M2 6H98"/><path d="M2 3V9${reset==null?'':'M98 2V10'}"/>${known?`<path class="eng-runout" d="M${runX} 1V11"/>`:''}</svg>${known?`<span class="eng-runout-label">${t('eng.runOutC',{t:dhm(run)})}</span>`:''}</div></div>`;
}
function column(col,m,ui,changed){return `<div class="ec${col.tint?' tint-'+col.tint:''}${col.grey?' grey':''}${col.off?' dimmed':''}" data-col="${esc(col.id)}" data-state="${esc(col.state)}">`+
 m.rows.map(r=>col.cells[r]?cell(col,col.cells[r],r,m,ui,changed.has(`${col.id}:${r}`)):`<div class="qcell none" data-row="${r}"></div>`).join('')+today(col,m)+(m.reserve?reserve(col,m,ui):'')+(m.rich?detail(col,ui):'')+'</div>';}
const key=col=>`<button class="ek bd-r${col.on?' on':''}${col.off?' off':''}" data-sub="${esc(col.id)}" data-col="${esc(col.id)}" data-mat="part" title="${esc(col.name)}" aria-pressed="${col.on}" aria-label="${esc(t('eng.keyAria',{name:col.name,k:col.key}))}"><span class="ek-identity"><img class="lamp" src="assets/brands/${esc(col.logo)}" alt=""><span class="ek-name" data-full="${esc(col.short)}" data-short="${esc(col.alias||col.short)}" title="${esc(col.name)}">${esc(col.short)}</span></span><i class="bl" style="--v:${esc(col.colour)}"></i><span class="ki">${col.key}</span></button>`;
function pageDescription(l,m) { return t('rev49.page',{p:l.page+1,names:(l.accounts||[]).map(a=>a.name+(a.status?' · '+t(a.status==='red'?'eng.lvLow':'eng.lvMid'):'')).join(', '),scope:t(m.scoped?'rev49.pageSub':'rev49.pageAll')}); }

function pager(m) {
  if (m.pages < 2) return '';
  const lv = l => l === 'red' ? ' lv-red' : l === 'amber' ? ' lv-amber' : '';
  const aria = [t('eng.pgAria', {p: m.page + 1, n: m.pages}),
    ...m.leds.filter(l => l.level).map(l => t('eng.pgAlert', {p: l.page + 1, lv: t(l.level === 'red' ? 'eng.lvLow' : 'eng.lvMid')}))].join(' · ');
  return `<div class="eng-pg"><button class="key sm eng-pk" data-bpage="-1" data-mat="part" aria-disabled="${m.page === 0}" aria-label="${t('eng.pgPrevAria')}">◀</button>`
    + `<span class="eng-leds" role="group" aria-label="${esc(aria)}">${m.leds.map(l => `<i class="eng-led${l.current ? ' cur' : ''}${lv(l.level)}" data-page="${l.page}" tabindex="0" role="img" aria-label="${esc(pageDescription(l,m))}" data-tip="${esc(pageDescription(l,m))}"></i>`).join('')}</span>`
    + `<button class="key sm eng-pk" data-bpage="1" data-mat="part" aria-disabled="${m.page === m.pages - 1}" aria-label="${t('eng.pgNextAria')}">▶</button></div>`;
}

export const cautionView = c => `<button class="caution${c.level ? ' lit ' + c.level : ''}${c.flash ? ' flash' : ''}" data-caution data-mat="part" aria-label="${c.level ? t('eng.cautionLitAria') : t('eng.cautionAria')}"><span>ALERT</span></button>`;


export function engineView(m,{changed=new Set(),lang='zh-CN',now=Date.now()}={}){
 const ui={lang,now,used:m.used},n=m.slots;
 const addLabel=esc(t("eng.addSubscription"));
 const empty=Array.from({length:n-m.cols.length},(_,i)=>emptyColumn(m,m.cols.length+i,addLabel)).join('');
 const emptyKeys=Array.from({length:n-m.cols.length},()=>emptyKey(addLabel)).join('');
 const labels=m.empty?'':m.rows.map(r=>`<span class="lb lb-${r}">${t(r==='other'?'eng.other':LABEL[m.rowPeriods[r]]||'eng.other')}</span>`).join('')+`<span class="lb lb-t" aria-label="${esc(t('eng.todayBasis'))}">${t('eng.today')}</span>`+(m.reserve?`<span class="lb lb-r">${t('eng.reserve')}</span>`:'');
 const keys=`<div class="eng-krow"><button class="ek ek-all${m.scoped?'':' on'}" data-all data-mat="part" aria-pressed="${!m.scoped}" aria-label="${t('eng.allAria')}"><span>${t('eng.all')}</span><i class="bl" aria-hidden="true"></i></button><div class="eng-keys" style="--n:${n}">${m.cols.map(key).join('')}${emptyKeys}</div></div>`;
 return `${keys}<div class="eng-lcd cls-${m.cls}${m.rich?' few-rich':''}" data-mat="well" style="--n:${n};--rows:${rowsTemplate(m)}">${m.empty?`<p class="ec-empty">${t('eng.empty')}</p>`:`<div class="eng-labels">${labels}</div><div class="eng-cols">${m.cols.map(col=>column(col,m,ui,changed)).join('')}${empty}</div>`}</div>${pager(m)}`;
}
