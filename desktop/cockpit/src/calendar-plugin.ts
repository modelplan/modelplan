// SPDX-License-Identifier: MIT
// v1.1 cockpit calendar plugin (owner D137, D145, D293, D323, D328; CKP-PLG-06/07).
// The column draws only the next 12 hours from now: an all-day line (at most one), peak blocks in the subscription's
// colour, the user's own reset capsules (time only) and the now line. Other days go through the week view: a day pressed
// there swaps the column's bottom line to that day's events. A user with no peak rules gets the D293 cells instead of the
// strip (no `draw`). The plugin key opens the 7-day week view as the plugin's big screen inside the MFD screen.
// Owner D323: both are custom draws (the framework's `draw` hook). The key, its underline, the bottom line, the screen's
// title bar and the lifecycle stay the framework's. If a draw fails, the column falls back to the cells and the screen to
// plain lines.
// All times are local. The page has no timers: the host's minute tick moves the now line and rolls the day over.
import {PLUGIN_ICON_FRAME,type CockpitPlugin,type PluginCell,type PluginColumn,type PluginContext,type PluginDrawContext,type PluginLocale} from './plugin-registry.js';
import {CALENDAR_MAX_BYTES,calendarFromCockpit,emptyCalendar,parseCalendarData,shortName,type CalendarData,type CalendarSpan} from './calendar-data.js';
import {HOUR,WEEK_DAYS,addDays,dayOffset,dayPieces,dayWindow,hhmm,hourMarks,isWeekend,midnights,monthDay,nextMinute,packLanes,startOfDay,stripWindow,wallHours} from './calendar-time.js';

// Every word the calendar draws comes from the plugin string table (strings/plugins.js, `plugin.cal*`), in the locale
// of the draw context; nothing here picks a language's text inline.
const WORDS=['now','allDay','peak','cont','r5','week5','weekly','weeklyLong','wk','cards','direct','until','announced','confirmed','effective','empty','waiting','zoomed','tentative','announcedOn','winWeek','win5'] as const;
type Words={readonly [k in typeof WORDS[number]]:string}&{readonly days:readonly string[];readonly weekdays:readonly string[];readonly narrow:readonly string[]};
function wordsOf(context:PluginContext):Words {
 const word=(key:string)=>context.words('plugin.'+key).full,out:Record<string,unknown>={};
 for(const k of WORDS)out[k]=word('cal'+k[0]!.toUpperCase()+k.slice(1));
 out.days=[0,1,2].map(i=>word('calDay'+i));out.weekdays=[0,1,2,3,4,5,6].map(i=>word('calWd'+i));out.narrow=[0,1,2,3,4,5,6].map(i=>word('calWn'+i));
 return out as Words;
}
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
const pct=(v:number)=>`${(Math.max(0,Math.min(1,v))*100).toFixed(3)}%`;

/** View state (the framework's per-plugin `memo`, shared by the column and the screen): the picked day (null = today),
 *  the week zoom and its centre hour. Readings are the framework's state (`accept`), not kept here. */
interface View {day:number|null;zoom:number;centre:number|null}
const viewOf=(memo:Record<string,unknown>)=>{let v=memo.view as View|undefined;if(!v){v={day:null,zoom:24,centre:null};memo.view=v;}return v;};
/** A button the framework keeps focused across redraws (D323 `data-focus`). */
const button=(className:string,focus:string,text?:string)=>{const b=el('button',className,text);b.type='button';b.dataset.focus=focus;return b;};

