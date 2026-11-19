// Round G, owner-approved task 09. Pure view; positional windows, one aligned number per cell.
import {t,has,formatCredits} from './i18n.js';
import {esc, dhm, tok, when, hm, relativeMoment, approxCost} from './mfd-pages/engine-fmt.js';
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
// G3-109: an extra whose period has no copy (role "other") shows its name alone, never a raw key like extra.per.other.
const extraName = c => c.name || t('eng.other');
const extraPer = c => has('extra.per.'+c.period) ? t('extra.per.'+c.period) : null;
const periodTag = c => c.extra ? (extraPer(c) ? t('extra.name',{n:extraName(c),p:extraPer(c)}) : extraName(c)) : t(TAG[c.period]||'eng.other');
const extraShort = c => [...extraName(c)].length <= 3 ? extraName(c) : extraPer(c) ? t('extra.nameShort',{n:[...extraName(c)][0],p:extraPer(c)}) : t('eng.other');
const ageText = m => m >= 60 ? t('age.hoursShort',{h:Math.floor(m/60)}) : t('age.minutesShort',{m:Math.floor(m)});
function note(col,c,ui) {
  if(col.state==='loading') return {text:t('eng.loading'),short:t('eng.loadingShort')};
  // CKP-ENG-50: an unreadable subscription is a dim "--" with a grey "no reading"; the cause lives in the card and Settings.
  if(col.state==='error') return {text:t('eng.unreadable'),dim:true};
  if(col.state==='error-lastgood') return {text:t('eng.failedAge',{a:t('age.hoursShort',{h:Math.round((col.ageMin||0)/60)})}),short:t('eng.failedShort')};
  if(col.grey) return {text:t('age.hoursShort',{h:Math.round((col.ageMin||0)/60)}),short:t('eng.ageCompact',{t:shortTime(col.ageMin||0)})};
  if(c.event) return {text:c.event.status==='confirmed'?t('eng.resetDone'):c.event.at!=null?t('eng.resetAnn',{at:relativeMoment(c.event.at,ui)}):t('eng.resetTba'),
    short:c.event.status==='confirmed'?t('eng.resetDoneShort'):c.event.at!=null?t('eng.resetAnnShort',{at:relativeMoment(c.event.at,ui)}):t('eng.resetTba'),
    small:c.event.status==='announced'&&c.event.at!=null?t('eng.resetAnnCompact',{at:relativeMoment(c.event.at,ui)}):null,event:true};
  // CKP-ENG-50: a used-up window is a red 0% that says so; credits being drawn say that instead.
  if(c.drawing) return {text:t('eng.drawCell'),crit:true};
  if(c.remaining===0) return {text:t('eng.usedUp'),crit:true};
  // Owner D277 (CKP-ENG-26): the cell that will run out says so itself, in its alert's colour (red at or below the
  // threshold, amber above it), whether or not its reset time is known.
  if(c.runOutMin!=null) return {text:t('eng.runOutC',{t:dhm(c.runOutMin)}),short:t('eng.runOutShort',{t:shortTime(c.runOutMin)}),warn:c.level!=='low',crit:c.level==='low'};
  if(c.noData) return {text:t('eng.noData')};
  // Owner D277 (CKP-ENG-26): an unknown reset time leaves the line empty instead of repeating "reset ?" in every cell;
  // the cell's hover and accessible text still say it.
  if(c.resetIn==null) return {text:''};
  return {text:dhm(c.resetIn),short:shortTime(c.resetIn)};
}
function title(col,c,ui){return [col.name,periodTag(c),c.value==null?t('eng.noReading'):t(ui.used?'eng.used':'eng.left',{v:Math.round(c.value)}),
  c.level==='low'?t('eng.lvLow'):c.level==='mid'?t('eng.lvMid'):'',c.runOutMin!=null?t('eng.runOut',{t:dhm(c.runOutMin)}):'',c.resetIn!=null?t('eng.resetIn',{t:dhm(c.resetIn)}):c.value!=null&&!col.grey?t('eng.resetUnknown'):'',note(col,c,ui).text].filter(Boolean).join(' · ');}
