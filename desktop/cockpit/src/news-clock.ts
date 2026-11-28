// SPDX-License-Identifier: MIT
// D466 / DOCK-3.7-05 (owner D166, 2026-11-12, extended to every surface on 2026-11-26): the news clock of a public reset
// announcement. One clock per event and status (a confirmation starts a fresh one). An item is news from its start
// (confirmation, or publication for an announcement) until the first of:
//   1. 30 minutes after the user first looks at it (in the cockpit: the cockpit is open while it is drawn);
//   2. 3 present hours (the cockpit visible), counted from the host's refresh and tick timestamps only;
//   3. 24 hours after its start (and never past the event's own expiry).
// No timers and no wakeups: the clock moves only when the page is rendered or ticked, and reports its next change as a
// deadline so the host's existing tick redraws the page then.
//
// Every cockpit surface reads this one clock (the key dot, the reserve "+1", the alert list, the calendar's news line);
// none reads `expiresAt` for visibility any more.
//
// Shared with the native app (#1289): the app owns the persisted clock (`DockNewsClock`, news-clock.json, per
// eventID#status). A host that has it sends a `news` message with `newsUntil` per announcement
// (`EngineDockContentProvider.isNews`); its answer then decides for those events, and the page reports each first look
// back (`newsLook` action → `recordNewsLook`), so a look in the cockpit also retires the widget dot. Without such a host
// (an older app, tests) the page keeps the same rule in its own memory: a reopened page then starts a fresh look, and the
// 24 h cap still bounds it.
import type {WireCockpitData,WireResetEvent} from '../generated/wire.js';
import {cockpitMembers} from './members.js';

export const NEWS_LOOK_MS=30*60_000;
export const NEWS_PRESENT_MS=3*3_600_000;
export const NEWS_CAP_MS=24*3_600_000;
/** A gap between two present refreshes counts as present time only when it is at most this long; a longer gap (the Mac
 *  slept or was locked, with no visibility change) counts nothing. The same 15-minute rule as the app's DockNewsClock. */
export const NEWS_STEP_MAX_MS=15*60_000;
const presentGap=(from:number|null,to:number)=>from!==null&&to>from&&to-from<=NEWS_STEP_MAX_MS?to-from:0;
const MAX_ENTRIES=64;

export type NewsEvent=Pick<WireResetEvent,'id'|'status'|'publishedAt'|'expiresAt'>&{readonly confirmedAt?:string};
interface Entry {firstLooked:number|null;present:number;last:number|null;end:number}
const ms=(v:string|undefined|null)=>{const t=v?Date.parse(v):NaN;return Number.isFinite(t)?t:null;};
export const newsKey=(e:NewsEvent)=>`${e.id}\u0000${e.status}`;
/** When the event's clock starts: its confirmation (or publication when no confirmation time is known), or its publication. */
export function newsStart(e:NewsEvent):number|null {return e.status==='confirmed'?ms(e.confirmedAt)??ms(e.publishedAt):ms(e.publishedAt);}
/** The hard end of the clock: 24 h after its start, never past the event's own expiry. */
export function newsCap(e:NewsEvent):number|null {
 const start=newsStart(e),expires=ms(e.expiresAt);if(start===null)return null;
 return Math.min(start+NEWS_CAP_MS,expires??Infinity);
}

export interface NewsClock {
 /** A render or tick at `now` (returns whether a first look was recorded); `present` is true while the cockpit is visible (open and not occluded). `looked` (default:
  *  `present`) says the user looked at the drawn items: in the cockpit an open page is a look; a surface that is shown
  *  without being looked at (the widget before a hover) passes false and is bounded by the present hours instead. */
 observe(events:readonly NewsEvent[],now:number,present:boolean,looked?:boolean):boolean;
 /** The cockpit's visibility changed at `now`. */
 present(value:boolean,now:number):void;
 /** Whether the event is news at `now`. */
 isNews(e:NewsEvent,now:number):boolean;
 /** The next moment one of `events` stops being news (for the host's deadline), or null. */
 nextChange(events:readonly NewsEvent[],now:number):number|null;
 /** D466 shared clock: the host's answer per event and status (`until` null = not news). Replaces earlier answers. */
 host(items:readonly {readonly id:string;readonly status:NewsEvent['status'];readonly until:number|null}[]):void;
 /** Called with the events first looked at in this page (the host records them in the shared clock). */
 onLook(report:((events:{id:string;status:NewsEvent['status']}[],at:number)=>void)|null):void;
 /** Forget everything (a cleared view or a new store). */
 reset():void;
}

