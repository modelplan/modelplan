// SPDX-License-Identifier: MIT
// v1.1 cockpit calendar plugin (owner D137, D138, D140, D141, D145; CKP-PLG-06/07; mockups v4 A, C, E3).
// The column is an Apple-style day view: a 今/明/后 picker with dots, an all-day lane, a 36-hour axis from now with a
// midnight divider, peak blocks in the subscription's colour (side by side when they overlap), the user's own reset chips,
// the now line and a folded line for what lies beyond. 明/后 show that day 00–24 with a ↺ 现在 chip. The plugin key opens
// the 7-day week view as the plugin's big screen inside the MFD screen.
// Owner D323: both are custom draws (the framework's `draw` hook): the day strip paints the column's cell area, the week
// grid paints the screen body. The key, its underline, the bottom line ("Now 12:00"), the screen's title bar and the
// lifecycle stay the framework's. If a draw fails, the column falls back to three cells (next reset, next peak, reset
// cards) and the screen to plain lines.
// All times are local. The page has no timers: the host's minute tick moves the now line and rolls the day over.
import {PLUGIN_ICON_FRAME,type CockpitPlugin,type PluginCell,type PluginContext,type PluginDrawContext,type PluginLocale} from './plugin-registry.js';
import {CALENDAR_MAX_BYTES,calendarFromCockpit,emptyCalendar,parseCalendarData,type CalendarData,type CalendarSpan} from './calendar-data.js';
import {HOUR,WEEK_DAYS,addDays,dayOffset,dayPieces,hhmm,hourMarks,isWeekend,midnights,monthDay,nextMinute,packLanes,startOfDay,stripWindow,wallHours,type Span} from './calendar-time.js';

// Every word the calendar draws comes from the plugin string table (strings/plugins.js, `plugin.cal*`), in the locale
// of the draw context; nothing here picks a language's text inline.
const WORDS=['now','back','allDay','peak','cont','r5','week5','weekly','weeklyLong','wk','cards','until','announced','confirmed','effective','empty','waiting','zoomed','tentative','announcedOn'] as const;
type Words={readonly [k in typeof WORDS[number]]:string}&{readonly days:readonly string[];readonly weekdays:readonly string[];readonly narrow:readonly string[]};
function wordsOf(context:PluginContext):Words {
 const word=(key:string)=>context.words('plugin.'+key).full,out:Record<string,unknown>={};
 for(const k of WORDS)out[k]=word('cal'+k[0]!.toUpperCase()+k.slice(1));
 out.days=[0,1,2].map(i=>word('calDay'+i));out.weekdays=[0,1,2,3,4,5,6].map(i=>word('calWd'+i));out.narrow=[0,1,2,3,4,5,6].map(i=>word('calWn'+i));
 return out as Words;
}
const el=<K extends keyof HTMLElementTagNameMap>(tag:K,className?:string,text?:string)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
const pct=(v:number)=>`${(Math.max(0,Math.min(1,v))*100).toFixed(3)}%`;

/** View state (the framework's per-plugin `memo`, shared by the column and the screen): the picked day, the folded
 *  list, the week zoom and its centre hour. Readings are the framework's state (`accept`), not kept here. */
interface View {day:number|null;fold:boolean;zoom:number;centre:number|null}
const viewOf=(memo:Record<string,unknown>)=>{let v=memo.view as View|undefined;if(!v){v={day:null,fold:false,zoom:24,centre:null};memo.view=v;}return v;};
/** A button the framework keeps focused across redraws (D323 `data-focus`). */
const button=(className:string,focus:string,text?:string)=>{const b=el('button',className,text);b.type='button';b.dataset.focus=focus;return b;};

