// SPDX-License-Identifier: MIT
// D466 calendar and time system (calendar-system.md §2, §4; band round 3): the cockpit's time surfaces.
// - The 24 h strip at the right edge of every subscription column: now at the top, +24 h at the bottom; a teal now bar,
//   the peak window in the maker colour, white reset ticks, an amber run-out tick, a blue dot for a timed official reset.
//   No text; always drawn (an empty strip is still the way into the calendar). Its hit area is wider than the 6 pt bar.
// - Its hover card, to the left of the strip: "<name> · 接下来 24 小时", one line per item (or "nothing" and the next two
//   later items), then "7 天日历 ›".
// - The big screen's 日历 tab (the 5th page key): the header range switch picks the view (今天 = the 24 h agenda, 7天 = the
//   week grid with the picked day's word list, 30天 = a dated list), and a chip shows the subscription filter.
// Every word comes from the string tables (strings/calendar.js); the page has no timers (the host's tick redraws it).
import {t} from '../study/rocket-r1/i18n.js';
import '../study/rocket-r1/strings/calendar.js';
import '../study/rocket-r1/strings/plugins.js';
import {dayPieces,hhmm,hourMarks,midnights,addDays,startOfDay,dayOffset,wallHours,monthDay,HOUR} from './calendar-time.js';
import {within,type CalItem,type CalModel} from './calendar-model.js';

type Locale='en'|'zh-CN';
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
const pct=(v:number)=>`${(Math.max(0,Math.min(1,v))*100).toFixed(3)}%`;
const nameOf=(model:CalModel,sub:number,locale:Locale)=>{const s=model.subs[sub];return s?(locale==='en'?s.name.en:s.name.zh).split(' / ')[0]!:'';};
const weekday=(at:number)=>t('plugin.calWd'+new Date(at).getDay());
const dayTitle=(at:number,now:number)=>`${weekday(at)} ${new Date(at).getDate()}`+(dayOffset(now,at)===0?` · ${t('cal.today')}`:'');

/** What an item says, without its time and subscription. */
export function itemWords(x:CalItem,locale:Locale):string {
 switch(x.kind){
  case 'reset5h':return t('cal.reset5h');
  case 'resetWeek':return t('cal.resetWeek');
  case 'resetMonth':return t('cal.resetMonth',{w:x.label?(locale==='en'?x.label.en:x.label.zh):t('cal.monthly')});
  case 'peak':return t(x.tentative?'cal.peakTentative':'cal.peakSpan');
  case 'runout':return t('cal.runOut');
  case 'official':return t(x.status==='confirmed'?'cal.officialConf':'cal.officialAnn');
  case 'credit':return t(x.status==='confirmed'?'cal.creditConf':'cal.creditAnn');
  case 'reserve':return t('cal.reserveLine');
 }
}
/** The time column of a line: "13:04", "22:00–02:00", or "全天". */
export function itemTime(x:CalItem):string {
 if(x.allDay)return t('cal.allDay');
 return x.kind==='peak'?`${hhmm(x.at)}–${x.end===null?'…':hhmm(x.end)}`:hhmm(x.at);
}
const tone=(x:CalItem)=>x.kind==='peak'?'peak':x.kind==='runout'?'warn':x.kind==='official'||x.kind==='credit'?(x.news?'news':'past'):x.kind==='reserve'?'reserve':'reset';

