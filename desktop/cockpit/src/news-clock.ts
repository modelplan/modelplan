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
// none reads `expiresAt` for visibility any more. The engine has no seen-state on the wire yet, so the clock lives in the
// page's memory. The native app keeps its own (DockAttention `confirmedDotUntil`); until the engine or the host carries a
// shared one (`newsUntil` per event), a reopened page starts a fresh look and the 24 h cap still bounds it.
import type {WireResetEvent} from '../generated/wire.js';

export const NEWS_LOOK_MS=30*60_000;
export const NEWS_PRESENT_MS=3*3_600_000;
export const NEWS_CAP_MS=24*3_600_000;
/** A gap between two refreshes longer than this is not counted as present time (the Mac slept or the page was hidden). */
export const NEWS_STEP_MAX_MS=10*60_000;
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
 /** A render or tick at `now`; `present` is true while the cockpit is visible (open and not occluded). `looked` (default:
  *  `present`) says the user looked at the drawn items: in the cockpit an open page is a look; a surface that is shown
  *  without being looked at (the widget before a hover) passes false and is bounded by the present hours instead. */
 observe(events:readonly NewsEvent[],now:number,present:boolean,looked?:boolean):void;
 /** The cockpit's visibility changed at `now`. */
 present(value:boolean,now:number):void;
 /** Whether the event is news at `now`. */
 isNews(e:NewsEvent,now:number):boolean;
 /** The next moment one of `events` stops being news (for the host's deadline), or null. */
 nextChange(events:readonly NewsEvent[],now:number):number|null;
 /** Forget everything (a cleared view or a new store). */
 reset():void;
}

export function createNewsClock():NewsClock {
 const entries=new Map<string,Entry>();let shown=false;
 const capped=(e:NewsEvent,now:number)=>{const start=newsStart(e),cap=newsCap(e);return start!==null&&cap!==null&&now<cap?cap:null;};
 const endOf=(x:Entry,cap:number,now:number,present:boolean)=>Math.min(cap,x.firstLooked===null?Infinity:x.firstLooked+NEWS_LOOK_MS,present?now+Math.max(0,NEWS_PRESENT_MS-x.present):Infinity);
 const clock:NewsClock={
  observe(events,now,present,looked=present){
   if(!Number.isFinite(now)||now<=0)return;
   shown=present;
   const live=new Set<string>();
   for(const e of events){
    const cap=capped(e,now),key=newsKey(e);if(cap===null)continue;live.add(key);
    let x=entries.get(key);
    // The clock starts when the item is first drawn while the user is present; until then only the 24 h cap applies.
    if(!x){if(!present)continue;x={firstLooked:null,present:0,last:null,end:cap};entries.set(key,x);}
    if(present){
     if(looked&&x.firstLooked===null)x.firstLooked=now;// the cockpit open with the item drawn is a look
     if(x.last!==null&&now>x.last)x.present+=Math.min(now-x.last,NEWS_STEP_MAX_MS);
     x.last=now;
    }else x.last=null;
    x.end=endOf(x,cap,now,present);
   }
   // Bounded memory: drop entries whose cap has passed; keep the rest even when an event is briefly missing from a reply.
   for(const [key,x] of entries)if(!live.has(key)&&x.end<=now)entries.delete(key);
   while(entries.size>MAX_ENTRIES){const first=entries.keys().next().value;if(first===undefined)break;entries.delete(first);}
  },
  present(value,now){
   for(const x of entries.values()){
    if(value&&x.last===null)x.last=now;
    if(!value&&x.last!==null){if(now>x.last)x.present+=Math.min(now-x.last,NEWS_STEP_MAX_MS);x.last=null;}
   }
   shown=value;
  },
  isNews(e,now){
   const cap=capped(e,now);if(cap===null)return false;
   const x=entries.get(newsKey(e));if(!x)return true;
   if(x.firstLooked!==null&&now>=x.firstLooked+NEWS_LOOK_MS)return false;
   const running=shown&&x.last!==null&&now>x.last?Math.min(now-x.last,NEWS_STEP_MAX_MS):0;
   return x.present+running<NEWS_PRESENT_MS;
  },
  nextChange(events,now){
   let next=Infinity;
   for(const e of events){
    if(!clock.isNews(e,now))continue;
    const cap=capped(e,now)!,x=entries.get(newsKey(e));
    next=Math.min(next,x?endOf(x,cap,now,shown):cap);
   }
   return Number.isFinite(next)&&next>now?next:null;
  },
  reset(){entries.clear();},
 };
 return clock;
}
/** The page's one clock: every cockpit surface reads it, and only the view (render, tick, visibility) moves it. */
export const newsClock:NewsClock=createNewsClock();
