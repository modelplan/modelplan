// SPDX-License-Identifier: MIT
// Calendar plugin time maths (CKP-PLG-06/07). Everything is in the user's local time zone (the page's `Date`), and
// every day boundary is a local midnight found through the calendar, never "+24 h": DST days are 23 or 25 hours.
export const MINUTE=60_000;
export const HOUR=3_600_000;
/** The day view's window from now (owner D137: about 36 hours). */
export const STRIP_HOURS=36;
export const WEEK_DAYS=7;
export const startOfDay=(t:number)=>{const d=new Date(t);return new Date(d.getFullYear(),d.getMonth(),d.getDate()).getTime();};
/** Local midnight `n` days after the local day of `t`. */
export const addDays=(t:number,n:number)=>{const d=new Date(t);return new Date(d.getFullYear(),d.getMonth(),d.getDate()+n).getTime();};
/** Whole local days from the day of `from` to the day of `t` (negative before). */
export const dayOffset=(from:number,t:number)=>{const a=new Date(from),b=new Date(t);return Math.round((Date.UTC(b.getFullYear(),b.getMonth(),b.getDate())-Date.UTC(a.getFullYear(),a.getMonth(),a.getDate()))/86_400_000);};
/** Local wall-clock hours of `t` (0 <= h < 24). */
export const wallHours=(t:number)=>{const d=new Date(t);return d.getHours()+d.getMinutes()/60+d.getSeconds()/3600;};
export const pad2=(n:number)=>String(n).padStart(2,'0');
export const hhmm=(t:number)=>{const d=new Date(t);return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;};
export const monthDay=(t:number)=>{const d=new Date(t);return `${d.getMonth()+1}/${d.getDate()}`;};
export const isWeekend=(t:number)=>{const day=new Date(t).getDay();return day===0||day===6;};
/** The next whole local minute after `now`: the host's minute tick for the now line and the day rollover. */
export const nextMinute=(now:number)=>Math.floor(now/MINUTE)*MINUTE+MINUTE;

export interface Span {readonly from:number;readonly to:number}
/** The day view's window: from now for 36 hours, or one whole local day (00:00 to the next local midnight). */
export function stripWindow(now:number,day:number|null):Span {
 if(day===null)return {from:now,to:now+STRIP_HOURS*HOUR};
 const from=startOfDay(day);return {from,to:addDays(from,1)};
}
/** Local whole-hour instants strictly inside (from, to) whose local hour is a multiple of `every`, with that hour.
 *  On a fall-back day an hour label repeats (01, 01); on a spring-forward day one is missing. */
export function hourMarks(span:Span,every:number):{at:number;hour:number}[] {
 const out:{at:number;hour:number}[]=[];const d=new Date(span.from);
 let t=span.from-(d.getMinutes()*MINUTE+d.getSeconds()*1000+d.getMilliseconds());
 if(t<=span.from)t+=HOUR;
 for(let guard=0;t<span.to&&guard<24*40;t+=HOUR,guard++){
  const local=new Date(t);if(local.getMinutes()!==0)continue;// a half-hour DST shift: not a whole local hour
  if(local.getHours()%every===0)out.push({at:t,hour:local.getHours()});
 }
 return out;
}
/** Local midnights strictly inside (from, to). */
export function midnights(span:Span):number[] {
 const out:number[]=[];for(let t=addDays(span.from,1),i=0;t<span.to&&i<64;t=addDays(t,1),i++)if(t>span.from)out.push(t);return out;
}
/** The part of [from, to) inside each of `days` local days from `first` (a local midnight), as wall-clock hours.
 *  `cont` marks a piece that started the day before (a peak crossing midnight, e.g. 22:00–02:00). */
export function dayPieces(from:number,to:number,first:number,days:number):{day:number;start:number;end:number;cont:boolean}[] {
 const out:{day:number;start:number;end:number;cont:boolean}[]=[];
 for(let i=0;i<days;i++){
  const ds=addDays(first,i),de=addDays(first,i+1),a=Math.max(from,ds),b=Math.min(to,de);
  if(a>=b)continue;
  out.push({day:i,start:a===ds?0:wallHours(a),end:b===de?24:wallHours(b)||24,cont:from<ds});
 }
 return out;
}
/** Side-by-side lanes for overlapping intervals (Apple day view): each item gets a lane and the lane count of its
 *  overlap group, so a group shares the width equally. Items that only touch do not overlap. */
export function packLanes<T extends {readonly start:number;readonly end:number}>(items:readonly T[]):{item:T;lane:number;lanes:number}[] {
 const sorted=[...items].sort((a,b)=>a.start-b.start||b.end-a.end),out:{item:T;lane:number;lanes:number}[]=[];
 let group:{item:T;lane:number;lanes:number}[]=[],ends:number[]=[],groupEnd=-Infinity;
 const flush=()=>{for(const g of group)g.lanes=ends.length;out.push(...group);group=[];ends=[];};
 for(const item of sorted){
  if(item.start>=groupEnd&&group.length)flush();
  let lane=ends.findIndex(e=>e<=item.start);if(lane<0){lane=ends.length;ends.push(item.end);}else ends[lane]=item.end;
  group.push({item,lane,lanes:0});groupEnd=Math.max(group.length===1?-Infinity:groupEnd,item.end);
 }
 if(group.length)flush();
 return out;
}