// --- shared labels -----------------------------------------------------------------------------------------------
const weekday=(t:number,w:Words,narrow=false)=>(narrow?w.narrow:w.weekdays)[new Date(t).getDay()]!;
const dayLabel=(t:number,w:Words,zh:boolean)=>zh?`${monthDay(t)} ${weekday(t,w)}`:`${weekday(t,w)} ${monthDay(t)}`;
/** A reset's day prefix in the fallback cell: none today, 明/后 (Tmr/weekday) on later days. */
function dayPrefix(at:number,now:number,w:Words,zh:boolean){const d=dayOffset(now,at);return d<=0?'':zh?(d<3?w.days[d]!:`${monthDay(at)} `):d===1?`${w.days[1]} `:`${weekday(at,w)} `;}
function resetText(abbr:string,kind:'5h'|'week',at:number,prefix:string,w:Words,long=false){
 const what=kind==='5h'?(long?w.week5:w.r5):(long?w.weeklyLong:w.weekly);return `${abbr} ${what} ${prefix}${hhmm(at)}`;
}
function spanText(data:CalendarData,s:CalendarSpan,w:Words,zh:boolean,full=false){
 const sub=data.subs[s.sub]!,name=full?(zh?sub.name.zh:sub.name.en):shortName(zh?sub.name.zh:sub.name.en);
 if(s.kind==='cards'){const n=s.count&&s.count>1?` ×${s.count}`:'';
  // No expiry known (a partial list, or none given): no date, never an epoch (macrevc-844-6).
  if(s.to===null)return `${name} ${w.cards}${n}`;
  return zh?`${name} ${w.cards}${n} ${w.until}${monthDay(s.to!)}`:`${name} ${w.cards}${n} · ${w.until} ${monthDay(s.to!)}`;}
 if(s.kind==='credit')return `${name} +1 ${w.cards}`;
 const what=s.kind==='confirmed'?w.confirmed:w.announced;
 if(s.to===null)return `${name} ${what}`;
 return zh?`${name} ${what} · ${monthDay(s.to)} ${w.effective}`:`${name} ${what} · ${monthDay(s.to)}`;
}
const peakTitle=(data:CalendarData,p:{sub:number;from:number;to:number|null;tentative:boolean},w:Words,zh:boolean)=>`${nameOf(data,p.sub,zh)} ${w.peak} ${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}${p.tentative?` · ${w.tentative}`:''}`;
/** The name the calendar writes for a subscription (D375): its full name in the locale, kept short for narrow places. */
const nameOf=(data:CalendarData,sub:number,zh:boolean)=>{const s=data.subs[sub]!;return shortName(zh?s.name.zh:s.name.en);};
const colourOf=(data:CalendarData,sub:number)=>data.subs[sub]?.colour??'#c6ccd4';