// --- the 24 h strip ------------------------------------------------------------------------------------------------
/** Draws the strip of subscription `sub` into `column` (replacing an earlier one). */
export function paintStrip(column:HTMLElement,model:CalModel,sub:number,locale:Locale):HTMLButtonElement {
 column.querySelector(':scope > .ec-strip')?.remove();
 const now=model.now,span={from:now,to:now+24*HOUR},Y=(at:number)=>(at-span.from)/(span.to-span.from);
 const hit=el('button','ec-strip');hit.type='button';hit.dataset.strip=String(sub);
 hit.setAttribute('aria-label',t('cal.stripAria',{s:nameOf(model,sub,locale)}));
 const bar=el('span','ec-strip-bar');bar.setAttribute('aria-hidden','true');hit.append(bar);
 const mark=(className:string,at:number,end?:number)=>{const m=el('i',className);m.style.top=pct(Y(at));if(end!==undefined)m.style.height=pct(Y(end)-Y(at));bar.append(m);return m;};
 for(const h of hourMarks(span,6))if(h.hour!==0)mark('st-h',h.at);
 for(const m of midnights(span))mark('st-mid',m);
 const own=within(model.items,span.from,span.to).filter(x=>x.sub===sub&&!x.allDay);
 for(const x of own){
  if(x.kind==='peak'){const p=mark('st-peak'+(x.tentative?' tent':''),Math.max(x.at,span.from),Math.min(x.end??span.to,span.to));p.style.setProperty('--c',model.subs[sub]!.colour);}
  else if(x.kind==='runout')mark('st-run',x.at);
  else if(x.kind==='official'||x.kind==='credit')mark('st-off',x.at);
  else mark('st-reset',x.at);
 }
 mark('st-now',now);
 column.append(hit);hit.dataset.marks=String(own.length);
 return hit;
}
/** The hover card's lines for one subscription: the next 24 h, else "nothing" and the next two items after it. */
export function nextLines(model:CalModel,sub:number,locale:Locale):{title:string;now:string|null;lines:{time:string;text:string;tone:string}[];empty:boolean} {
 const now=model.now,s=model.subs[sub]!,mine=model.items.filter(x=>x.sub===sub&&!x.allDay&&!x.projected);
 const soon=within(mine,now,now+24*HOUR).sort((a,b)=>a.at-b.at),line=(x:CalItem)=>({time:itemTime(x),text:itemWords(x,locale),tone:tone(x)});
 let state:string|null=null;
 if(s.rules){const live=mine.find(x=>x.kind==='peak'&&x.at<=now&&(x.end===null||x.end>now));state=live?t('cal.inPeak',{t:live.end===null?'…':hhmm(live.end)}):t('cal.offPeak');}
 const upcoming=soon.filter(x=>!(x.kind==='peak'&&x.at<=now));
 if(upcoming.length)return {title:t('cal.next24',{s:nameOf(model,sub,locale)}),now:state,lines:upcoming.slice(0,6).map(line),empty:false};
 const later=mine.filter(x=>x.at>=now+24*HOUR).sort((a,b)=>a.at-b.at).slice(0,2).map(x=>({...line(x),time:`${weekday(x.at)} ${itemTime(x)}`}));
 return {title:t('cal.next24',{s:nameOf(model,sub,locale)}),now:state,lines:later,empty:true};
}
/** The hover card for a strip, placed to the left of `anchor` inside `host` (the cockpit), with its "7 天日历 ›" link. */
export function stripCard(host:HTMLElement,anchor:HTMLElement,model:CalModel,sub:number,locale:Locale,open:()=>void):HTMLElement {
 host.querySelector(':scope > .ec-next')?.remove();
 const n=nextLines(model,sub,locale),card=el('div','ec-next mfd-tip');card.setAttribute('role','dialog');card.setAttribute('aria-label',n.title);
 card.append(el('span','h',n.title));
 if(n.now){const r=el('span','ln now');r.append(el('b','',`${t('cal.nowLabel')} ${hhmm(model.now)}`),el('em','',n.now));card.append(r);}
 if(n.empty)card.append(el('span','ln quiet',t('cal.nothing24')));
 for(const [i,x] of n.lines.entries()){const r=el('span','ln '+x.tone);r.append(el('b','',(n.empty&&!i?`${t('cal.later')} `:'')+x.time),el('em','',x.text));card.append(r);}
 const link=el('button','ln link',t('cal.open7'));link.type='button';link.onclick=e=>{if(e.isTrusted)open();};card.append(link);
 host.append(card);
 const box=host.getBoundingClientRect(),r=anchor.getBoundingClientRect(),w=card.offsetWidth,h=card.offsetHeight;
 card.style.left=`${Math.max(4,r.left-box.left-w-6)}px`;card.style.top=`${Math.max(4,Math.min(box.height-h-4,r.top-box.top+8))}px`;
 return card;
}

