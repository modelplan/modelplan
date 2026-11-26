// SPDX-License-Identifier: MIT
// ALERT lamp and alert list rule (owner D38, 2026-11-06). One shared source for the lamp, the column wash,
// the blink conditions and the public-screen list.
// - RED: a current window at or below the red line T (Settings threshold), which includes an exhausted window.
//   "Credits being drawn" is red too, but no reader reports it yet, so it never appears here.
// - AMBER: a quota forecast to run out before its reset while still above T (cockpitForecastV1). An engine
//   that does not negotiate it creates no amber condition.
//   WP-03: a forecast whose reset time is unknown is amber too ("约40m用完" with no reset part).
// - Public reset announcements/confirmations, lower-effort advice and banked resets expiring within 48 hours are
//   list-only (blue); they never light the lamp. Credits being drawn and non-reset official notices have no producer
//   field yet, so they are not listed.
// - ALR-51 (WP-11, V1-FINAL §11, §12): a subscription that cannot be read, and a retained (stale) reading, are grey:
//   list-only, never lit, never a column wash; a grey row opens Settings › Subscriptions.
// Every red, amber and unreadable line is the one shared sentence (study/rocket-r1/alert-sentence.js, ALR-50).
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';
import {currentWindow,runOutMinutes} from './prototype-data-adapter.js';
import {alertSentence,isUnreadable,openSettingsAction,resetsAvailable,type Both} from '../study/rocket-r1/alert-sentence.js';
import {tables} from '../study/rocket-r1/i18n.js';
import {relativeMoment,dhm} from '../study/rocket-r1/mfd-pages/fmt.js';
import '../study/rocket-r1/strings/common.js';
import '../study/rocket-r1/strings/mfd.js';
import '../study/rocket-r1/strings/host.js';

export type CautionLevel='red'|'amber';
/** ALR-51: red and amber light the lamp; blue (announced, not yet in effect) and grey (unreadable) are list-only. */
export type AlertLevel=CautionLevel|'blue'|'grey';
export const lights=<T extends {readonly level:AlertLevel}>(item:T):item is T&{readonly level:CautionLevel}=>item.level==='red'||item.level==='amber';
export interface CautionItem {
 /** Stable per condition and window cycle: a reset or a cleared-then-returning condition is a new condition. */
 readonly id:string; /** Identity of the caution itself: tool, window and severity. Unlike `id` it survives a refresh that moves the reset time. */ readonly stable:string; readonly level:AlertLevel; readonly member:string;
 /** ALR-50: the shared sentence (with the reset when known); `short` drops the reset for a place it does not fit. */
 readonly text:Both; readonly short?:Both;
 /** CKP-MFD-55: the alert list's second line (available resets, or the Settings action of a grey row). */
 readonly detail?:Both;
 /** The row's tooltip, for an entry whose uncertainty the sentence cannot carry (a tentative published peak). */
 readonly tip?:Both;
 /** CKP-MFD-56: a grey row opens Settings › Subscriptions instead of selecting the subscription. */
 readonly settings?:true;
 /** A grey row is either a retained (stale) reading or one that cannot be read at all (WP-12: only the latter merge). */
 readonly kind?:'stale'|'unreadable';
 /** G3-106: the reset moment of the window cycle an amber forecast caution belongs to. The forecast comes and goes with
  *  the recent usage rate, so for amber only a new cycle (or a red escalation) is a recurrence, never a paused forecast. */
 readonly cycle?:number;
}
/** A window with a real current reading, with what tells its cycles apart. */
export interface ReadWindow {readonly resetAt:number|null;readonly span:number|null;/** The window's remaining percent; tells a refill (a new allowance) from a paused forecast when no reset time is known. */readonly remaining?:number|null}
const span=(minutes:number)=>minutes<60?`${Math.max(0,Math.round(minutes))}m`:minutes<1440?`${Math.floor(minutes/60)}h${String(Math.round(minutes%60)).padStart(2,'0')}`:`${Math.floor(minutes/1440)}d${Math.floor(minutes%1440/60)}h`;
const rank={red:0,amber:1,blue:2,grey:3} as const;
// Both languages from the study's string tables (strings/common.js, strings/mfd.js), so the copy stays the study's.
const both=(key:string,vars:(lang:'en'|'zh-CN')=>Record<string,string>)=>{const one=(lang:'en'|'zh-CN')=>{const v=vars(lang);return String(tables[lang][key]??key).replace(/\{(\w+)\}/g,(m,n)=>v[n]??m);};return {en:one('en'),zh:one('zh-CN')};};
const nameOf=(row:{name:{en:string;zh:string}},lang:'en'|'zh-CN')=>lang==='en'?row.name.en:row.name.zh;
const LADDER=['Low','Med','High','XHigh','Max'] as const;
const ladderLevel=(v:unknown)=>{if(typeof v!=='string')return -1;const aliases:Readonly<Record<string,number>>={low:0,med:1,medium:1,high:2,xhigh:3,max:4};return aliases[v.toLowerCase()]??-1;};
const finite=(v:unknown):v is number=>typeof v==='number'&&Number.isFinite(v);