export function createNewsClock():NewsClock {
 const entries=new Map<string,Entry>(),answers=new Map<string,number|null>();let shown=false,reporter:((events:{id:string;status:NewsEvent['status']}[],at:number)=>void)|null=null;
 const hostUntil=(e:NewsEvent):number|null|undefined=>answers.has(newsKey(e))?answers.get(newsKey(e)):undefined;
 const capped=(e:NewsEvent,now:number)=>{const start=newsStart(e),cap=newsCap(e);return start!==null&&cap!==null&&now<cap?cap:null;};
 const endOf=(x:Entry,cap:number,now:number,present:boolean)=>Math.min(cap,x.firstLooked===null?Infinity:x.firstLooked+NEWS_LOOK_MS,present?now+Math.max(0,NEWS_PRESENT_MS-x.present):Infinity);
 const clock:NewsClock={
  observe(events,now,present,looked=present){
   if(!Number.isFinite(now)||now<=0)return false;
   shown=present;
   const live=new Set<string>(),looks:{id:string;status:NewsEvent['status']}[]=[];
   for(const e of events){
    const cap=capped(e,now),key=newsKey(e);if(cap===null)continue;live.add(key);
    let x=entries.get(key);
    // The clock starts when the item is first drawn while the user is present; until then only the 24 h cap applies.
    if(!x){if(!present)continue;x={firstLooked:null,present:0,last:null,end:cap};entries.set(key,x);}
    if(present){
     if(looked&&x.firstLooked===null){x.firstLooked=now;looks.push({id:e.id,status:e.status});}// the cockpit open with the item drawn is a look
     x.present+=presentGap(x.last,now);
     x.last=now;
    }else x.last=null;
    x.end=endOf(x,cap,now,present);
   }
   // Bounded memory: drop entries whose cap has passed; keep the rest even when an event is briefly missing from a reply.
   for(const [key,x] of entries)if(!live.has(key)&&x.end<=now)entries.delete(key);
   while(entries.size>MAX_ENTRIES){const first=entries.keys().next().value;if(first===undefined)break;entries.delete(first);}
   if(looks.length&&reporter){try{reporter(looks,now);}catch{/* reporting never breaks a render */}}
   return looks.length>0;
  },
  present(value,now){
   for(const x of entries.values()){
    if(value&&x.last===null)x.last=now;
    if(!value&&x.last!==null){x.present+=presentGap(x.last,now);x.last=null;}
   }
   shown=value;
  },
  isNews(e,now){
   const cap=capped(e,now);if(cap===null)return false;
   const until=hostUntil(e);if(until!==undefined)return until!==null&&now<until;
   const x=entries.get(newsKey(e));if(!x)return true;
   if(x.firstLooked!==null&&now>=x.firstLooked+NEWS_LOOK_MS)return false;
   const running=shown?presentGap(x.last,now):0;
   return x.present+running<NEWS_PRESENT_MS;
  },
  nextChange(events,now){
   let next=Infinity;
   for(const e of events){
    if(!clock.isNews(e,now))continue;
    const cap=capped(e,now)!,x=entries.get(newsKey(e)),until=hostUntil(e);
    next=Math.min(next,until!==undefined?until??cap:x?endOf(x,cap,now,shown):cap);
   }
   return Number.isFinite(next)&&next>now?next:null;
  },
  host(items){answers.clear();for(const x of items.slice(0,MAX_ENTRIES))answers.set(newsKey({id:x.id,status:x.status,publishedAt:'',expiresAt:''}),x.until);},
  onLook(report){reporter=report;},
  reset(){entries.clear();answers.clear();},
 };
 return clock;
}
/** D474 §5.1: an undated announcement (no schedule) that is never confirmed retires 48 h after publication. */
export const NEWS_UNDATED_RETIRE_MS=48*3_600_000;
/** macrevb-1290-7: a direct reset counts as applied only when a window's current cycle began at or after its confirmation.
 *  The only tolerance is clock skew between the provider's reset stamp and the confirmation stamp: reset times arrive at
 *  whole-second or whole-minute precision, so 60 s covers rounding plus ordinary clock drift while a cycle that began
 *  minutes before the confirmation (the previous cycle) never counts. */
