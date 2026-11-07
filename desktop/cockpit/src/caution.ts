// SPDX-License-Identifier: MIT
// ALERT lamp and alert list rule (owner D38, 2026-11-06). One shared source for the lamp, the column wash,
// the blink conditions and the public-screen list.
// - RED: a current window at or below the red line T (Settings threshold), which includes an exhausted window.
//   "Credits being drawn" is red too, but no reader reports it yet, so it never appears here.
// - AMBER: a quota forecast to run out before its reset while still above T (cockpitForecastV1). An engine
//   that does not negotiate it creates no amber condition.
// - Public reset announcements/confirmations and stale (retained) readings are list-only (blue); they never
//   light the lamp.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {currentWindow,runOutMinutes} from './prototype-data-adapter.js';

export type CautionLevel='red'|'amber';
export interface CautionItem {
 /** Stable per condition and window cycle: a reset or a cleared-then-returning condition is a new condition. */
 readonly id:string; readonly level:CautionLevel|'blue'; readonly member:string;
 readonly text:{readonly en:string;readonly zh:string};
}
const span=(minutes:number)=>minutes<60?`${Math.max(0,Math.round(minutes))}m`:minutes<1440?`${Math.floor(minutes/60)}h${String(Math.round(minutes%60)).padStart(2,'0')}`:`${Math.floor(minutes/1440)}d${Math.floor(minutes%1440/60)}h`;
const rank={red:0,amber:1,blue:2} as const;

export function cautionItems(data:WireCockpitData,now:number,redBelow:number):CautionItem[] {
 const lamp:{item:CautionItem;remaining:number;resetAt:number}[]=[],list:CautionItem[]=[];
 for(const {key,row,account} of cockpitMembers(data)){
  if(account.valueState==='retained'){
   const at=account.observedAt?Date.parse(account.observedAt):NaN,age=Number.isFinite(at)?span((now-at)/60000):null;
   list.push({id:JSON.stringify(['stale',key]),level:'blue',member:key,text:{en:`${row.name.en} · Last reading${age?` ${age} ago`:''}`,zh:`${row.name.zh} · 上次读数${age?` ${age}前`:''}`}});
   continue;
  }
  for(const w of account.windows){
   if(!currentWindow(account,w,now)||w.remainingPercent===null)continue;
   const r=Math.round(w.remainingPercent),resetAt=w.resetsAt?Date.parse(w.resetsAt):NaN,left=Number.isFinite(resetAt)&&resetAt>now?span((resetAt-now)/60000):null;
   if(w.remainingPercent>redBelow){
    if(left&&runOutMinutes(data,row.id,account,w,now)!==null)lamp.push({remaining:w.remainingPercent,resetAt,item:{id:JSON.stringify([key,w.id,w.resetsAt,'forecast']),level:'amber',member:key,
     text:{en:`${row.name.en} ${w.label.en} ${r}% · won't last ${left}`,zh:`${row.name.zh} ${w.label.zh} ${r}% · 撑不到 ${left} 后重置`}}});
    continue;
   }
   lamp.push({remaining:w.remainingPercent,resetAt:Number.isFinite(resetAt)?resetAt:Infinity,item:{id:JSON.stringify([key,w.id,w.resetsAt]),level:'red',member:key,
    text:{en:`${row.name.en} ${w.label.en} ${r}% left${left?` · resets in ${left}`:''}`,zh:`${row.name.zh} ${w.label.zh} 剩 ${r}%${left?` · ${left}后重置`:''}`}}});
  }
 }
 const members=cockpitMembers(data);
 for(const e of data.details?.resetEvents??[]){
  if(!(Date.parse(e.expiresAt)>now))continue;const m=members.find(m=>m.row.id===e.rowId);if(!m)continue;
  const confirmed=e.status==='confirmed';
  list.push({id:JSON.stringify(['reset',e.id]),level:'blue',member:m.key,text:{en:`${m.row.name.en} · ${confirmed?'Reset confirmed':'Reset announced'}`,zh:`${m.row.name.zh} · ${confirmed?'重置已确认':'重置已公布'}`}});
 }
 lamp.sort((a,b)=>a.remaining-b.remaining||a.resetAt-b.resetAt);
 return [...lamp.map(x=>x.item),...list].sort((a,b)=>rank[a.level]-rank[b.level]);
}
/** The lamp shows the most severe condition; list-only items never light it. */
export function cautionLevel(items:readonly CautionItem[],member?:string):CautionLevel|null {
 const own=member===undefined?items:items.filter(x=>x.member===member);
 return own.some(x=>x.level==='red')?'red':own.some(x=>x.level==='amber')?'amber':null;
}