// --- the column (the next 12 hours) ------------------------------------------------------------------------------
function paintStrip(context:PluginDrawContext,reading:CalendarData) {
 const w=wordsOf(context),zh=context.locale==='zh-CN',now=context.now;
 const panel=el('div','cal');context.area.append(panel);
 // No host time yet (the first draw comes before the first display data): nothing to place.
 if(!now){panel.dataset.view='waiting';panel.replaceChildren(el('p','cal-empty',w.waiting));return;}
 panel.dataset.view='now';
 const data=reading,span=stripWindow(now);
 // All-day: at most one line (reset cards, announced resets); the rest is a "+N" on it.
 const allDay=el('div','cal-ad'),rows=data.spans.filter(x=>x.from<span.to&&(x.to===null||x.to>=span.from));
 allDay.append(el('span','cal-adl',w.allDay));
 if(rows.length){
  const x=rows[0]!,sub=data.subs[x.sub]!,row=el('div','cal-adr '+(x.kind==='cards'?'bar':'line'));row.style.setProperty('--c',sub.colour);row.title=spanText(data,x,w,zh,true);
  row.append(el('span','',spanText(data,x,w,zh)+(rows.length>1?` +${rows.length-1}`:'')));allDay.append(row);
 }else allDay.classList.add('none');
 // The axis: linear in real time over the 12 hours from now.
 const axis=el('div','cal-ax'),len=span.to-span.from,Y=(t:number)=>(t-span.from)/len;
 panel.replaceChildren(allDay,axis);
 // Hour labels at the smallest step (1, 2, 3 or 6 h) that leaves 13 px between them.
 const H=axis.clientHeight||160,pxHour=H/(len/HOUR),every=[1,2,3,6].find(n=>pxHour*n>=13)??6;
 for(const m of hourMarks(span,every)){if(m.hour===0)continue;const g=el('div','cal-g');g.style.top=pct(Y(m.at));g.append(el('i','',String(m.hour).padStart(2,'0')));axis.append(g);}
 for(const m of midnights(span)){const line=el('div','cal-mid');line.style.top=pct(Y(m));line.append(el('b','',w.days[Math.max(0,Math.min(2,dayOffset(now,m)))]!));axis.append(line);}
 // Peaks: one line each ("GL 22:00–02:00", or "GL until 02:00" while it runs).
 const pieces=data.peaks.flatMap(p=>{const a=Math.max(p.from,span.from),b=Math.min(p.to??span.to,span.to);return a<b?[{p,start:a,end:b}]:[];});
 for(const {item,lane,lanes} of packLanes(pieces)){
  const {p,start,end}=item,block=el('div','cal-pk'+(p.tentative?' tent':''));block.style.setProperty('--c',colourOf(data,p.sub));
  block.style.top=pct(Y(start));block.style.height=pct(Y(end)-Y(start));
  block.style.left=`calc(var(--cal-g) + (100% - var(--cal-g) - 2px) * ${lane/lanes})`;block.style.width=`calc((100% - var(--cal-g) - 2px) / ${lanes} - 2px)`;
  const abbr=nameOf(data,p.sub,zh),live=p.from<=now,stop=p.to===null?'…':hhmm(p.to);
  block.title=peakTitle(data,p,w,zh);
  // G3-179 (owner 11-22, shot 142331): a six-column cockpit leaves the block ~45 px, so "GL 09:00–…" clipped to
  // "GL 09:…". The time is the block's fact (D375: cells lead with the big time), so the abbreviation drops first,
  // then the end, before any of it clips. The tooltip keeps the whole sentence.
  const label=live?(p.to===null?[`${abbr} ${w.peak}`,w.peak]:[`${abbr} ${w.until} ${stop}`,`${w.until} ${stop}`,stop]):[`${abbr} ${hhmm(p.from)}–${stop}`,`${hhmm(p.from)}–${stop}`,hhmm(p.from)];
  const text=el('b','',label[0]!);block.append(text);axis.append(block);
  for(let i=1;i<label.length&&text.scrollWidth>text.clientWidth;i++)text.textContent=label[i]!;
  // G3-179 (sampling 11-22): a split lane can stay narrower than even HH:MM, and a block with less than one line of
  // height (the strip's end) clips its text vertically. The time then leaves the lane: a tag on the axis in the
  // peak's colour, settled with the reset chips so tags never cover each other; the block keeps its tooltip.
  if(text.scrollWidth>text.clientWidth||block.clientHeight<12){
   text.remove();
   const tag=el('div','cal-pkt');tag.style.setProperty('--c',colourOf(data,p.sub));
   tag.dataset.y=String(Y(start));tag.textContent=label[label.length-1]!;tag.title=block.title;
   axis.append(tag);
  }
 }
 // The user's own resets: capsules with the time only after the subscription and kind ("CL 周 09:00").
 const chips=data.resets.filter(r=>r.at>=span.from&&r.at<span.to);
 for(const r of chips){
  const c=el('div','cal-ch'+(r.kind==='week'?' wk':'')),sub=data.subs[r.sub]!;c.style.setProperty('--c',sub.colour);c.dataset.y=String(Y(r.at));c.style.top=pct(Y(r.at));
  // Name + window + time; a narrow column drops the window (D375). The chip's colour and the name appear together.
  const wide=(context.width||0)>=100;c.textContent=`${nameOf(data,r.sub,zh)} ${wide?`${r.kind==='5h'?w.r5:w.wk} `:''}${hhmm(r.at)}`;c.title=`${zh?sub.name.zh:sub.name.en} · ${resetText(zh?sub.name.zh:sub.name.en,r.kind,r.at,'',w,true)} · ${dayLabel(r.at,w,zh)}`;axis.append(c);
 }
 // Now: the line, with the time in the gutter to its left.
 const line=el('div','cal-nl');line.style.top='0%';axis.append(line,el('div','cal-nt',hhmm(now)));
 if(!pieces.length&&!chips.length&&!rows.length)axis.append(el('p','cal-empty',w.empty));
 settleChips(axis);
}
/** Reset chips and moved-out peak times never overlap: one that would sit on the one above moves down (the axis is
 *  measured when drawn). */