// --- shared labels -----------------------------------------------------------------------------------------------
const weekday=(t:number,w:Words,narrow=false)=>(narrow?w.narrow:w.weekdays)[new Date(t).getDay()]!;
const dayLabel=(t:number,w:Words,zh:boolean)=>zh?`${monthDay(t)} ${weekday(t,w)}`:`${weekday(t,w)} ${monthDay(t)}`;
/** A chip's day prefix inside the 36-hour view: none today, 明/后 (Tmr/weekday) on later days. */
function dayPrefix(at:number,now:number,w:Words,zh:boolean){const d=dayOffset(now,at);return d<=0?'':zh?(d<3?w.days[d]!:`${monthDay(at)} `):d===1?`${w.days[1]} `:`${weekday(at,w)} `;}
function resetText(abbr:string,kind:'5h'|'week',at:number,prefix:string,w:Words,long=false){
 const what=kind==='5h'?(long?w.week5:w.r5):(long?w.weeklyLong:w.weekly);return `${abbr} ${what} ${prefix}${hhmm(at)}`;
}
function spanText(data:CalendarData,s:CalendarSpan,w:Words,zh:boolean,full=false){
 const sub=data.subs[s.sub]!,name=full?(zh?sub.name.zh:sub.name.en):sub.abbr;
 if(s.kind==='cards'){const n=s.count&&s.count>1?` ×${s.count}`:'';return zh?`${name} ${w.cards}${n} ${w.until}${monthDay(s.to!)}`:`${name} ${w.cards}${n} · ${w.until} ${monthDay(s.to!)}`;}
 const what=s.kind==='confirmed'?w.confirmed:w.announced;
 if(s.to===null)return `${name} ${what}`;
 return zh?`${name} ${what} · ${monthDay(s.to)} ${w.effective}`:`${name} ${what} · ${monthDay(s.to)}`;
}
const peakTitle=(data:CalendarData,p:{sub:number;from:number;to:number|null;tentative:boolean},w:Words)=>`${data.subs[p.sub]!.abbr} ${w.peak} ${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}${p.tentative?` · ${w.tentative}`:''}`;
const colourOf=(data:CalendarData,sub:number)=>data.subs[sub]?.colour??'#c6ccd4';

/** Days 0..2 from today that have something on them (the picker's dots). */
export function dayHasEvents(data:CalendarData,now:number,offset:number):boolean {
 const from=addDays(now,offset),to=addDays(now,offset+1),inside=(t:number)=>t>=from&&t<to;
 return data.resets.some(r=>inside(r.at))||data.peaks.some(p=>p.from<to&&(p.to??p.from+1)>from)||data.spans.some(s=>s.to!==null&&inside(s.to));
}
/** What lies beyond the strip's window, earliest first (the folded line). */
export function beyond(data:CalendarData,span:Span):{at:number;sub:number;kind:'5h'|'week'|'span';span?:CalendarSpan}[] {
 const out:{at:number;sub:number;kind:'5h'|'week'|'span';span?:CalendarSpan}[]=[];
 for(const r of data.resets)if(r.at>=span.to)out.push({at:r.at,sub:r.sub,kind:r.kind});
 for(const s of data.spans)if(s.kind!=='cards'&&s.to!==null&&s.to>=span.to)out.push({at:s.to,sub:s.sub,kind:'span',span:s});
 return out.sort((a,b)=>a.at-b.at);
}

