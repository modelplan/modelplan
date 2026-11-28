// Round G, owner-approved task 09. Pure view; positional windows, one aligned number per cell.
import {t,has,formatCredits} from './i18n.js';
import {esc, dhm, tok, hm, approxCost, countdown} from './mfd-pages/engine-fmt.js';
import {fillColour, numberColour} from './colour-mode.js';
import {emptyKey, emptyColumn} from './empty-bays.js';
import './strings/engine.js';
import './strings/common.js';
import './strings/review49.js';
const TAG = {'5h':'eng.t5h', day:'eng.tDay', week:'eng.tWeek', month:'eng.tMonth'};
const LABEL = {'5h':'eng.row5h', day:'eng.rowDay', week:'eng.rowWeek', month:'eng.rowMonth'};
const H = 3600e3;
export const rowsTemplate = m => [m.rows.length ? `repeat(${m.rows.length},minmax(0,1fr))` : '', '23px', m.reserve ? '32px' : ''].filter(Boolean).join(' ');
const bar = c => `<span class="qmeter"><span class="qbar">${Array.from({length:10},(_,i)=>`<i${i<c.lit?' class="on"':''}></i>`).join('')}</span>${c.timeLit==null?'':`<span class="qtime" data-frac="${c.timeLeft}" aria-hidden="true">${Array.from({length:10},(_,i)=>`<i${i<c.timeLit?' class="on"':''}></i>`).join('')}</span>`}</span>`;
const paint = c => ` style="--qf:${fillColour(c.level)||'var(--lcd-muted)'};--qn:${numberColour(c.level)||'var(--lcd-ink)'}"`;
// G3-109: an extra whose period has no copy (role "other") shows its name alone, never a raw key like extra.per.other.
const extraName = c => c.name || t('eng.other');
const extraPer = c => has('extra.per.'+c.period) ? t('extra.per.'+c.period) : null;
const periodTag = c => c.extra ? (extraPer(c) ? t('extra.name',{n:extraName(c),p:extraPer(c)}) : extraName(c)) : t(TAG[c.period]||'eng.other');
// D417: an extra window's name is a short label (MCP, Opus, Fable: at most 6 characters) shown in full on every width.
const NAME_MAX = 5;
// The six-column cell cannot fit "Sonnet" beside its time (fit spec D417), so its narrow variants use the defined short form.
const NARROW = {Sonnet: 'Snt'};
const narrowName = c => NARROW[extraName(c)] || extraName(c);
const fitsNarrow = c => [...narrowName(c)].length <= (c.named ? NAME_MAX : 3);
const extraShort = c => fitsNarrow(c) ? narrowName(c) : extraPer(c) ? t('extra.nameShort',{n:[...extraName(c)][0],p:extraPer(c)}) : t('eng.other');
const ageText = m => m >= 60 ? t('age.hoursShort',{h:Math.floor(m/60)}) : t('age.minutesShort',{m:Math.floor(m)});
// D474 §3.2 / decision 1 (C26): a quota cell has two lines beside its number. Line 1 = the real reset ("4d14h 后重置",
// narrow "4d14h后"), ink-3 and never coloured. Line 2 = the estimate: "预估 2d16h 用完" (narrow "2d16h完") in amber or red
// only when it runs out before the reset, else a faint "够用到重置" ("够用"); used up "已用完" and drawing "扣点中" in red.
// Each line is {full, short}; a narrow cell starts at its narrow form, a wide one falls back to it (host fit()).
// §3.4 失败·2h: the age of the kept reading in whole units (45m, 2h, 3d).
const failAge = m => m < 60 ? `${Math.max(1,Math.round(m))}m` : m < 1440 ? `${Math.round(m/60)}h` : `${Math.round(m/1440)}d`;
const L = (full, short = full, cls = '') => ({full, short: short || full, cls});
const NONE = L('');
function lines(col,c,m,row,lead,named){
  const narrow=m.cls==='narrow', pick=(w,n,cls='')=>narrow?L(n,n,cls):L(w,n,cls);
  // CKP-ENG-50 / §3.4: no reading (or a kept reading that lapsed) is a dim "--" with 读不到 on line 1.
  if(col.state==='error'||c.lapsed) return [L(t('eng.unreadable'),t('eng.unreadable'),'dim'),NONE];
  // D275 / CKP-ENG-50: the latest attempt failed but a good reading is kept: its numbers stay, line 1 says how old.
  if(col.state==='error-lastgood') return [L(t('eng.failedAge',{a:failAge(col.ageMin||0)}),t('eng.failedShort')),NONE];
  if(c.noData) return [L(t('eng.noData')),NONE];
  // CKP-ENG-22: a stale reading says how old it is, once per column on its first populated cell's line 1.
  const age=col.state==='stale'&&col.ageMin!=null&&row===lead?ageText(col.ageMin):'';
  // CKP-ENG-26: an unknown reset time leaves line 1 empty (no "reset ?" in every cell); the hover still says it.
  const reset=c.resetIn==null?NONE:pick(t('eng.resetLine',{t:countdown(c.resetIn)}),t('eng.resetNarrow',{t:countdown(c.resetIn,{narrow:true})}));
  const est=c.drawing?L(t('eng.drawCell'),t('eng.drawCell'),'crit'):c.remaining===0?L(t('eng.usedUp'),t('eng.usedUp'),'crit')
    :c.runOutMin!=null?pick(t('eng.estLine',{t:countdown(c.runOutMin)}),t('eng.estNarrow',{t:countdown(c.runOutMin,{narrow:true})}),c.level==='low'?'crit':'warn')
    :c.lasts?pick(t('eng.lasts'),t('eng.lastsNarrow')):NONE;
  const more=c.more?` +${c.more}`:'';
  const join=(...p)=>p.filter(Boolean).join(' ');
  // C33: a cell names its window only when its row heading cannot (額外 over mixed windows). Wide: the name leads line 1.
  // Narrow: the name takes line 1 and the reset moves to line 2, unless the window also has an estimate (or is used up):
  // then the name moves into the hover and the lines stay reset / estimate.
  if(named&&narrow&&!est.full) return [L(join(named.narrow,age)+more),L(reset.full,reset.short)];
  if(named&&!narrow) return [L(join(named.wide,reset.full,age)+more,join(named.narrow,reset.short,age)+more),est];
  return [L(join(reset.full,age)+more,join(reset.short,age)+more),est];
}
const hoverTag = c => c.extra && has('extra.quota.'+c.period) ? t('extra.hover',{n:extraName(c),p:t('extra.quota.'+c.period)}) : periodTag(c);
function title(col,c,ui){return [col.name,hoverTag(c),c.value==null?t('eng.noReading'):t(ui.used?'eng.used':'eng.left',{v:Math.round(c.value)}),
  c.level==='low'?t('eng.lvLow'):c.level==='mid'?t('eng.lvMid'):'',c.runOutMin!=null?t('eng.runOut',{t:dhm(c.runOutMin)}):c.lasts?t('eng.lasts'):'',c.resetIn!=null?t('eng.resetIn',{t:dhm(c.resetIn)}):c.value!=null&&!col.grey?t('eng.resetUnknown'):'',
  c.lapsed||col.state==='error'?t('eng.unreadable'):'',(c.lapsed||col.grey)&&col.attemptAt!=null?t('eng.lastTry',{at:hm(col.attemptAt)}):''].filter(Boolean).join(' · ');}