function settleChips(axis:HTMLElement) {
 const h=axis.clientHeight||160,chips=[...axis.querySelectorAll<HTMLElement>('.cal-ch,.cal-pkt')].sort((a,b)=>Number(a.dataset.y)-Number(b.dataset.y)),ch=12,gap=1;
 const ys=chips.map(c=>Number(c.dataset.y)*h-ch/2);
 for(let i=0;i<ys.length;i++)ys[i]=Math.max(ys[i]!,i?ys[i-1]!+ch+gap:0);
 // Pushed past the bottom: settle upwards from the end instead (they only overlap when the axis cannot hold them all).
 for(let i=ys.length-1;i>=0;i--)ys[i]=Math.max(0,Math.min(ys[i]!,i===ys.length-1?h-ch:ys[i+1]!-ch-gap));
 chips.forEach((c,i)=>{c.style.top=`${ys[i]!.toFixed(1)}px`;});
}
/** "2h50", "35m": a duration the way the bottom line writes it. */
export const duration=(ms:number)=>{const m=Math.max(0,Math.round(ms/60_000)),h=Math.floor(m/60);return h?`${h}h${String(m%60).padStart(2,'0')}`:`${m}m`;};
/** What the week view's picked day holds, for the bottom line: its resets and peaks in time order, one short phrase each. */
export function dayEvents(data:CalendarData,day:number,w:Words,zh=false):string[] {
 const {from,to}=dayWindow(day),inside=(t:number)=>t>=from&&t<to;
 return [
  ...data.resets.filter(r=>inside(r.at)).map(r=>({at:r.at,text:`${nameOf(data,r.sub,zh)} ${r.kind==='5h'?w.r5:w.wk} ${hhmm(r.at)}`})),
  ...data.peaks.filter(p=>inside(p.from)).map(p=>({at:p.from,text:`${nameOf(data,p.sub,zh)} ${w.peak} ${hhmm(p.from)}`})),
 ].sort((a,b)=>a.at-b.at).map(x=>x.text);
}
/** The bottom line (D328): the picked day's events, else the peak now / the next peak, else "no peak rules". */
function footOf(data:CalendarData|null,context:PluginContext):PluginColumn['foot'] {
 if(!data||!context.now)return null;
 const now=context.now,w=wordsOf(context),zh=context.locale==='zh-CN',view=context.memo?viewOf(context.memo):null;
 if(view&&view.day!==null&&dayOffset(now,view.day)<=0)view.day=null;// the day rolled over: back to now
 if(view&&view.day!==null){
  const list=dayEvents(data,view.day,w,zh).join(' · ')||context.words('plugin.calendarNone').full;
  return {label:{full:dayLabel(view.day,w,zh),short:monthDay(view.day)},value:{full:list,short:list}};
 }
 if(!data.peaks.length)return {label:context.words('plugin.calPeakLabel'),value:context.words(data.peakRules==='no'?'plugin.calNoRules':data.peakRules==='yes'?'plugin.calendarNone':'plugin.calPeaksUnknown')};
 const live=data.peaks.find(p=>p.from<=now&&(p.to===null||p.to>now));
 if(live)return {label:context.words('plugin.calPeakNow',{a:nameOf(data,live.sub,zh)}),value:live.to===null?null:context.words('plugin.calLeft',{t:duration(live.to-now)})};
 const next=data.peaks.filter(p=>p.from>now).sort((a,b)=>a.from-b.from)[0];
 return next?{label:context.words('plugin.calendarPeak'),value:context.words('plugin.calIn',{t:duration(next.from-now)})}:{label:context.words('plugin.calPeakLabel'),value:context.words('plugin.calendarNone')};
}