function cell(col,c,row,m,ui,fresh,lead){
  const n=note(col,c,ui), different=c.extra||c.period!==m.rowPeriods[row];
  const tag=different?periodTag(c):'', shortTag=c.extra?extraShort(c):tag;
  // CKP-ENG-22: a stale reading says how old it is, once per column on its first populated quota cell, from the row's own reading time; none known = no age.
  const age=col.state==='stale'&&col.ageMin!=null&&row===lead?ageText(col.ageMin):'';
  const meta=(txt,tg)=>[tg,txt,age,c.more?`+${c.more}`:''].filter(Boolean).join(' ');
  const full=meta(n.warn&&m.cls==='narrow'?(n.short||n.text):n.text,tag), short=meta(n.event&&ui.lang==='zh-CN'?(n.short||n.text).replaceAll(' ',''):(n.short||n.text),shortTag);
  const smallest=[c.extra?[...extraName(c)][0]:tag,n.small||n.short||n.text,age].filter(Boolean).join(' ')+(c.more?`+${c.more}`:'');
  const tip=c.all?c.all.map(x=>title(col,x,ui)).join('\n'):title(col,c,ui);
  // Extras are focusable and carry their details; a reading whose reset time is unknown says so on hover (the line
  // itself stays empty, CKP-ENG-26), as its accessible name does.
  const focusable=c.extra||c.all?.some(x=>x.extra), unknownReset=c.value!=null&&c.resetIn==null&&!col.grey;
  const tipAttr=focusable?`tabindex="0" data-tip="${esc(tip)}"`:unknownReset?`data-tip="${esc(tip)}"`:'';
  return `<div class="qcell lv-${c.level}${c.extra?' qx':''}${c.drawing?' used':''}${c.noData?' nodata':''}${c.event?' ev':''}" data-row="${row}" data-kind="${c.extra?'extra':c.kind}" data-tag="${esc(tag)}" data-more="${c.more||0}"${paint(c)} ${tipAttr} aria-label="${esc(tip)}">
    <span class="qline"><b class="qnum${fresh?' lcd-in':''}"><span class="qvalue">${c.value==null?'--':Math.round(c.value)}</span>${c.value==null?'':'<small>%</small>'}</b><em class="qtxt${n.warn?' warn':''}${n.crit?' crit':''}${n.event?' qev':''}${n.dim?' dim':''}" data-full="${esc(full)}" data-short="${esc(short)}" data-small="${esc(smallest)}">${esc(full)}</em></span>${bar(c)}</div>`;
}
// CKP-ENG-53: the range row, ≈cost first and brightest, then tokens, then speed; the host drops speed and then tokens
// when they do not fit (never a clipped "42/s"). No usage record at all: "quota only" (CKP-ENG-50).
function today(col,m){
 const cost=approxCost(col.cost);
 const parts=(cost?`<span class="qcost" title="${esc(t('eng.costHint'))}" aria-label="${esc(cost+' · '+t('eng.costHint'))}">${esc(cost)}</span>`:'')+(col.today==null?'':`<span class="qtokens">${tok(col.today)}</span>`)+(col.speed==null?'':`<span class="qaverage" aria-label="${esc(t('eng.averageAria',{n:col.speed}))}">${Math.round(col.speed)}<em> t/s</em></span>`);
 return `<div class="qrow qrow-t" aria-label="${esc(t('eng.todayBasis'))}">${parts||(col.quotaOnly?`<span class="qq">${t('eng.quotaOnly')}</span>`:'')}</div>`;}