const qtxt=(l,n)=>`<em class="qtxt ql${n}${l.cls?' '+l.cls:''}" data-full="${esc(l.full)}" data-short="${esc(l.short)}">${esc(l.full)}</em>`;
function cell(col,c,row,m,ui,fresh,lead){
  const different=c.extra||c.period!==m.rowPeriods[row], tag=different?periodTag(c):'';
  // C33: the name is drawn only under the 额外 heading (each cell names its own window); a named heading says it once.
  const mixed=otherHeading(m)===t('eng.extra');
  const named=c.extra?(mixed?{wide:extraName(c),narrow:extraShort(c)}:null):different?{wide:tag,narrow:tag}:null;
  const [l1,l2]=lines(col,c,m,row,lead,named);
  const tip=c.all?c.all.map(x=>title(col,x,ui)).join('\n'):title(col,c,ui);
  // Extras are focusable and carry their details (the hover always adds the period: "MCP · 每月额度"); a reading whose
  // reset time is unknown or that lapsed says so on hover, as its accessible name does.
  const focusable=c.extra||c.all?.some(x=>x.extra), unknownReset=c.value!=null&&c.resetIn==null&&!col.grey;
  const tipAttr=focusable||c.lapsed?`tabindex="0" data-tip="${esc(tip)}"`:unknownReset?`data-tip="${esc(tip)}"`:'';
  const value=c.value==null||c.lapsed;
  return `<div class="qcell lv-${c.level}${c.extra?' qx':''}${c.drawing?' used':''}${c.noData?' nodata':''}${c.lapsed?' lapsed':''}" data-row="${row}" data-kind="${c.extra?'extra':c.kind}" data-tag="${esc(tag)}" data-more="${c.more||0}"${paint(c)} ${tipAttr} aria-label="${esc(tip)}">
    <span class="qline"><b class="qnum${fresh?' lcd-in':''}"><span class="qvalue">${value?'--':Math.round(c.value)}</span>${value?'':'<small>%</small>'}</b><span class="qlines">${qtxt(l1,1)}${l2.full?qtxt(l2,2):''}</span></span>${bar(c)}</div>`;
}
// CKP-ENG-53: the range row, ≈cost first and brightest, then tokens, then speed; the host drops speed and then tokens
// when they do not fit (never a clipped "42/s"). No usage record at all: "quota only" (CKP-ENG-50).
const cap=r=>r==='today'?'Today':r;
function today(col,m){
 const range=m.range||'today';
 const cost=approxCost(col.cost);
 const parts=(cost?`<span class="qcost" title="${esc(t('eng.costHint'))}" aria-label="${esc(cost+' · '+t('eng.costHint'))}">${esc(cost)}</span>`:'')+(col.today==null?'':`<span class="qtokens">${tok(col.today)}</span>`)+(col.speed==null?'':`<span class="qaverage" aria-label="${esc(t('eng.averageAria',{n:col.speed}))}">${Math.round(col.speed)}<em> t/s</em></span>`);
 return `<div class="qrow qrow-t" aria-label="${esc(t(range==='today'?'eng.todayBasis':'eng.rangeBasis'))}">${parts||(col.noUsage?`<span class="qq">${t('eng.noUsage',{r:t('eng.noUsageRange'+cap(range))})}</span>`:col.quotaOnly?`<span class="qq">${t('eng.quotaOnly')}</span>`:'')}</div>`;}