// --- the week view (the plugin's big screen on the MFD) -------------------------------------------------------------
const ZOOMS=[24,16,12,8] as const;
interface WeekItem {day:number;start:number;end:number;label:string;kind:'peak'|'chip'}
function paintWeek(context:PluginDrawContext,reading:CalendarData|null) {
 const s=viewOf(context.memo),w=wordsOf(context),zh=context.locale==='zh-CN',now=context.now,data=reading??emptyCalendar,today=startOfDay(now);
 if(context.opening){s.zoom=24;s.centre=null;}
 const narrow=(context.width||600)<450,zoom=s.zoom,fit=zoom>=24;
 const body=el('div','cal-wk'+(narrow?' narrow':'')+(fit?' fit':' zoom'));context.area.append(body);
 const status=el('span','wk-zoom',fit?'':w.zoomed);status.classList.toggle('on',!fit);
 const redraw=()=>context.redraw();
 // ⌘+ / ⌘− / ⌘0 zoom while focus is inside the week view (the framework keeps Esc for closing the screen).
 context.area.onkeydown=e=>{
  if(!e.isTrusted||!(e.metaKey||e.ctrlKey)||e.altKey)return;
  const step=e.key==='+'||e.key==='='?1:e.key==='-'||e.key==='_'?-1:e.key==='0'?0:null;if(step===null)return;
  e.preventDefault();e.stopPropagation();if(step===0){s.zoom=24;redraw();}else zoomBy(step,s,redraw);
 };
 const col=(i:number)=>`calc(var(--wk-g) + (100% - var(--wk-g) - var(--wk-r)) * ${i/WEEK_DAYS})`,colW=`calc((100% - var(--wk-g) - var(--wk-r)) / ${WEEK_DAYS})`;
 const place=(e:HTMLElement,i:number,span=1)=>{e.style.left=col(i);e.style.width=span===1?colW:`calc((100% - var(--wk-g) - var(--wk-r)) * ${span/WEEK_DAYS})`;};
 if(s.day!==null&&dayOffset(now,s.day)<=0)s.day=null;
 const selected=s.day===null?0:dayOffset(now,s.day);
 const pickDay=(i:number)=>{s.day=i===0?null:addDays(now,i);redraw();};
 // Day headers (a press moves the strip to that day).
 const heads=el('div','wk-days');
 for(let i=0;i<WEEK_DAYS;i++){
  const at=addDays(today,i),b=button('wk-dh'+(isWeekend(at)?' we':'')+(i===0?' today':'')+(i===selected?' sel':''),'wk-day-'+i);b.dataset.day=String(i);place(b,i);
  b.append(el('i','',weekday(at,w,narrow)),el('b','',String(new Date(at).getDate())));b.setAttribute('aria-label',dayLabel(at,w,zh));b.setAttribute('aria-pressed',String(i===selected));
  b.onclick=e=>{if(e.isTrusted)pickDay(i);};heads.append(b);
 }
 // All-day: one row. Reset-card bars across their days; an official announced reset is a ◆ on the day it takes effect only.
 const allDay=el('div','wk-ad');allDay.append(el('span','wk-adl',w.allDay));
 const end=addDays(today,WEEK_DAYS),chipsOn=new Array<number>(WEEK_DAYS).fill(0);let rowsUsed=0;
 for(const x of data.spans){
  if(x.from>=end||x.to!==null&&x.to<today)continue;
  const sub=data.subs[x.sub]!;
  if(x.kind==='cards'){
   if(x.to===null){// no expiry known: one mark on the day the cards were seen, no bar and no date
    const row=el('div','wk-adr mark');row.style.setProperty('--c',sub.colour);row.title=spanText(data,x,w,zh,true);place(row,Math.max(0,dayOffset(now,x.from)));
    row.append(el('span','',`◆ ${nameOf(data,x.sub,zh)}`));allDay.append(row);rowsUsed++;continue;
   }
   const a=Math.max(0,dayOffset(now,x.from)),b=Math.min(WEEK_DAYS-1,dayOffset(now,x.to)),row=el('div','wk-adr bar');row.style.setProperty('--c',sub.colour);row.title=spanText(data,x,w,zh,true);
   place(row,a,b-a+1);row.append(el('span','',narrow?`${nameOf(data,x.sub,zh)} ${w.cards}`:zh?`${sub.name.zh} ${w.cards} ${monthDay(Math.max(x.from,today))}–${monthDay(x.to)}`:`${sub.name.en} ${w.cards} ${monthDay(Math.max(x.from,today))}–${monthDay(x.to)}`));
   allDay.append(row);rowsUsed++;
  }else{
   // Reset notices are chips on their day: +1 for a reset card, ↻ for a direct reset (dashed until the vendor reports it done).
   // With no stated time the day is the one it was published; a notice still current never sits before today.
   const stamp=x.to??x.from,day=x.to===null?Math.max(0,dayOffset(now,stamp)):dayOffset(now,x.to);
   if(x.to!==null&&x.to<today||day>=WEEK_DAYS)continue;
   const credit=x.kind==='credit',row=el('div','wk-adr mark chip '+(credit?'credit':x.kind==='confirmed'?'direct':'direct pending'));row.style.setProperty('--c',sub.colour);row.title=spanText(data,x,w,zh,true);place(row,day);
   // Chips of one day stack in lanes under each other; on a narrow column the direct reset keeps only its ↻ (the title has the words).
   const lane=chipsOn[day]!++;if(lane)row.style.top=`${2+lane*15}px`;
   row.append(el('span','',credit?`+1 ${w.cards}`:narrow?'↻':`↻ ${w.direct}`));allDay.append(row);rowsUsed++;
  }
 }
 if(!rowsUsed)allDay.classList.add('none');
 else if(Math.max(...chipsOn)>1)allDay.style.height=`${5+15*Math.max(...chipsOn)}px`;
 // The hour body: the whole day fitted by default; zoomed it scrolls (scrollbar, ↑/↓ hints at the column edges).
 const scroll=el('div','wk-sc'),inner=el('div','wk-in');inner.style.height=fit?'100%':`${(24/zoom*100).toFixed(3)}%`;scroll.append(inner);
 const Y=(h:number)=>pct(h/24);
 for(let i=0;i<WEEK_DAYS;i++){const at=addDays(today,i),c=el('div','wk-col'+(isWeekend(at)?' we':'')+(i===selected?' sel':''));c.dataset.day=String(i);place(c,i);c.onclick=e=>{if(e.isTrusted&&!(e.target as Element).closest('.wk-ch'))pickDay(i);};inner.append(c);}
 const step=fit?6:2;
 for(let h=0;h<=24;h+=fit?6:1){const g=el('div','wk-g'+(h%step?' minor':'')+(h===0?' top':''));g.style.top=Y(h);if(h%step===0&&h<24)g.append(el('i','',narrow?String(h).padStart(2,'0'):`${String(h).padStart(2,'0')}:00`));inner.append(g);}
 const items:WeekItem[]=[],times:[HTMLElement,string,number,string,string][]=[],dayChips=new Map<number,HTMLElement[]>();
 // Peaks: split at local midnights; overlapping peaks in one day sit side by side.
 const pieces=data.peaks.flatMap(p=>dayPieces(p.from,p.to??Math.max(p.from+HOUR,now),today,WEEK_DAYS).map(x=>({...x,p})));
 for(let i=0;i<WEEK_DAYS;i++)for(const {item,lane,lanes} of packLanes(pieces.filter(x=>x.day===i))){
  const {p,start,end:stop,cont}=item,block=el('div','wk-pk'+(p.tentative?' tent':''));block.style.setProperty('--c',colourOf(data,p.sub));
  block.style.top=Y(start);block.style.height=pct((stop-start)/24);
  block.style.left=`calc(${col(i)} + 2px + (${colW} - 4px) * ${lane/lanes})`;block.style.width=`calc((${colW} - 4px) / ${lanes} - 1px)`;
  const abbr=nameOf(data,p.sub,zh);block.title=peakTitle(data,p,w,zh);
  const time=el('i','',`${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}`);
  block.append(el('b','',fit?abbr:`${abbr} ${w.peak}${cont?w.cont:''}`),time);
  inner.append(block);times.push([time,hhmm(p.from),i,Y(start),colourOf(data,p.sub)]);
  items.push({day:i,start,end:stop,label:`${abbr} ${w.peak} ${hhmm(p.from)}`,kind:'peak'});
 }
 // Chips: weekly resets on their day, and today's next 5-hour reset of each subscription.
 const next5=new Map<number,number>();for(const r of data.resets)if(r.kind==='5h'&&dayOffset(now,r.at)===0&&!next5.has(r.sub))next5.set(r.sub,r.at);
 for(const r of data.resets){
  const i=dayOffset(now,r.at);if(i<0||i>=WEEK_DAYS)continue;if(r.kind==='5h'&&next5.get(r.sub)!==r.at)continue;
  const sub=data.subs[r.sub]!,h=wallHours(r.at),c=el('div','wk-ch'+(r.kind==='week'?' wk':''));c.style.setProperty('--c',sub.colour);c.style.top=Y(h);c.style.left=`calc(${col(i)} + ${narrow?3:10}px)`;c.style.maxWidth=`calc(${colW} - ${narrow?5:14}px)`;
  const short=r.kind==='5h'?`${nameOf(data,r.sub,zh)} 5h ${hhmm(r.at)}`:`${nameOf(data,r.sub,zh)} ${w.wk} ${hhmm(r.at)}`;
  c.textContent=hhmm(r.at);c.title=`${zh?sub.name.zh:sub.name.en} · ${resetText(zh?sub.name.zh:sub.name.en,r.kind,r.at,'',w,true)} · ${dayLabel(r.at,w,zh)}`;
  inner.append(c);dayChips.set(i,[...(dayChips.get(i)??[]),c]);items.push({day:i,start:h,end:h,label:short,kind:'chip'});
 }
 // Now: today's past is dimmed, the now line crosses today's column and the time sits in the gutter.
 const nh=wallHours(now),past=el('div','wk-past');place(past,0);past.style.top='0%';past.style.height=Y(nh);
 const line=el('div','wk-nl');place(line,0);line.style.top=Y(nh);const tag=el('div','wk-nt',hhmm(now));tag.style.top=Y(nh);
 inner.append(past,line,tag);
 const hints=el('div','wk-hints');
 body.replaceChildren(heads,allDay,scroll,hints,status);hints.style.top=`${scroll.offsetTop}px`;
 // G3-179: measured only now that the body is in the document — a zoomed time line drops its end before it clips
 // (a block holds ~40 px across seven columns). A split lane can stay narrower than even HH:MM (sampling 11-22);
 // the time then leaves the lane as a tag on the day column, in the peak's colour; the block keeps its tooltip.
 const peakTags=new Map<number,HTMLElement[]>();
 if(!fit)for(const [time,start,i,top,colour] of times)if(time.scrollWidth>time.clientWidth){
  time.textContent=start;
  if(time.scrollWidth>time.clientWidth){
   const title=time.parentElement?.title??'';time.remove();
   const tag=el('i','wk-pkt');tag.style.setProperty('--c',colour);
   tag.style.top=top;tag.style.left=`calc(${col(i)} + 2px)`;tag.textContent=start;tag.title=title;
   inner.append(tag);peakTags.set(i,[...(peakTags.get(i)??[]),tag]);
  }
 }
 // Adjacent peaks and reset chips can start less than one label-height apart. Settle them
 // within each day so moved peak times do not cover another time.
 for(const [day,moved] of peakTags){
  const tags=[...moved,...(dayChips.get(day)??[])].sort((a,b)=>parseFloat(a.style.top)-parseFloat(b.style.top));
  const h=inner.clientHeight,ys=tags.map(tag=>parseFloat(tag.style.top)*h/100-6);
  for(let i=0;i<ys.length;i++)ys[i]=Math.max(ys[i]!,i?ys[i-1]!+13:0);
  for(let i=ys.length-1;i>=0;i--)ys[i]=Math.max(0,Math.min(ys[i]!,i===ys.length-1?h-12:ys[i+1]!-13));
  tags.forEach((tag,i)=>{tag.style.top=`${ys[i]!+6}px`;});
 }
 // Zoomed: keep the centre hour (first zoom: centre on now), and keep the edge hints in step with the scroll.
 if(!fit){
  const centre=s.centre??nh,vh=scroll.clientHeight,ch=inner.clientHeight;
  scroll.scrollTop=Math.max(0,centre/24*ch-vh/2);
  const sync=()=>{const ch2=inner.clientHeight||1,top=scroll.scrollTop/ch2*24,bottom=(scroll.scrollTop+scroll.clientHeight)/ch2*24;s.centre=(top+bottom)/2;paintHints(hints,items,top,bottom,col,colW);};
  scroll.onscroll=sync;sync();
 }
 else s.centre=null;
 // Pinch (WebKit sends ctrl+wheel) or ⌘+wheel zooms; a plain wheel scrolls when zoomed.
 scroll.onwheel=e=>{if(!e.isTrusted)return;if(e.ctrlKey||e.metaKey){e.preventDefault();zoomBy(e.deltaY<0?1:-1,s,redraw);}};
 const gesture=(e:Event)=>{const scale=(e as Event&{scale?:number}).scale;if(typeof scale!=='number')return;e.preventDefault();if(scale>1.15)zoomBy(1,s,redraw);else if(scale<0.87)zoomBy(-1,s,redraw);};
 scroll.addEventListener('gestureend',gesture);
}
function paintHints(hints:HTMLElement,items:readonly WeekItem[],top:number,bottom:number,col:(i:number)=>string,colW:string) {
 hints.replaceChildren();
 for(let i=0;i<WEEK_DAYS;i++){
  const day=items.filter(x=>x.day===i),above=day.filter(x=>(x.kind==='chip'?x.start:x.end)<=top).sort((a,b)=>b.end-a.end)[0],below=day.filter(x=>x.start>=bottom).sort((a,b)=>a.start-b.start)[0];
  const clipped=day.some(x=>x.kind==='peak'&&x.start<top&&x.end>top);
  if(above||clipped){const h=el('i','up',above?`↑ ${above.label}`:'↑');h.style.left=col(i);h.style.width=colW;hints.append(h);}
  if(below){const h=el('i','down',`↓ ${below.label}`);h.style.left=col(i);h.style.width=colW;hints.append(h);}
 }
}
function zoomBy(step:number,s:View,redraw:()=>void) {
 const at=ZOOMS.indexOf(s.zoom as typeof ZOOMS[number]),next=ZOOMS[Math.max(0,Math.min(ZOOMS.length-1,(at<0?0:at)+step))]!;
 if(next!==s.zoom){s.zoom=next;redraw();}
}