export function cautionItems(data:WireCockpitData,now:number,redBelow:number):CautionItem[] {
 const lamp:{item:CautionItem;remaining:number;resetAt:number}[]=[],list:CautionItem[]=[],grey:CautionItem[]=[];
 const members=cockpitMembers(data),verified=new Set(data.subscriptions.map(s=>s.subscriptionRef));
 // CKP-MFD-55: available resets (banked resets with time left), joined only through a verified reference.
 // The producer may list only part of the cards (state partial, truncated, or a count above the items), so a count of the
 // visible items is exact only for a complete list: `partial` makes the line say "resets available" without a number.
 const cardFacts=(key:string,unstable:boolean)=>{
  if(unstable||!verified.has(key))return null;
  const details=data.details?.subscriptions.filter(s=>s.subscriptionRef===key)??[],cards=details.length===1?details[0]!.resetCards:null;
  if(!cards||cards.state==='unknown')return null;
  const items=cards.items??[],partial=cards.truncated||cards.state!=='complete'||(cards.count!==null&&cards.count>items.length);
  return {items,partial};
 };
 const available=(key:string,unstable:boolean)=>{
  const f=cardFacts(key,unstable);if(!f)return null;
  const n=f.items.filter(c=>{const at=c.expiresAt?Date.parse(c.expiresAt):NaN;return !Number.isFinite(at)||at>now;}).length;
  return n?{n,partial:f.partial}:null;
 };
 const subscription=(row:{name:{en:string;zh:string}})=>({en:row.name.en,zh:row.name.zh});
 for(const {key,row,account,unstable} of members){
  if(account.valueState==='retained'){
   const at=account.observedAt?Date.parse(account.observedAt):NaN,age=Number.isFinite(at)?span((now-at)/60000):null;
   grey.push({id:JSON.stringify(['stale',key]),stable:JSON.stringify(['stale',key]),level:'grey',kind:'stale',member:key,settings:true,detail:openSettingsAction(),text:age?both('host.alStaleAge',lang=>({s:nameOf(row,lang),age})):both('host.alStale',lang=>({s:nameOf(row,lang)}))});
   continue;
  }
  if(account.valueState==='none'){
   const code=account.lastFailure?.code??null;
   if(isUnreadable(code)){const s=alertSentence({kind:'unreadable',subscription:subscription(row),cause:code});grey.push({id:JSON.stringify(['unread',key,code]),stable:JSON.stringify(['unread',key]),level:'grey',kind:'unreadable',member:key,settings:true,detail:openSettingsAction(),text:s.text,short:s.short});}
   continue;
  }
  const extra=available(key,unstable),detail=extra?{detail:resetsAvailable(extra.partial?null:extra.n)}:{};
  for(const w of account.windows){
   if(!currentWindow(account,w,now)||w.remainingPercent===null)continue;
   const resetAt=w.resetsAt?Date.parse(w.resetsAt):NaN,resetMinutes=Number.isFinite(resetAt)&&resetAt>now?(resetAt-now)/60000:null;
   const out=runOutMinutes(data,row.id,account,w,now,true);
   const s=alertSentence({kind:'quota',subscription:subscription(row),window:{en:w.label.en,zh:w.label.zh},remaining:w.remainingPercent,runOutMinutes:out,resetMinutes});
   if(w.remainingPercent>redBelow){
    if(out!==null)lamp.push({remaining:w.remainingPercent,resetAt:Number.isFinite(resetAt)?resetAt:Infinity,item:{id:JSON.stringify([key,w.id,w.resetsAt,'forecast']),stable:JSON.stringify([key,w.id,'amber']),level:'amber',member:key,...(Number.isFinite(resetAt)?{cycle:resetAt}:{}),text:s.text,short:s.short,...detail}});
    continue;
   }
   lamp.push({remaining:w.remainingPercent,resetAt:Number.isFinite(resetAt)?resetAt:Infinity,item:{id:JSON.stringify([key,w.id,w.resetsAt]),stable:JSON.stringify([key,w.id,'red']),level:'red',member:key,text:s.text,short:s.short,...detail}});
  }
 }
 // ALR-51 / CKP-MFD-56: the producer drops the Dock surface from a signed-out or unreadable tool row, so such a row is not
 // a cockpit member (no tab, column, HUD row or lamp). Its grey line still belongs in the alert list: it is read from the
 // rows the menu or Settings admit, list-only, and adds no member. A row with no surface at all stays hidden.
 const taken=new Set(members.map(m=>m.key));
 for(const row of data.projection.rows){
  if(row.kind!=='tool'||row.surfaces.includes('dock')||!(row.surfaces.includes('menu')||row.surfaces.includes('settings')))continue;
  if(row.state==='off'||row.consent==='unset'||row.consent==='retired')continue;
  const accounts=row.accounts.length?row.accounts:[null];
  for(const account of accounts){
   if(account&&account.valueState!=='none')continue;
   const ref=account?.subscriptionRef,key=ref&&verified.has(ref)?ref:`${row.id}#${account?.route??'row'}`;
   if(taken.has(key))continue;
   const code=account?.lastFailure?.code??row.reason.code;
   if(!isUnreadable(code))continue;
   taken.add(key);
   const s=alertSentence({kind:'unreadable',subscription:subscription(row),cause:code});
   grey.push({id:JSON.stringify(['unread',key,code]),stable:JSON.stringify(['unread',key]),level:'grey',kind:'unreadable',member:key,settings:true,detail:openSettingsAction(),text:s.text,short:s.short});
  }
 }
 // CKP-MFD-28 (study mfd-adapter.js resetAlert): an announced public reset is placed at its window's middle, to the
 // half hour; a date-only or missing schedule has no time to show. Never the user's own reset.
 for(const e of data.details?.resetEvents??[]){
  if(!(Date.parse(e.expiresAt)>now))continue;const m=members.find(m=>m.row.id===e.rowId&&(!e.planIds?.length||e.planIds.includes(m.account.plan.id)));if(!m)continue;// a plan-scoped announcement belongs to that plan's subscription only (CKP-MFD-56)
  const s=(lang:'en'|'zh-CN')=>lang==='en'?m.row.name.en:m.row.name.zh,id=JSON.stringify(['reset',e.id]),stable=id;
  // D166/D428: only reset_credit is a banked reset; a direct reset and a legacy event with no kind use the direct wording.
  const bank=e.kind==='reset_credit';
  if(e.status==='confirmed'){list.push({id,stable,level:'blue',member:m.key,text:both(bank?'mfd.alBankedConf':'mfd.alResetConf',lang=>({s:s(lang)}))});continue;}
  const from=e.schedule?Date.parse(e.schedule.from):NaN,through=e.schedule?Date.parse(e.schedule.through):NaN;
  const mid=e.schedule&&e.schedule.precision!=='date'&&Number.isFinite(from)?Number.isFinite(through)?(from+through)/2:from:null;
  const at=mid===null?null:Math.round(mid/(30*60000))*30*60000;
  list.push({id,stable,level:'blue',member:m.key,text:at===null?both(bank?'mfd.alBankedSoon':'mfd.alResetSoon',lang=>({s:s(lang)})):both(bank?'mfd.alBankedAnn':'mfd.alResetAnn',lang=>({s:s(lang),at:relativeMoment(at,{now,lang})}))});
 }
 // D63: banked resets that expire within 48 hours, one blue line per subscription. Personal facts are joined
 // only through a verified reference, as the Subscription page joins them. List-only: they never light the lamp.
 for(const m of members){
  if(m.unstable||!verified.has(m.key))continue;
  const f=cardFacts(m.key,false);if(!f)continue;
  const n=f.items.filter(c=>{const at=c.expiresAt?Date.parse(c.expiresAt):NaN;return Number.isFinite(at)&&at>now&&at-now<=48*3600e3;}).length;
  if(!n)continue;
  list.push({id:JSON.stringify(['cards',m.key,n]),stable:JSON.stringify(['cards',m.key]),level:'blue',member:m.key,text:both(f.partial?'host.alCardsSome':n===1?'host.alCardsOne':'host.alCardsMany',lang=>({s:nameOf(m.row,lang),n:String(n)}))});
 }
 // D63: a declared plan's published peak-rate window (cockpitPeaksV1), from the same time-of-day windows the CLI's
 // advice reads. Blue and list-only; a peak already over is not listed. Unlike the reset-card loop above, unstable members
 // are not skipped: a peak window is publication data, not a personal reading that may be wrong.
 for(const peak of data.details?.peaks??[]){
  const m=members.find(x=>x.row.id===peak.rowId),start=Date.parse(peak.startsAt),end=peak.endsAt?Date.parse(peak.endsAt):NaN;
  if(!m||!Number.isFinite(start)||(Number.isFinite(end)&&end<=now))continue;
  const s=(lang:'en'|'zh-CN')=>lang==='en'?m.row.name.en:m.row.name.zh,id=JSON.stringify(['peak',peak.rowId,peak.startsAt]),stable=JSON.stringify(['peak',peak.rowId]);
  // A peak the producer did not confirm (a tool-read ZCode subscription, or a tentative window) says so, in the sentence and the tooltip.
  const tentative=peak.status!=='confirmed',tip=tentative?both('host.alPeakTip',()=>({})):undefined;
  if(start<=now){list.push({id,stable,level:'blue',member:m.key,tip,text:tentative?both('host.alPeakNowT',lang=>({s:s(lang)})):{en:`${s('en')} ${tables.en['mfd.peak']} · ${tables.en['mfd.peakNow']}`,zh:`${s('zh-CN')} ${tables['zh-CN']['mfd.peak']} · ${tables['zh-CN']['mfd.peakNow']}`}});continue;}
  const wait=(start-now)/60000;
  if(Number.isFinite(end))list.push({id,stable,level:'blue',member:m.key,tip,text:both(tentative?'host.alPeakT':'alert.peak',lang=>({s:s(lang),in:dhm(wait),dur:dhm((end-start)/60000)}))});
  else list.push({id,stable,level:'blue',member:m.key,tip,text:both(tentative?'host.alPeakOpenT':'host.alPeakOpen',lang=>({s:s(lang),in:dhm(wait)}))});
 }
 // CKP-MFD-55: tightest first within a colour: the lowest remaining, then the soonest reset.
 lamp.sort((a,b)=>rank[a.item.level]-rank[b.item.level]||a.remaining-b.remaining||a.resetAt-b.resetAt);
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
  advice.push({id:JSON.stringify(['advice',x.subscriptionRef,x.sessionRef,LADDER[cur]]),stable:JSON.stringify(['advice',x.subscriptionRef,x.sessionRef]),level:'blue',member:x.subscriptionRef,text:both('alert.advice',()=>({m:model.name,e:LADDER[cur]!,rec:LADDER[rec]!,cost,abl}))});
 }
 return [...lamp.map(x=>x.item),...advice,...list,...grey].sort((a,b)=>rank[a.level]-rank[b.level]);
}
/** The lamp shows the most severe condition; list-only items never light it. */
export function cautionLevel(items:readonly CautionItem[],member?:string):CautionLevel|null {
 const own=member===undefined?items:items.filter(x=>x.member===member);
 return own.some(x=>x.level==='red')?'red':own.some(x=>x.level==='amber')?'amber':null;
}

/** Windows that have a real current reading right now, keyed `[member, window]`. A condition is cleared only for these:
 *  a pending, stale or missing read says nothing about whether the caution is over. */
export function readWindows(data:WireCockpitData,now:number):Map<string,ReadWindow> {
 const out=new Map<string,ReadWindow>();
 for(const {key,account} of cockpitMembers(data)){
  if(account.valueState==='retained')continue;
  for(const w of account.windows)if(currentWindow(account,w,now)&&w.remainingPercent!==null){
   const at=w.resetsAt?Date.parse(w.resetsAt):NaN;
   out.set(JSON.stringify([key,w.id]),{resetAt:Number.isFinite(at)?at:null,span:finite(w.durationSeconds)&&w.durationSeconds>0?w.durationSeconds*1000:null,remaining:w.remainingPercent});
  }
 }
 return out;
}
