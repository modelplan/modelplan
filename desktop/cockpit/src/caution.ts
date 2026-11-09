// SPDX-License-Identifier: MIT
// ALERT lamp and alert list rule (owner D38, 2026-11-06). One shared source for the lamp, the column wash,
// the blink conditions and the public-screen list.
// - RED: a current window at or below the red line T (Settings threshold), which includes an exhausted window.
//   "Credits being drawn" is red too, but no reader reports it yet, so it never appears here.
// - AMBER: a quota forecast to run out before its reset while still above T (cockpitForecastV1). An engine
//   that does not negotiate it creates no amber condition.
// - Public reset announcements/confirmations, lower-effort advice, extra resets expiring within 48 hours and stale
//   (retained) readings are list-only (blue); they never light the lamp. Credits being drawn, peak hours and
//   non-reset official notices have no producer field yet, so they are not listed.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {currentWindow,runOutMinutes} from './prototype-data-adapter.js';
import {tables} from '../study/rocket-r1/i18n.js';
import {relativeMoment} from '../study/rocket-r1/mfd-pages/fmt.js';
import '../study/rocket-r1/strings/common.js';
import '../study/rocket-r1/strings/mfd.js';

export type CautionLevel='red'|'amber';
export interface CautionItem {
 /** Stable per condition and window cycle: a reset or a cleared-then-returning condition is a new condition. */
 readonly id:string; readonly level:CautionLevel|'blue'; readonly member:string;
 readonly text:{readonly en:string;readonly zh:string};
}
const span=(minutes:number)=>minutes<60?`${Math.max(0,Math.round(minutes))}m`:minutes<1440?`${Math.floor(minutes/60)}h${String(Math.round(minutes%60)).padStart(2,'0')}`:`${Math.floor(minutes/1440)}d${Math.floor(minutes%1440/60)}h`;
const rank={red:0,amber:1,blue:2} as const;
// Both languages from the study's string tables (strings/common.js, strings/mfd.js), so the copy stays the study's.
const both=(key:string,vars:(lang:'en'|'zh-CN')=>Record<string,string>)=>{const one=(lang:'en'|'zh-CN')=>{const v=vars(lang);return String(tables[lang][key]??key).replace(/\{(\w+)\}/g,(m,n)=>v[n]??m);};return {en:one('en'),zh:one('zh-CN')};};
const LADDER=['Low','Med','High','XHigh','Max'] as const;
const ladderLevel=(v:unknown)=>{if(typeof v!=='string')return -1;const aliases:Readonly<Record<string,number>>={low:0,med:1,medium:1,high:2,xhigh:3,max:4};return aliases[v.toLowerCase()]??-1;};
const finite=(v:unknown):v is number=>typeof v==='number'&&Number.isFinite(v);

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
 // CKP-MFD-28 (study mfd-adapter.js resetAlert): an announced public reset is placed at its window's middle, to the
 // half hour; a date-only or missing schedule has no time to show. Never the user's own reset.
 for(const e of data.details?.resetEvents??[]){
  if(!(Date.parse(e.expiresAt)>now))continue;const m=members.find(m=>m.row.id===e.rowId);if(!m)continue;
  const s=(lang:'en'|'zh-CN')=>lang==='en'?m.row.name.en:m.row.name.zh,id=JSON.stringify(['reset',e.id]);
  if(e.status==='confirmed'){list.push({id,level:'blue',member:m.key,text:both('mfd.alResetConf',lang=>({s:s(lang)}))});continue;}
  const from=e.schedule?Date.parse(e.schedule.from):NaN,through=e.schedule?Date.parse(e.schedule.through):NaN;
  const mid=e.schedule&&e.schedule.precision!=='date'&&Number.isFinite(from)?Number.isFinite(through)?(from+through)/2:from:null;
  const at=mid===null?null:Math.round(mid/(30*60000))*30*60000;
  list.push({id,level:'blue',member:m.key,text:at===null?both('mfd.alResetSoon',lang=>({s:s(lang)})):both('mfd.alResetAnn',lang=>({s:s(lang),at:relativeMoment(at,{now,lang})}))});
 }
 // D63: extra resets (reset cards) that expire within 48 hours, one blue line per subscription. Personal facts are joined
 // only through a verified reference, as the Subscription page joins them. List-only: they never light the lamp.
 const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef));
 for(const m of members){
  if(m.unstable||!verified.has(m.key))continue;
  const details=data.details?.subscriptions.filter(s=>s.subscriptionRef===m.key)??[],cards=details.length===1?details[0]!.resetCards:null;
  if(!cards||cards.state==='unknown')continue;
  const n=(cards.items??[]).filter(c=>{const at=c.expiresAt?Date.parse(c.expiresAt):NaN;return Number.isFinite(at)&&at>now&&at-now<=48*3600e3;}).length;
  if(!n)continue;
  list.push({id:JSON.stringify(['cards',m.key,n]),level:'blue',member:m.key,text:{en:`${m.row.name.en} · ${n} ${n===1?'reset expires':'resets expire'} within 48 hours`,zh:`${m.row.name.zh} · 重置次数中有 ${n} 次将在 48 小时内到期`}});
 }
 lamp.sort((a,b)=>a.remaining-b.remaining||a.resetAt-b.resetAt);
 // CKP-MFD-27 (study core.js alerts): on a red quota, each running session of that subscription above its model's
 // recommended effort gets one blue line naming the lower effort, its cost multiple and ability change. The advice stays
 // inside the tool in use: never another model, tool or time of day. It is list-only and never lights the lamp.
 const advice:CautionItem[]=[],red=new Set(lamp.filter(x=>x.item.level==='red').map(x=>x.item.member)),models=data.details?.publication?.models??[];
 for(const x of data.details?.sessions??[]){
  if(x.state!=='running'||!x.subscriptionRef||!red.has(x.subscriptionRef))continue;
  const model=models.find(m=>m.id===x.model),cur=ladderLevel(x.effort),rec=ladderLevel(model?.recommended);if(!model||cur<0||rec<0||cur<=rec)continue;
  const row=(level:number)=>model.efforts.find(e=>ladderLevel(e.effort)===level),now_=row(cur),best=row(rec);
  if(!now_||!best||!finite(now_.cost)||!finite(best.cost)||now_.cost<=0||!finite(now_.ability)||!finite(best.ability))continue;
  const cost=(best.cost/now_.cost).toFixed(2),abl=(best.ability-now_.ability).toFixed(1).replace('-','−');
  advice.push({id:JSON.stringify(['advice',x.subscriptionRef,x.sessionRef,LADDER[cur]]),level:'blue',member:x.subscriptionRef,text:both('alert.advice',()=>({m:model.name,e:LADDER[cur]!,rec:LADDER[rec]!,cost,abl}))});
 }
 return [...lamp.map(x=>x.item),...advice,...list].sort((a,b)=>rank[a.level]-rank[b.level]);
}
/** The lamp shows the most severe condition; list-only items never light it. */
export function cautionLevel(items:readonly CautionItem[],member?:string):CautionLevel|null {
 const own=member===undefined?items:items.filter(x=>x.member===member);
 return own.some(x=>x.level==='red')?'red':own.some(x=>x.level==='amber')?'amber':null;
}