// --- the fallback cells and lines (D293 grammar), used when a draw fails ----------------------------------------
const readingOf=(state:unknown)=>state&&typeof state==='object'&&(state as CalendarData).version===1?state as CalendarData:null;
function nextReset(data:CalendarData,now:number) {const r=data.resets.find(x=>x.at>now);return r?{r,sub:data.subs[r.sub]!}:null;}
function fallbackCells(data:CalendarData|null,context:PluginContext):PluginCell[] {
 if(!data||!context.now)return [{tag:context.words('plugin.calendarWaiting')}];
 const w=wordsOf(context),now=context.now,zh=context.locale==='zh-CN',side=(full:string,short=full)=>({full,short});
 // D293 cells, D375: the soonest reset of any kind with its time as the big text, then the weekly reset when it is another
 // moment (the same moment is written once). Each carries the subscription's colour mark and its name.
 const first=data.resets.find(x=>x.at>now),weekly=data.resets.find(x=>x.at>now&&x.kind==='week'&&(!first||x.at!==first.at));
 const peak=data.peaks.find(p=>(p.to??p.from+1)>now),cards=data.spans.find(x=>x.kind==='cards');
 const cells:PluginCell[]=[];
 const resetCell=(tag:PluginCell['tag'],r:CalendarData['resets'][number]):PluginCell=>{
  const name=nameOf(data,r.sub,zh),win=context.words(r.kind==='5h'?'plugin.calWin5':'plugin.calWinWeek').full,day=dayOffset(now,r.at)>0?` · ${dayLabel(r.at,w,zh)}`:'';
  return {tag,big:hhmm(r.at),side:context.words('plugin.calIn',{t:duration(r.at-now)}),subline:{colour:colourOf(data,r.sub),text:side(`${name} ${win}${day}`,name)}};
 };
 cells.push(first?resetCell(context.words('plugin.calendarReset'),first):{tag:context.words('plugin.calendarReset'),side:context.words('plugin.calendarNone')});
 if(weekly)cells.push(resetCell(context.words('plugin.calWeekReset'),weekly));
 else if(first&&first.kind==='week'){/* the next reset is the weekly one: written once, above */}
 else cells.push({tag:context.words('plugin.calWeekReset'),side:context.words('plugin.calendarNone')});
 if(peak)cells.push({tag:context.words('plugin.calendarPeak'),side:side(`${hhmm(peak.from)}–${peak.to===null?'…':hhmm(peak.to)}`),subline:{colour:colourOf(data,peak.sub),text:side(nameOf(data,peak.sub,zh))}});
 else if(cards)cells.push({tag:context.words('plugin.calendarCards'),side:side(spanText(data,cards,w,zh),`${nameOf(data,cards.sub,zh)} ${cards.to===null?w.cards:monthDay(cards.to)}`)});
 return cells;
}
function fallbackLines(data:CalendarData|null,context:PluginContext):{label:string;value:string}[] {
 if(!data||!context.now)return [{label:context.words('plugin.calendarWaiting').full,value:''}];
 const w=wordsOf(context),zh=context.locale==='zh-CN',now=context.now,end=addDays(now,WEEK_DAYS);
 const lines=[
  ...data.resets.filter(r=>r.at>now&&r.at<end).map(r=>({at:r.at,label:resetText(nameOf(data,r.sub,zh),r.kind,r.at,'',w,true),value:`${dayLabel(r.at,w,zh)} ${hhmm(r.at)}`})),
  ...data.peaks.filter(p=>(p.to??p.from+1)>now&&p.from<end).map(p=>({at:p.from,label:`${nameOf(data,p.sub,zh)} ${w.peak}`,value:`${dayLabel(p.from,w,zh)} ${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}`})),
 ].sort((a,b)=>a.at-b.at).map(({label,value})=>({label,value}));
 return lines.length?lines:[{label:w.empty,value:''}];
}