function reserve(col,m,ui){
  const r=col.reserve;if(!r)return '<div class="qrow qrow-r"></div>';
  // CKP-ENG-52: the row names what it holds ("重置 2 次 · 30h 后到期", "点数 2,368"); the model leaves out zeros.
  const left=r.firstExpiry==null?null:until(r.firstExpiry,ui.now);
  const full=t(r.cards===1?'eng.resetWordOne':'eng.resetsWords',{n:r.cards})+(left?' · '+t('eng.expires',{t:left}):''), short=t(r.cards===1?'eng.resetCompactOne':'eng.resetsCompact',{n:r.cards})+(left?'·'+t('eng.expiresShort',{t:left}):'');
  // G3-109: a money balance arrives formatted and escaped; it reads "Balance $12.34", or the value alone when narrow.
  const points=r.money?t('eng.balance',{v:r.money}):r.credits==null?'':t('eng.points',{v:formatCredits(r.credits,ui.lang).replace('<','&lt;')});
  return `<div class="qrow qrow-r" aria-label="${esc([r.cards!=null?full:'',points].filter(Boolean).join(' · '))}">${r.cards!=null?`<span class="qrv-c${r.warn?' warn':''}" data-full="${esc(full)}" data-short="${esc(short)}">${esc(full)}</span>`:''}${points?`<span class="qrv-p"${r.money?` data-full="${esc(points)}" data-short="${esc(r.money)}"`:''}>${esc(points)}</span>`:''}</div>`;
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
// CKP-ENG-50: a subscription still being read shows a dark placeholder in every row, no text; an unreadable one with
// nothing to show still says so in its first row.
const placeholder=(col,r)=>`<div class="qcell loading" data-row="${r}" aria-label="${esc(col.name+' · '+t('eng.loading'))}"><span class="qph" aria-hidden="true"></span></div>`;
const UNREAD={kind:'5h',period:'5h',remaining:null,value:null,level:'none',lit:0,timeLeft:null,timeLit:null,resetIn:null,resetAt:null,resetText:null,runOutMin:null};
function column(col,m,ui,changed){
 const cells=col.state==='error'&&!m.rows.some(r=>col.cells[r])?{...col.cells,[m.rows[0]]:UNREAD}:col.cells;
 return `<div class="ec${col.tint?' tint-'+col.tint:''}${col.grey?' grey':''}${col.off?' dimmed':''}" data-col="${esc(col.id)}" data-state="${esc(col.state)}">`+
 m.rows.map(r=>col.state==='loading'?placeholder(col,r):cells[r]?cell(col,cells[r],r,m,ui,changed.has(`${col.id}:${r}`),m.rows.find(x=>cells[x])):`<div class="qcell none" data-row="${r}"></div>`).join('')+today(col,m)+(m.reserve?reserve(col,m,ui):'')+(m.rich?detail(col,ui):'')+'</div>';}
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
 // CKP-ENG-56 / D95: one add affordance in the first empty bay; paged bays stay blank (CKP-ENG-03).
 const empty=Array.from({length:n-m.cols.length},(_,i)=>emptyColumn(m,m.cols.length+i,addLabel,i===0&&m.pages<2)).join('');
 const emptyKeys=Array.from({length:n-m.cols.length},()=>emptyKey(addLabel)).join('');
 const labels=m.empty?'':m.rows.map(r=>`<span class="lb lb-${r}">${t(r==='other'?'eng.other':LABEL[m.rowPeriods[r]]||'eng.other')}</span>`).join('')+`<span class="lb lb-t" aria-label="${esc(t('eng.todayBasis'))}">${t('eng.today')}</span>`+(m.reserve?`<span class="lb lb-r" tabindex="0" aria-label="${esc(t('eng.reserveHint'))}" data-tip="${esc(t('eng.reserveHint'))}">${t('eng.reserve')}</span>`:'');
 const keys=`<div class="eng-krow"><button class="ek ek-all${m.scoped?'':' on'}" data-all data-mat="part" aria-pressed="${!m.scoped}" aria-label="${t('eng.allAria')}"><span>${t('eng.all')}</span><i class="bl" aria-hidden="true"></i></button><div class="eng-keys" style="--n:${n}">${m.cols.map(key).join('')}${emptyKeys}</div></div>`;
 return `${keys}<div class="eng-lcd cls-${m.cls}${m.rich?' few-rich':''}" data-mat="well" style="--n:${n};--rows:${rowsTemplate(m)}">${m.empty?`<p class="ec-empty">${t('eng.empty')}</p>`:`<div class="eng-labels">${labels}</div><div class="eng-cols">${m.cols.map(col=>column(col,m,ui,changed)).join('')}${empty}</div>`}</div>${pager(m)}`;
}
