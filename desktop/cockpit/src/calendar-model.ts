// SPDX-License-Identifier: MIT
// D466 calendar and time system: the one item list behind every time surface of the cockpit (the subscription column's
// 24 h strip, its hover card, and the big screen's 日历 tab). Pure: shaped from the display data the page already has.
//
// Classes (calendar-system.md §1): own period resets (5 h, weekly, monthly), time rules (peaks), forecasts (run-out),
// announcements (official limit or banked resets) and the reserve's expiry. An announcement is "news" only for its news
// clock (src/news-clock.ts); a timed one stays on the strip and calendar until its time passes, and after its news clock a
// past chip turns muted but stays on its date. Multi-day facts are one item on the day that matters, never a span.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {calendarFromCockpit,cardFacts} from './calendar-data.js';
import {currentWindow} from './prototype-data-adapter.js';
import {newsClock,newsMark} from './news-clock.js';
import {addDays,startOfDay} from './calendar-time.js';

export const DAY=86_400_000;
export interface CalSub {readonly key:string;readonly name:{readonly en:string;readonly zh:string};readonly colour:string;readonly rules:boolean}
export type CalKind='reset5h'|'resetWeek'|'resetMonth'|'peak'|'runout'|'official'|'credit'|'reserve';
export interface CalItem {
 readonly sub:number;readonly kind:CalKind;
 /** The moment (a reset, a run-out, a timed announcement) or the start of a peak. All-day items: any time on their day. */
 readonly at:number;
 /** A peak's end (null: no end published inside the horizon). */
 readonly end:number|null;
 readonly allDay:boolean;
 readonly tentative:boolean;
 /** Announcements: their status, and whether they are news now (the news clock). */
 readonly status:'announced'|'confirmed'|null;
 readonly news:boolean;
 /** The announcement's news mark (data-news), drawn only while it is news so the clock sees only rendered news. */
 readonly mark:string|null;
 /** The monthly window's own name ("MCP"), for the 30-day list. */
 readonly label:{readonly en:string;readonly zh:string}|null;
 /** A weekly reset projected past the next one (the window's fixed length), for the 7- and 30-day views. */
 readonly projected:boolean;
 /** An announced window that spans several days: its last moment, so the words can name the range (the item sits on its first day). */
 readonly until:number|null;
}
export interface CalModel {readonly now:number;readonly subs:readonly CalSub[];readonly items:readonly CalItem[]}

const ms=(v:string|null|undefined)=>{const t=v?Date.parse(v):NaN;return Number.isFinite(t)?t:null;};
const item=(x:Partial<CalItem>&Pick<CalItem,'sub'|'kind'|'at'>):CalItem=>({end:null,allDay:false,tentative:false,status:null,news:false,mark:null,label:null,projected:false,until:null,...x});