// --- the plugin ------------------------------------------------------------------------------------------------------
export const calendarPlugin:CockpitPlugin=Object.freeze({
 id:'calendar',
 title:'plugin.calendarTitle',
 summary:'plugin.calendarSummary',
 // D328 key icon: a white line calendar sheet with two rings, on the shared 16 px frame at the vendor marks' stroke (currentColor); the underline is the grey dashed #87939e.
 icon:`<svg viewBox="0 0 16 16" aria-hidden="true">${PLUGIN_ICON_FRAME}<path d="M1 6h14M5 0.5v3M11 0.5v3" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" fill="none"/></svg>`,
 underline:'#87939e',
 defaultEnabled:true,
 settings:Object.freeze([]),
 /** A host push or the page's own shaping (`derive`): bounded as JSON, then the strict parser. */
 accept(data:unknown){
  let bytes=Infinity;try{const json=JSON.stringify(data);if(typeof json==='string')bytes=new TextEncoder().encode(json).length;}catch{return undefined;}
  if(bytes>CALENDAR_MAX_BYTES)return undefined;
  return parseCalendarData(data)??undefined;
 },
 derive:calendarFromCockpit,
 nextDeadline:(_state:unknown,now:number)=>now?nextMinute(now):null,
 column(state:unknown,context:PluginContext){
  const data=readingOf(state);
  // D328: no peak rules (only Codex, say): the D293 cells and "Peak: no peak rules", no strip.
  const strip=data&&data.peaks.length?(c:PluginDrawContext)=>paintStrip(c,data):null;
  return {cells:fallbackCells(data,context),foot:footOf(data,context),draw:strip};
 },
 screen(state:unknown,context:PluginContext){
  const data=readingOf(state);
  return {lines:fallbackLines(data,context),draw:(c:PluginDrawContext)=>paintWeek(c,data)};
 },
});