// Within 48 h an expiry reads in whole hours ("40h"), under an hour in minutes.
const expiryLeft = m => m < 60 ? `${Math.max(1,Math.round(m))}m` : `${Math.round(m/60)}h`;
function reserve(col,m,ui){
  const r=col.reserve;if(!r)return '<div class="qrow qrow-r"></div>';
  // D474 §3.1 (CKP-ENG-52, C24, C43): one quiet line, "重置 3 次 · 1 次 40h 后到期" / "重置 1 次 · 点数 1,865". Only the
  // expiry clause is amber, and only for items expiring within 48 h (reserveSoon). Narrow: "3次·40h到期" (en "3 resets ·
  // 1 exp. 40h"); the points drop first. A banked reset confirmed during its news clock adds a plain blue "+1" (C3).
  const narrow=m.cls==='narrow', left=r.warn&&r.firstExpiry!=null?expiryLeft((r.firstExpiry-ui.now)/6e4):null;
  const words=r.cards==null?'':t(r.cards===1?'eng.resetWordOne':'eng.resetsWords',{n:r.cards}),compact=r.cards==null?'':t(r.cards===1?'eng.resetCompactOne':'eng.resetsCompact',{n:r.cards});
  const n=r.expiring||1, exp=left?t('eng.expires',{n,t:left}):'',expShort=left?t('eng.expiresShort',{n,t:left}):'',expSmall=left?t('eng.expiresNarrowest',{n,t:left}):'';
  const plus=r.plus>0?`<b class="qrv-plus" aria-hidden="true" data-news="${esc(r.plusMarks||'')}">+${r.plus}</b>`:'';
  // G3-109: a money balance arrives formatted and escaped; it reads "Balance $12.34", or the value alone when narrow.
  const points=r.money?t('eng.balance',{v:r.money}):r.credits==null?'':t('eng.points',{v:formatCredits(r.credits,ui.lang).replace('<','&lt;')});
  const aria=[words,r.plus>0?t('eng.plusAria',{n:r.plus}):'',exp,points].filter(Boolean).join(' · ');
  const f=(a,b)=>narrow?b:a;
  // The +1 sits beside the count, outside the fitted span (fit() rewrites the span's text).
  // Narrow with an expiry: if even the short pair does not fit, the host drops the count (data-drop) so the clause stays
  // whole ("reset exp. 40h"); the time is never cut.
  const drop=narrow&&left?' data-drop=""':'';
  const cards=(words?`<span class="qrv-c"${drop} data-full="${esc(f(words,compact))}" data-short="${esc(compact)}">${esc(f(words,compact))}</span>`:'')+plus;
  const expiry=left?`<span class="qrv-x warn" data-full="${esc(f(exp,expShort))}" data-short="${esc(expShort)}" data-small="${esc(expSmall)}">${esc(f(exp,expShort))}</span>`:'';
  const pts=points&&!(narrow&&left)?`<span class="qrv-p"${r.money?` data-full="${esc(points)}" data-short="${esc(r.money)}"`:''}>${esc(points)}</span>`:'';
  const sep=d=>`<i class="qrv-sep"${d} aria-hidden="true">${narrow&&ui.lang!=='en'?'·':' · '}</i>`;
  const parts=[cards,expiry,pts].filter(Boolean);
  return `<div class="qrow qrow-r${narrow?' narrow':''}" aria-label="${esc(aria)}">${parts.map((p,i)=>i?sep(i===1&&words&&drop?drop:'')+p:p).join('')}</div>`;
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
const key=col=>`<button class="ek bd-r${col.on?' on':''}${col.off?' off':''}" data-sub="${esc(col.id)}" data-col="${esc(col.id)}" data-mat="part" title="${esc(col.name)}" aria-pressed="${col.on}" aria-label="${esc(t('eng.keyAria',{name:col.name,k:col.key}))}"><span class="ek-identity"><img class="lamp" src="assets/brands/${esc(col.logo)}" alt=""><span class="ek-name" data-full="${esc(col.short)}" data-short="${esc(col.alias||col.short)}" title="${esc(col.name)}">${esc(col.short)}</span></span><i class="bl" style="--v:${esc(col.colour)}"></i><span class="ki">${col.key}</span>${col.news?`<i class="ek-news ${col.news==='confirmed'?'solid':'hollow'}" data-news="${esc(col.newsMarks||'')}" role="img" aria-label="${esc(t(col.news==='confirmed'?'eng.newsConfirmed':'eng.newsAnnounced'))}"></i>`:''}</button>`;
// D417: the third row's heading names what its cells are when every column agrees (MCP, Opus, ...); mixed columns
// carry their own names in the cells and the heading says only that these are extra windows, never a bare "Other".
export function otherHeading(m) {
  const names = new Set(), cells = (m.cols || []).map(c => c && c.cells && c.cells.other).filter(Boolean);
  for (const c of cells) names.add(c.extra && c.named && c.name && [...c.name].length <= 6 && !c.more ? c.name : '');
  return names.size === 1 && cells.length && [...names][0] ? [...names][0] : t('eng.extra');
}
function pageDescription(l,m) { return t('rev49.page',{p:l.page+1,names:(l.accounts||[]).map(a=>a.name+(a.status?' · '+t(a.status==='red'?'eng.lvLow':'eng.lvMid'):'')).join(', '),scope:t(m.scoped?'rev49.pageSub':'rev49.pageAll')}); }

// D376: the pager sits under the 全部 key as "◀ 1/2 ▶" (the fader bank pager, smaller). Another page's amber/red
// subscription (CKP-ENG-03) colours the arrow that points toward it; there are no LEDs.
function pager(m) {
  if (m.pages < 2) return '';
  const rank = l => l === 'red' ? 2 : l === 'amber' ? 1 : 0, level = pages => pages.reduce((best, l) => rank(l.level) > rank(best) ? l.level : best, null);
  const before = level(m.leds.filter(l => l.page < m.page)), after = level(m.leds.filter(l => l.page > m.page));
  const lv = l => l === 'red' ? ' lv-red' : l === 'amber' ? ' lv-amber' : '';
  const aria = [t('eng.pgAria', {p: m.page + 1, n: m.pages}),
    ...m.leds.filter(l => l.level).map(l => t('eng.pgAlert', {p: l.page + 1, lv: t(l.level === 'red' ? 'eng.lvLow' : 'eng.lvMid')}))].join(' · ');
  return `<div class="eng-pg"><button class="key sm eng-pk${lv(before)}" data-bpage="-1" data-mat="part" aria-disabled="${m.page === 0}" aria-label="${t('eng.pgPrevAria')}">◀</button>`
    + `<span class="eng-pgn bank-lcd" data-mat="well" data-page="${m.page}" aria-current="true" role="group" aria-label="${esc(aria)}">${m.page + 1}/${m.pages}</span>`
    + `<button class="key sm eng-pk${lv(after)}" data-bpage="1" data-mat="part" aria-disabled="${m.page === m.pages - 1}" aria-label="${t('eng.pgNextAria')}">▶</button></div>`;
}

export const cautionView = c => `<button class="caution${c.level ? ' lit ' + c.level : ''}${c.flash ? ' flash' : ''}" data-caution data-mat="part" aria-label="${c.level ? t('eng.cautionLitAria') : t('eng.cautionAria')}"><span>ALERT</span></button>`;


export function engineView(m,{changed=new Set(),lang='zh-CN',now=Date.now()}={}){
 const ui={lang,now,used:m.used},n=m.slots;
 const addLabel=esc(t("eng.addSubscription"));
 // CKP-ENG-56 / D95: one add affordance in the first empty bay; paged bays stay blank (CKP-ENG-03).
 const empty=Array.from({length:n-m.cols.length},(_,i)=>emptyColumn(m,m.cols.length+i,addLabel,i===0&&m.pages<2)).join('');
 const emptyKeys=Array.from({length:n-m.cols.length},()=>emptyKey(addLabel)).join('');
 const labels=m.empty?'':m.rows.map(r=>`<span class="lb lb-${r}">${t(r==='other'?otherHeading(m):LABEL[m.rowPeriods[r]]||'eng.other')}</span>`).join('')+`<span class="lb lb-t" aria-label="${esc(t((m.range||'today')==='today'?'eng.todayBasis':'eng.rangeBasis'))}">${t('eng.range'+cap(m.range||'today'))}</span>`+(m.reserve?`<span class="lb lb-r" tabindex="0" aria-label="${esc(t('eng.reserveHint'))}" data-tip="${esc(t('eng.reserveHint'))}">${t('eng.reserve')}</span>`:'');
 const keys=`<div class="eng-krow${m.pages>1?' paged':''}"><button class="ek ek-all${m.scoped?'':' on'}" data-all data-mat="part" aria-pressed="${!m.scoped}" aria-label="${t('eng.allAria')}"><span>${t('eng.all')}</span><i class="bl" aria-hidden="true"></i></button>${pager(m)}<div class="eng-keys" style="--n:${n}">${m.cols.map(key).join('')}${emptyKeys}</div></div>`;
 return `${keys}<div class="eng-lcd cls-${m.cls}${m.rich?' few-rich':''}" data-mat="well" style="--n:${n};--rows:${rowsTemplate(m)}">${m.empty?`<p class="ec-empty">${t('eng.empty')}</p>`:`<div class="eng-labels">${labels}</div><div class="eng-cols">${m.cols.map(col=>column(col,m,ui,changed)).join('')}${empty}</div>`}</div>`;
}