// --- the big screen's 日历 tab ---------------------------------------------------------------------------------------
export interface CalendarPageOptions {
 readonly locale:Locale;readonly range:'today'|'7d'|'30d';
 /** The "只看 X" filter's subscription key, or null for all. */
 readonly filter:string|null;readonly filterName:string|null;
 /** The 7-day view's picked day (0 = today). */
 readonly day:number;
 clearFilter():void;pickDay(day:number):void;wider():void;
}
export function paintCalendarPage(page:HTMLElement,model:CalModel,o:CalendarPageOptions):void {
 const box=el('div','cal-page');box.dataset.view=o.range;page.replaceChildren(box);
 const head=el('div','cal-head');
 if(o.filter!==null&&o.filterName){const chip=el('button','cal-chip on');chip.type='button';chip.dataset.calFilter=o.filter;chip.append(el('span','',t('cal.only',{s:o.filterName})),el('b','','✕'));chip.setAttribute('aria-label',`${t('cal.only',{s:o.filterName})} · ${t('cal.onlyClear')}`);const colour=model.subs[0]?.colour;if(colour&&/^#[0-9a-f]{6}$/i.test(colour))chip.style.setProperty('--c',colour);chip.onclick=e=>{if(e.isTrusted)o.clearFilter();};head.append(chip);}
 else head.append(el('span','cal-chip',t('cal.all')));
 box.append(head);
 if(o.range==='today')agenda(box,head,model,o);else if(o.range==='7d')week(box,head,model,o);else list(box,head,model,o);
}
function newsLine(box:HTMLElement,model:CalModel,o:CalendarPageOptions){
 const news=model.items.filter(x=>x.news);if(!news.length)return;
 const x=news[news.length-1]!,line=el('p','cal-news');line.append(el('i','al-dot '+(x.status==='confirmed'?'solid':'hollow')),el('span','',`${nameOf(model,x.sub,o.locale)} ${itemWords(x,o.locale)} · ${x.allDay?monthDay(x.at):hhmm(x.at)}`));
 box.append(line);
}
/** 今天: the strips enlarged, one lane per subscription, with one line of words per item at its time. */
function agenda(box:HTMLElement,head:HTMLElement,model:CalModel,o:CalendarPageOptions){
 const now=model.now,span={from:now,to:now+24*HOUR},Y=(at:number)=>(at-span.from)/(span.to-span.from);
 head.append(el('span','cal-range',t('cal.span24',{a:`${weekday(now)} ${hhmm(now)}`,b:`${weekday(span.to)} ${hhmm(span.to)}`})));
 newsLine(box,model,o);
 const body=el('div','cal-ag'),axis=el('div','ag-axis'),lanes=el('div','ag-lanes'),words=el('div','ag-words');lanes.style.setProperty('--n',String(model.subs.length));
 for(const h of hourMarks(span,6)){const g=el('i','ag-h',h.hour===0?`00 ${weekday(h.at)}`:String(h.hour).padStart(2,'0'));g.style.top=pct(Y(h.at));axis.append(g);}
 model.subs.forEach((s,i)=>{const lane=el('div','ag-lane');lane.dataset.sub=String(i);lane.title=nameOf(model,i,o.locale);
  for(const x of within(model.items,span.from,span.to).filter(x=>x.sub===i&&!x.allDay)){
   const m=el('i',x.kind==='peak'?'st-peak':x.kind==='runout'?'st-run':x.kind==='official'||x.kind==='credit'?'st-off':'st-reset');
   m.style.top=pct(Y(Math.max(x.at,span.from)));if(x.kind==='peak'){m.style.height=pct(Y(Math.min(x.end??span.to,span.to))-Y(Math.max(x.at,span.from)));m.style.setProperty('--c',s.colour);}lane.append(m);
  }
  const nowBar=el('i','st-now');nowBar.style.top='0%';lane.append(nowBar);lanes.append(lane);});
 const many=model.subs.length>1;
 const lines:{y:number;e:HTMLElement}[]=[];
 const state=model.subs.map((s,i)=>s.rules?nextLines(model,i,o.locale).now:null);
 const nowLine=el('p','ag-w now');nowLine.append(el('b','',`${t('cal.nowLabel')} ${hhmm(now)}`),el('span','',state.map((v,i)=>v?`${many?nameOf(model,i,o.locale)+' ':''}${v}`:'').filter(Boolean).join(' · ')));
 lines.push({y:0,e:nowLine});
 for(const x of within(model.items,span.from,span.to).filter(x=>!x.allDay&&!(x.kind==='peak'&&x.at<=now))){
  const p=el('p','ag-w '+tone(x));p.append(el('b','',itemTime(x)),el('span','',`${many?nameOf(model,x.sub,o.locale)+' ':''}${itemWords(x,o.locale)}`));lines.push({y:Y(x.at),e:p});
  if(x.kind==='peak'&&x.end!==null&&x.end<span.to){const q=el('p','ag-w reset');q.append(el('b','',hhmm(x.end)),el('span','',`${many?nameOf(model,x.sub,o.locale)+' ':''}${t('cal.offPeakAt')}`));lines.push({y:Y(x.end),e:q});}
 }
 lines.sort((a,b)=>a.y-b.y);for(const l of lines){l.e.dataset.y=String(l.y);words.append(l.e);}
 body.append(axis,lanes,words);box.append(body);
 // Beyond 24 h, folded into one line, with the way to the week.
 const later=model.items.filter(x=>!x.allDay&&!x.projected&&x.at>=span.to&&x.kind!=='peak').slice(0,1);// one line: the soonest; the week has the rest
 const foot=el('div','cal-later');foot.append(el('b','',t('cal.later')));
 for(const x of later)foot.append(el('span',tone(x),`${weekday(x.at)} ${hhmm(x.at)} ${many?nameOf(model,x.sub,o.locale)+' ':''}${itemWords(x,o.locale)}`));
 const more=el('button','cal-more','7d ›');more.type='button';more.onclick=e=>{if(e.isTrusted)o.wider();};foot.append(more);box.append(foot);
 settle(words);
}
/** Lines placed at their time never overlap: one that would sit on the one above moves down (measured once drawn). */
function settle(words:HTMLElement){
 const h=words.clientHeight||150,rows=[...words.children] as HTMLElement[],lh=12;
 const ys=rows.map(r=>Number(r.dataset.y)*h-lh/2);
 for(let i=0;i<ys.length;i++)ys[i]=Math.max(ys[i]!,i?ys[i-1]!+lh:0);
 for(let i=ys.length-1;i>=0;i--)ys[i]=Math.max(0,Math.min(ys[i]!,i===ys.length-1?h-lh:ys[i+1]!-lh));
 rows.forEach((r,i)=>{r.style.top=`${ys[i]!.toFixed(1)}px`;});
}
const DAYS=7;
/** 7天: day headers, one all-day row of chips, a 0–24 grid, and the picked day as a word list (website CalendarAgenda). */
function week(box:HTMLElement,head:HTMLElement,model:CalModel,o:CalendarPageOptions){
 const now=model.now,today=startOfDay(now),end=addDays(today,DAYS),pick=Math.max(0,Math.min(DAYS-1,o.day));
 head.append(el('span','cal-range',`${monthDay(today)} – ${monthDay(addDays(today,DAYS-1))}`));
 const grid=el('div','cal-wk7'),days=el('div','w7-days'),allDay=el('div','w7-ad'),body=el('div','w7-body');
 allDay.append(el('span','w7-adl',t('cal.allDay')));body.append(el('i','w7-g g0'),el('i','w7-g g6'),el('i','w7-g g12'),el('i','w7-g g18'));
 for(const [h,label] of [[0,'00'],[6,'06'],[12,'12'],[18,'18']] as const){const l=el('i','w7-hl',label);l.style.top=pct(h/24);body.append(l);}
 const col=(i:number)=>`calc(var(--w7-g) + (100% - var(--w7-g)) * ${i/DAYS})`,colW=`calc((100% - var(--w7-g)) / ${DAYS})`;
 const place=(e:HTMLElement,i:number)=>{e.style.left=col(i);e.style.width=colW;};
 for(let i=0;i<DAYS;i++){
  const at=addDays(today,i),b=el('button','w7-dh'+(i===0?' today':'')+(i===pick?' sel':''));b.type='button';b.dataset.day=String(i);place(b,i);
  b.append(el('i','',weekday(at)),el('b','',String(new Date(at).getDate())));b.setAttribute('aria-pressed',String(i===pick));b.onclick=e=>{if(e.isTrusted)o.pickDay(i);};days.append(b);
  const c=el('div','w7-col'+(i===pick?' sel':''));place(c,i);body.append(c);
 }
 const inWeek=model.items.filter(x=>x.kind==='peak'?x.at<end&&(x.end??x.at+HOUR)>today:x.at>=today&&x.at<end);
 // All-day: one chip on the day that matters (banked reset on its issue day, reserve on its expiry, an untimed
 // announcement on its day); never a bar. Chips of one day stack.
 const lanes=new Array<number>(DAYS).fill(0);
 for(const x of inWeek.filter(x=>x.allDay)){
  const i=dayOffset(now,x.at);if(i<0||i>=DAYS)continue;
  const chip=el('span','w7-chip '+x.kind+(x.news?' news':x.kind==='official'||x.kind==='credit'?' past':''),x.kind==='reserve'?t('cal.reserveChip'):x.kind==='credit'?t('cal.creditChip'):t('cal.officialChip'));
  chip.style.setProperty('--c',model.subs[x.sub]!.colour);place(chip,i);if(lanes[i])chip.style.top=`${1+lanes[i]!*13}px`;lanes[i]!++;
  chip.title=`${nameOf(model,x.sub,o.locale)} ${itemWords(x,o.locale)}`;allDay.append(chip);
 }
 if(Math.max(...lanes)>1)allDay.style.height=`${3+13*Math.max(...lanes)}px`;
 // Peaks: maker-colour blocks, split at local midnights; overlapping subscriptions share the day's width.
 const peaks=inWeek.filter(x=>x.kind==='peak');
 for(const x of peaks)for(const piece of dayPieces(Math.max(x.at,today),x.end??Math.max(x.at+HOUR,now),today,DAYS)){
  const b=el('i','w7-pk'+(x.tentative?' tent':''));b.style.setProperty('--c',model.subs[x.sub]!.colour);b.style.top=pct(piece.start/24);b.style.height=pct((piece.end-piece.start)/24);
  const share=model.subs.length>1?model.subs.length:1;
  b.style.left=`calc(${col(piece.day)} + 2px + (${colW} - 4px) * ${x.sub/share})`;b.style.width=`calc((${colW} - 4px) / ${share})`;
  b.title=`${nameOf(model,x.sub,o.locale)} ${itemWords(x,o.locale)} ${itemTime(x)}`;body.append(b);
 }
 // Resets: small rounded chips with a maker bar ("13:04", "每周"); today's next 5-hour reset only. Run-out: amber dashed line.
 const next5=new Set<string>();
 for(const x of inWeek.filter(x=>!x.allDay&&x.kind!=='peak')){
  const i=dayOffset(now,x.at);if(i<0||i>=DAYS)continue;
  if(x.kind==='reset5h'){if(i!==0||next5.has(String(x.sub)))continue;next5.add(String(x.sub));}
  if(x.kind==='runout'){const line=el('i','w7-run');line.style.top=pct(wallHours(x.at)/24);place(line,i);line.title=`${nameOf(model,x.sub,o.locale)} ${itemWords(x,o.locale)} ${hhmm(x.at)}`;body.append(line);continue;}
  const chip=el('span','w7-rc '+x.kind+(x.kind==='official'||x.kind==='credit'?(x.news?' news':' past'):''),x.kind==='resetWeek'?t('cal.weekChip'):x.kind==='resetMonth'?(x.label?(o.locale==='en'?x.label.en:x.label.zh):t('cal.monthly')):hhmm(x.at));
  chip.style.setProperty('--c',model.subs[x.sub]!.colour);chip.style.top=pct(wallHours(x.at)/24);chip.style.left=`calc(${col(i)} + 2px)`;chip.style.maxWidth=`calc(${colW} - 4px)`;
  chip.title=`${nameOf(model,x.sub,o.locale)} ${itemWords(x,o.locale)} ${hhmm(x.at)}`;body.append(chip);
 }
 const nowLine=el('i','w7-now');nowLine.style.top=pct(wallHours(now)/24);place(nowLine,0);body.append(nowLine);
 grid.append(days,allDay,body);box.append(grid);
 // The picked day in words: all-day items first, then by time.
 const from=addDays(today,pick),to=addDays(today,pick+1),many=model.subs.length>1;
 const listBox=el('div','w7-list');listBox.append(el('p','w7-lh',dayTitle(from,now)));
 const dayItems=within(model.items,from,to).filter(x=>!(x.kind==='reset5h'&&pick>0)).sort((a,b)=>Number(b.allDay)-Number(a.allDay)||a.at-b.at);
 const seen5=new Set<number>();
 for(const x of dayItems){if(x.kind==='reset5h'){if(seen5.has(x.sub))continue;seen5.add(x.sub);}
  const p=el('p','w7-li '+tone(x));const mark=el('i','w7-sw');mark.style.background=model.subs[x.sub]!.colour;p.append(mark,el('b','',x.kind==='peak'&&x.at<from?`… – ${x.end===null?'…':hhmm(x.end)}`:itemTime(x)),el('span','',`${many?nameOf(model,x.sub,o.locale)+' ':''}${itemWords(x,o.locale)}`));listBox.append(p);}
 if(!dayItems.length)listBox.append(el('p','w7-li quiet',t('cal.nothingDay')));
 box.append(listBox);
}
/** 30天: a list grouped by date: monthly and weekly resets, reserve expiries and announcements. */
function list(box:HTMLElement,head:HTMLElement,model:CalModel,o:CalendarPageOptions){
 const now=model.now,today=startOfDay(now),end=addDays(today,30),many=model.subs.length>1;
 head.append(el('span','cal-range',`${monthDay(today)} – ${monthDay(addDays(today,29))}`));
 const items=model.items.filter(x=>x.at>=today&&x.at<end&&['resetMonth','resetWeek','reserve','official','credit'].includes(x.kind)).sort((a,b)=>a.at-b.at||Number(b.allDay)-Number(a.allDay));
 const out=el('div','cal-30');let day=-1;
 for(const x of items){
  const d=startOfDay(x.at);if(d!==day){day=d;out.append(el('p','c30-d',`${monthDay(d)} ${dayTitle(d,now)}`));}
  const p=el('p','c30-li '+tone(x));const mark=el('i','w7-sw');mark.style.background=model.subs[x.sub]!.colour;p.append(mark,el('b','',itemTime(x)),el('span','',`${many?nameOf(model,x.sub,o.locale)+' ':''}${itemWords(x,o.locale)}`));out.append(p);
 }
 if(!items.length)out.append(el('p','c30-li quiet',t('cal.nothingRange')));
 box.append(out);
}