// --- the column (day view) ---------------------------------------------------------------------------------------
function paintStrip(context:PluginDrawContext,reading:CalendarData|null) {
 const s=viewOf(context.memo),w=wordsOf(context),zh=context.locale==='zh-CN',now=context.now;
 const panel=el('div','cal');context.area.append(panel);
 const redraw=()=>context.redraw();
 // No host time yet (the first draw comes before the first display data): nothing to place.
 if(!now){panel.dataset.view='waiting';panel.replaceChildren(el('p','cal-empty',w.waiting));return;}
 if(s.day!==null&&dayOffset(now,s.day)<=0)s.day=null;// the day rolled over: back to now
 panel.dataset.view=s.day===null?'now':String(dayOffset(now,s.day));
 const data=reading??emptyCalendar,span=stripWindow(now,s.day);
 // Picker: 今 明 后 with dots on days that have events; the selected day is lit.
 const pick=el('div','cal-pick');
 for(let i=0;i<3;i++){
  const at=addDays(now,i),b=button('cal-d','day-'+i),sel=s.day===null?i===0:dayOffset(now,s.day)===i;b.dataset.day=String(i);
  b.append(el('i','',zh||i<2?w.days[i]??weekday(at,w):weekday(at,w)),el('b','',String(new Date(at).getDate())),el('s',reading&&dayHasEvents(data,now,i)?'on':''));
  b.classList.toggle('sel',sel);b.setAttribute('aria-pressed',String(sel));b.setAttribute('aria-label',dayLabel(at,w,zh));
  b.onclick=e=>{if(!e.isTrusted)return;s.day=i===0?null:startOfDay(at);s.fold=false;redraw();};pick.append(b);
 }
 // The time now is the framework's bottom line; another day shows its date and the ↺ Now chip here.
 const head=el('div','cal-hd');
 if(s.day===null)head.hidden=true;
 else{const back=button('cal-back','back',w.back);back.onclick=e=>{if(!e.isTrusted)return;s.day=null;s.fold=false;redraw();};head.append(el('span','cal-ts',dayLabel(s.day,w,zh)),back);}
 // All-day lane: reset cards and announced resets that touch the window.
 const allDay=el('div','cal-ad');allDay.append(el('span','cal-adl',w.allDay));
 const rows=data.spans.filter(x=>x.from<span.to&&(x.to===null||x.to>=span.from));
 for(const x of rows.slice(0,3)){
  const sub=data.subs[x.sub]!,row=el('div','cal-adr '+(x.kind==='cards'?'bar':'line'));row.style.setProperty('--c',sub.colour);row.title=spanText(data,x,w,zh,true);
  row.append(el('span','',spanText(data,x,w,zh)));
  if(x.kind!=='cards'){row.classList.toggle('before',x.from<span.from);row.classList.toggle('after',x.to===null||x.to>span.to);}
  allDay.append(row);
 }
 if(rows.length>3)allDay.append(el('div','cal-adm',`+${rows.length-3}`));
 if(!rows.length)allDay.classList.add('none');
 // The axis: linear in real time over the window (36 h from now, or the 23/24/25 h of one local day).
 const axis=el('div','cal-ax'),len=span.to-span.from,Y=(t:number)=>(t-span.from)/len;
 // Built after the rest so the axis can be measured: hour labels every 3 h when there is room, else every 6 h.
 const later=beyond(data,span),fold=button('cal-fold','fold');
 const label=(x:ReturnType<typeof beyond>[number])=>x.kind==='span'?`${monthDay(x.at)} ${spanText(data,x.span!,w,zh)}`:`${monthDay(x.at)} ${resetText(data.subs[x.sub]!.abbr,x.kind,x.at,'',w)}`;
 if(later.length){fold.textContent=`▾ ${label(later[0]!)}${later.length>1?` · +${later.length-1}`:''}`;fold.setAttribute('aria-expanded',String(s.fold));fold.onclick=e=>{if(!e.isTrusted)return;s.fold=!s.fold;redraw();};}
 else{fold.disabled=true;fold.classList.add('none');}
 panel.replaceChildren(pick,head,allDay,axis,fold);
 const H=axis.clientHeight||160,pxHour=H/(len/HOUR),every=pxHour*3>=13?3:pxHour*6>=13?6:12;
 for(const m of hourMarks(span,every)){if(m.hour===0)continue;const g=el('div','cal-g');g.style.top=pct(Y(m.at));g.append(el('i','',String(m.hour).padStart(2,'0')));axis.append(g);}
 for(const m of midnights(span)){const line=el('div','cal-mid');line.style.top=pct(Y(m));line.append(el('b','',dayLabel(m,w,zh)));axis.append(line);}
 const pieces=data.peaks.flatMap(p=>{const a=Math.max(p.from,span.from),b=Math.min(p.to??span.to,span.to);return a<b?[{p,start:a,end:b}]:[];});
 for(const {item,lane,lanes} of packLanes(pieces)){
  const {p,start,end}=item,block=el('div','cal-pk'+(p.tentative?' tent':''));block.style.setProperty('--c',colourOf(data,p.sub));
  block.style.top=pct(Y(start));block.style.height=pct(Y(end)-Y(start));
  block.style.left=`calc(var(--cal-g) + (100% - var(--cal-g) - 2px) * ${lane/lanes})`;block.style.width=`calc((100% - var(--cal-g) - 2px) / ${lanes} - 2px)`;
  const tall=(Y(end)-Y(start))*H;block.classList.toggle('short',tall<17);block.classList.toggle('tiny',tall<8);
  block.title=peakTitle(data,p,w);block.append(el('b','',`${data.subs[p.sub]!.abbr} ${w.peak}${p.from<span.from?w.cont:''}`),el('i','',`${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}`));
  axis.append(block);
 }
 const chips=data.resets.filter(r=>r.at>=span.from&&r.at<span.to);
 for(const r of chips){
  const c=el('div','cal-ch'),sub=data.subs[r.sub]!;c.style.setProperty('--c',sub.colour);c.dataset.y=String(Y(r.at));c.style.top=pct(Y(r.at));
  c.textContent=resetText(sub.abbr,r.kind,r.at,s.day===null?dayPrefix(r.at,now,w,zh):'',w);c.title=`${zh?sub.name.zh:sub.name.en} · ${resetText(sub.abbr,r.kind,r.at,'',w,true)} · ${dayLabel(r.at,w,zh)}`;axis.append(c);
 }
 if(s.day===null){const line=el('div','cal-nl');line.style.top='0%';axis.append(line);}
 if(!reading)axis.append(el('p','cal-empty',w.waiting));
 else if(!pieces.length&&!chips.length&&!rows.length)axis.append(el('p','cal-empty',w.empty));
 // Folded: everything beyond the window in one line (built above); a press lists it.
 if(s.fold&&later.length){const list=el('ul','cal-more');for(const x of later.slice(0,12))list.append(el('li','',label(x)));panel.append(list);}
 settleChips(axis);
}
/** Reset chips never overlap: a chip that would sit on the one above moves down (the axis is measured when drawn). */
function settleChips(axis:HTMLElement) {
 const h=axis.clientHeight||160,chips=[...axis.querySelectorAll<HTMLElement>('.cal-ch')].sort((a,b)=>Number(a.dataset.y)-Number(b.dataset.y)),ch=11,gap=1;
 const ys=chips.map(c=>Number(c.dataset.y)*h-ch/2);
 for(let i=0;i<ys.length;i++)ys[i]=Math.max(ys[i]!,i?ys[i-1]!+ch+gap:0);
 // Pushed past the bottom: settle upwards from the end instead (they only overlap when the axis cannot hold them all).
 for(let i=ys.length-1;i>=0;i--)ys[i]=Math.max(0,Math.min(ys[i]!,i===ys.length-1?h-ch:ys[i+1]!-ch-gap));
 chips.forEach((c,i)=>{c.style.top=`${ys[i]!.toFixed(1)}px`;});
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
 const selected=s.day===null?0:dayOffset(now,s.day);
 const pickDay=(i:number)=>{s.day=i===0?null:addDays(now,i);s.fold=false;redraw();};
 // Day headers (a press moves the strip to that day).
 const heads=el('div','wk-days');
 for(let i=0;i<WEEK_DAYS;i++){
  const at=addDays(today,i),b=button('wk-dh'+(isWeekend(at)?' we':'')+(i===0?' today':'')+(i===selected?' sel':''),'wk-day-'+i);b.dataset.day=String(i);place(b,i);
  b.append(el('i','',weekday(at,w,narrow)),el('b','',String(new Date(at).getDate())));b.setAttribute('aria-label',dayLabel(at,w,zh));b.setAttribute('aria-pressed',String(i===selected));
  b.onclick=e=>{if(e.isTrusted)pickDay(i);};heads.append(b);
 }
 // All-day lane: reset-card bars across their days, announced resets as a line to the day they take effect.
 const allDay=el('div','wk-ad');allDay.append(el('span','wk-adl',w.allDay));
 const end=addDays(today,WEEK_DAYS);let rowsUsed=0;
 for(const x of data.spans){
  if(rowsUsed>=2)break;if(x.from>=end||x.to!==null&&x.to<today)continue;
  const sub=data.subs[x.sub]!,a=Math.max(0,dayOffset(now,x.from)),row=el('div','wk-adr '+(x.kind==='cards'?'bar':'line'));row.style.setProperty('--c',sub.colour);row.style.setProperty('--row',String(rowsUsed++));row.title=spanText(data,x,w,zh,true);
  if(x.kind==='cards'){const b=Math.min(WEEK_DAYS-1,dayOffset(now,x.to!));place(row,a,b-a+1);row.append(el('span','',narrow?`${sub.abbr} ${w.cards}`:zh?`${sub.name.zh} ${w.cards} ${monthDay(Math.max(x.from,today))}–${monthDay(x.to!)}`:`${sub.name.en} ${w.cards} ${monthDay(Math.max(x.from,today))}–${monthDay(x.to!)}`));}
  else{
   const inWeek=x.to!==null&&x.to<end,b=inWeek?dayOffset(now,x.to!):WEEK_DAYS-1;
   row.style.left=col(a);row.style.width=inWeek?`calc((100% - var(--wk-g) - var(--wk-r)) * ${(b-a+0.5)/WEEK_DAYS})`:`calc((100% - var(--wk-g) - var(--wk-r)) * ${(WEEK_DAYS-a)/WEEK_DAYS} - 4px)`;
   row.classList.toggle('before',x.from<today);row.classList.toggle('after',!inWeek);
   const what=x.kind==='confirmed'?w.confirmed:w.announced,name=zh?sub.name.zh:sub.name.en;
   row.append(el('span','',narrow?`${sub.abbr} ${zh?w.effective:''}`.trim():x.to===null?`${name} ${what} →`:zh?`${name} ${monthDay(x.to)} ${w.effective}（${monthDay(x.from)} ${w.announcedOn}）${inWeek?'':' →'}`:`${name} ${what} ${monthDay(x.to)} (${w.announcedOn} ${monthDay(x.from)})${inWeek?'':' →'}`));
  }
  allDay.append(row);
 }
 if(!rowsUsed)allDay.classList.add('none');
 // The hour body: the whole day fitted by default; zoomed it scrolls (scrollbar, ↑/↓ hints at the column edges).
 const scroll=el('div','wk-sc'),inner=el('div','wk-in');inner.style.height=fit?'100%':`${(24/zoom*100).toFixed(3)}%`;scroll.append(inner);
 const Y=(h:number)=>pct(h/24);
 for(let i=0;i<WEEK_DAYS;i++){const at=addDays(today,i),c=el('div','wk-col'+(isWeekend(at)?' we':'')+(i===selected?' sel':''));c.dataset.day=String(i);place(c,i);c.onclick=e=>{if(e.isTrusted&&!(e.target as Element).closest('.wk-ch'))pickDay(i);};inner.append(c);}
 const step=fit?6:2;
 for(let h=0;h<=24;h+=fit?6:1){const g=el('div','wk-g'+(h%step?' minor':'')+(h===0?' top':''));g.style.top=Y(h);if(h%step===0&&h<24)g.append(el('i','',narrow?String(h).padStart(2,'0'):`${String(h).padStart(2,'0')}:00`));inner.append(g);}
 const items:WeekItem[]=[];
 // Peaks: split at local midnights; overlapping peaks in one day sit side by side.
 const pieces=data.peaks.flatMap(p=>dayPieces(p.from,p.to??Math.max(p.from+HOUR,now),today,WEEK_DAYS).map(x=>({...x,p})));
 for(let i=0;i<WEEK_DAYS;i++)for(const {item,lane,lanes} of packLanes(pieces.filter(x=>x.day===i))){
  const {p,start,end:stop,cont}=item,block=el('div','wk-pk'+(p.tentative?' tent':''));block.style.setProperty('--c',colourOf(data,p.sub));
  block.style.top=Y(start);block.style.height=pct((stop-start)/24);
  block.style.left=`calc(${col(i)} + 2px + (${colW} - 4px) * ${lane/lanes})`;block.style.width=`calc((${colW} - 4px) / ${lanes} - 1px)`;
  const abbr=data.subs[p.sub]!.abbr;block.title=peakTitle(data,p,w);
  block.append(el('b','',fit?abbr:`${abbr} ${w.peak}${cont?w.cont:''}`),el('i','',`${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}`));
  inner.append(block);items.push({day:i,start,end:stop,label:`${abbr} ${w.peak} ${hhmm(p.from)}`,kind:'peak'});
 }
 // Chips: weekly resets on their day, and today's next 5-hour reset of each subscription.
 const next5=new Map<number,number>();for(const r of data.resets)if(r.kind==='5h'&&dayOffset(now,r.at)===0&&!next5.has(r.sub))next5.set(r.sub,r.at);
 for(const r of data.resets){
  const i=dayOffset(now,r.at);if(i<0||i>=WEEK_DAYS)continue;if(r.kind==='5h'&&next5.get(r.sub)!==r.at)continue;
  const sub=data.subs[r.sub]!,h=wallHours(r.at),c=el('div','wk-ch');c.style.setProperty('--c',sub.colour);c.style.top=Y(h);c.style.left=`calc(${col(i)} + ${narrow?3:10}px)`;c.style.maxWidth=`calc(${colW} - ${narrow?5:14}px)`;
  const short=r.kind==='5h'?`${sub.abbr} 5h ${hhmm(r.at)}`:`${sub.abbr} ${w.wk} ${hhmm(r.at)}`;
  c.textContent=fit?short:resetText(sub.abbr,r.kind,r.at,'',w,true);c.title=`${zh?sub.name.zh:sub.name.en} · ${resetText(sub.abbr,r.kind,r.at,'',w,true)} · ${dayLabel(r.at,w,zh)}`;
  inner.append(c);items.push({day:i,start:h,end:h,label:short,kind:'chip'});
 }
 // Now: today's past is dimmed, the now line crosses today's column and the time sits in the gutter.
 const nh=wallHours(now),past=el('div','wk-past');place(past,0);past.style.top='0%';past.style.height=Y(nh);
 const line=el('div','wk-nl');place(line,0);line.style.top=Y(nh);const tag=el('div','wk-nt',hhmm(now));tag.style.top=Y(nh);
 inner.append(past,line,tag);
 const hints=el('div','wk-hints');
 body.replaceChildren(heads,allDay,scroll,hints,status);hints.style.top=`${scroll.offsetTop}px`;
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
 const reset=nextReset(data,now),peak=data.peaks.find(p=>(p.to??p.from+1)>now),cards=data.spans.find(x=>x.kind==='cards');
 const cells:PluginCell[]=[];
 cells.push({tag:context.words('plugin.calendarReset'),side:reset?side(resetText(reset.sub.abbr,reset.r.kind,reset.r.at,dayPrefix(reset.r.at,now,w,zh),w),`${reset.sub.abbr} ${hhmm(reset.r.at)}`):context.words('plugin.calendarNone')});
 cells.push({tag:context.words('plugin.calendarPeak'),side:peak?side(`${data.subs[peak.sub]!.abbr} ${hhmm(peak.from)}–${peak.to===null?'…':hhmm(peak.to)}`,`${data.subs[peak.sub]!.abbr} ${hhmm(peak.from)}`):context.words('plugin.calendarNone')});
 if(cards)cells.push({tag:context.words('plugin.calendarCards'),side:side(spanText(data,cards,w,zh),`${data.subs[cards.sub]!.abbr} ${monthDay(cards.to!)}`)});
 return cells;
}
function fallbackLines(data:CalendarData|null,context:PluginContext):{label:string;value:string}[] {
 if(!data||!context.now)return [{label:context.words('plugin.calendarWaiting').full,value:''}];
 const w=wordsOf(context),zh=context.locale==='zh-CN',now=context.now,end=addDays(now,WEEK_DAYS);
 const lines=[
  ...data.resets.filter(r=>r.at>now&&r.at<end).map(r=>({at:r.at,label:resetText(data.subs[r.sub]!.abbr,r.kind,r.at,'',w,true),value:`${dayLabel(r.at,w,zh)} ${hhmm(r.at)}`})),
  ...data.peaks.filter(p=>(p.to??p.from+1)>now&&p.from<end).map(p=>({at:p.from,label:`${data.subs[p.sub]!.abbr} ${w.peak}`,value:`${dayLabel(p.from,w,zh)} ${hhmm(p.from)}–${p.to===null?'…':hhmm(p.to)}`})),
 ].sort((a,b)=>a.at-b.at).map(({label,value})=>({label,value}));
 return lines.length?lines:[{label:w.empty,value:''}];
}

// --- the plugin ------------------------------------------------------------------------------------------------------
export const calendarPlugin:CockpitPlugin=Object.freeze({
 id:'calendar',
 title:'plugin.calendarTitle',
 summary:'plugin.calendarSummary',
 // Mockup v4 key icon: a calendar sheet with two rings, on the shared 16 px frame at the vendor marks' stroke (currentColor).
 icon:`<svg viewBox="0 0 16 16" aria-hidden="true">${PLUGIN_ICON_FRAME}<path d="M1 6h14M5 0.5v3M11 0.5v3" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" fill="none"/></svg>`,
 underline:'#b9c7d6',
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
  return {cells:fallbackCells(data,context),foot:context.now?{label:context.words('plugin.calendarNow'),value:{full:hhmm(context.now),short:hhmm(context.now)}}:null,draw:(c:PluginDrawContext)=>paintStrip(c,data)};
 },
 screen(state:unknown,context:PluginContext){
  const data=readingOf(state);
  return {lines:fallbackLines(data,context),draw:(c:PluginDrawContext)=>paintWeek(c,data)};
 },
});