/** Every time item of the user's own subscriptions from `now` on (and today's earlier all-day items), `horizon` days ahead. */
export function calendarModel(data:WireCockpitData,now:number,horizon=31):CalModel {
 // No transport cap here: the fixed page reads every admitted subscription (macrev2-1291-7).
 const members=cockpitMembers(data),shaped=calendarFromCockpit(data,now,false),end=addDays(startOfDay(now),horizon);
 const subs:CalSub[]=members.map((m,i)=>({key:m.key,name:shaped.subs[i]?.name??m.row.name,colour:shaped.subs[i]?.colour??'#c6ccd4',rules:m.row.id==='zai'||m.row.id.startsWith('declared:')}));
 const items:CalItem[]=[];
 for(const p of shaped.peaks)if(p.from<end)items.push(item({sub:p.sub,kind:'peak',at:p.from,end:p.to,tentative:p.tentative}));
 for(const r of shaped.resets){
  items.push(item({sub:r.sub,kind:r.kind==='5h'?'reset5h':'resetWeek',at:r.at}));
  // A weekly window resets every 7 days: the next ones are known from the reading, marked as projected.
  if(r.kind==='week')for(let t=r.at+7*DAY;t<end;t+=7*DAY)items.push(item({sub:r.sub,kind:'resetWeek',at:t,projected:true}));
 }
 // Monthly windows (MCP and other monthly limits): their next reset, named.
 members.forEach((m,sub)=>{for(const w of m.account.windows){
  if(w.role!=='monthly'||!currentWindow(m.account,w,now))continue;const at=ms(w.resetsAt);if(at===null||at<=now||at>=end)continue;
  if(!items.some(x=>x.sub===sub&&x.kind==='resetMonth'&&x.at===at))items.push(item({sub,kind:'resetMonth',at,label:{en:w.label.en,zh:w.label.zh}}));
 }});
 // Forecast run-outs: the engine's forecast for a shown window, while it is still ahead.
 for(const f of data.details?.forecasts??[]){
  const sub=members.findIndex(m=>m.key===f.subscriptionRef||m.account.subscriptionRef===f.subscriptionRef),at=ms(f.runsOutAt);
  if(sub<0||at===null||at<=now||at>=end)continue;
  const window=members[sub]!.account.windows.find(w=>w.id===f.windowId);if(!window||!currentWindow(members[sub]!.account,window,now))continue;
  if(!items.some(x=>x.sub===sub&&x.kind==='runout'&&x.at===at))items.push(item({sub,kind:'runout',at}));
 }
 // Announcements for the user's own plans (macrev2-1291-5). An official limit window sits on the day it STARTS (a
 // multi-day window names its range in the words; never its midpoint). A banked reset is a reserve event, not a clock
 // event: one all-day item on the day it was issued (its stated day, else when it was confirmed or published).
 for(const e of data.details?.resetEvents??[]){
  const sub=members.findIndex(m=>m.row.id===e.rowId&&(!e.planIds?.length||e.planIds.includes(m.account.plan.id)));
  const published=ms(e.publishedAt),expires=ms(e.expiresAt);if(sub<0||published===null||expires===null||expires<=now)continue;
  const from=e.schedule?ms(e.schedule.from):null,through=e.schedule?ms(e.schedule.through):null;
  const dated=e.schedule?.precision==='date'&&from!==null?startOfDay(from):null;
  if(e.kind==='reset_credit'){
   const issued=dated??(from!==null?startOfDay(from):null)??(e.status==='confirmed'?ms(e.confirmedAt)??published:published);
   if(issued>=end)continue;
   items.push(item({sub,kind:'credit',at:issued,allDay:true,status:e.status,news:newsClock.isNews(e,now),mark:newsMark(e)}));continue;
  }
  const timed=e.schedule&&e.schedule.precision!=='date'?from:null;
  const day=dated??(e.status==='confirmed'?ms(e.confirmedAt)??published:from??published);
  const at=timed??day;if(at>=end)continue;
  const last=through!==null&&through>at&&startOfDay(through)>startOfDay(at)?through:null;
  items.push(item({sub,kind:'official',at,allDay:timed===null,status:e.status,news:newsClock.isNews(e,now),mark:newsMark(e),until:last}));
 }
 // The reserve's expiry: one all-day item per known expiry day (never a bar from now to it). A partial inventory states
 // only its own earliest expiry, so no later date is invented.
 members.forEach((m,sub)=>{
  const days=new Set<number>();
  for(const at of cardFacts(data,m,now)?.expiries??[]){const d=startOfDay(at);if(at>=end||days.has(d))continue;days.add(d);items.push(item({sub,kind:'reserve',at,allDay:true}));}
 });
 items.sort((a,b)=>Number(b.allDay)-Number(a.allDay)||a.at-b.at||a.sub-b.sub);
 return {now,subs,items};
}
/** The model for one subscription only (the "只看 X" filter), or the whole model for null. */
export function filterModel(model:CalModel,key:string|null):CalModel {
 const at=key===null?-1:model.subs.findIndex(s=>s.key===key);if(at<0)return model;
 return {now:model.now,subs:[model.subs[at]!],items:model.items.filter(x=>x.sub===at).map(x=>({...x,sub:0}))};
}
/** Items that fall inside [from, to): a peak overlapping it counts. */
export const within=(items:readonly CalItem[],from:number,to:number)=>items.filter(x=>x.kind==='peak'?x.at<to&&(x.end??x.at+1)>from:x.at>=from&&x.at<to);