export const NEWS_RESTART_SKEW_MS=60_000;
/** D474 §5.1 retirements beyond the clock itself: (a) an undated, never-confirmed announcement 48 h after publication;
 *  (b) a confirmed direct reset once the reading shows its window restarted (DOCK-3.7-03: a longer-than-5h window of that
 *  subscription whose current cycle started at or after the confirmation, within NEWS_RESTART_SKEW_MS). A confirmed banked reset never clears this
 *  way: the credit stays in the reserve until it is used. */
export function newsRetired(e:WireResetEvent,data:WireCockpitData,now:number):boolean {
 const published=ms(e.publishedAt);
 if(e.status==='announced'&&!e.schedule&&published!==null&&now>=published+NEWS_UNDATED_RETIRE_MS)return true;
 if(e.status!=='confirmed'||e.kind==='reset_credit')return false;
 const confirmed=ms(e.confirmedAt)??published;if(confirmed===null)return false;
 for(const m of cockpitMembers(data,true)){
  if(m.row.id!==e.rowId||(e.planIds?.length&&!e.planIds.includes(m.account.plan.id))||m.account.valueState!=='current')continue;
  for(const w of m.account.windows){
   const reset=ms(w.resetsAt),span=w.durationSeconds;
   if(!w.current||reset===null||span===null||span<=18000||reset<=now)continue;
   if(reset-span*1000>=confirmed-NEWS_RESTART_SKEW_MS)return true;
  }
 }
 return false;
}
/** Whether a reset event is news on the cockpit now: the shared clock, minus the retirements above. Every surface (key
 *  dot, reserve "+1", alert list, calendar news line) asks this. */
export const newsLive=(e:WireResetEvent,data:WireCockpitData,now:number):boolean=>!newsRetired(e,data,now)&&newsClock.isNews(e,now);
/** D466 (macrevb-1290-1): the announcements the cockpit can draw: those of a shown subscription (its row, and its plan
 *  when the announcement names plans). One hidden in Settings, or of a tool the user does not have, is drawn nowhere, so
 *  the clock never records a look at it; its clock starts when the subscription is shown. */
export function drawnNews(data:WireCockpitData,now?:number):WireResetEvent[] {
 const members=cockpitMembers(data);
 return (data.details?.resetEvents??[]).filter(e=>members.some(m=>m.row.id===e.rowId&&(!e.planIds?.length||e.planIds.includes(m.account.plan.id)))&&(now===undefined||!newsRetired(e,data,now)));
}
/** D466 (macrevb-1290-1 round 2): the mark a surface puts on what it draws for an announcement (`data-news`, space
 *  separated). The clock records a look only for marks rendered on screen in this paint. */
export const newsMark=(e:Pick<NewsEvent,'id'|'status'>)=>`${encodeURIComponent(e.id)}#${e.status}`;
/** The marks rendered inside `root` now: connected, laid out (not hidden, not on another page or bank). */
export function renderedMarks(root:ParentNode):Set<string> {
 const out=new Set<string>();
 for(const e of root.querySelectorAll<HTMLElement>('[data-news]')){
  if(!e.isConnected||!e.getClientRects().length||e.closest('[hidden]'))continue;
  for(const mark of (e.dataset.news??'').split(' '))if(mark)out.add(mark);
 }
 return out;
}
/** The page's one clock: every cockpit surface reads it, and only the view (render, tick, visibility) moves it. */
export const newsClock:NewsClock=createNewsClock();
