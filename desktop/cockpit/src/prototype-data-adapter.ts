// SPDX-License-Identifier: MIT
// Preserve the producer's nulls, empty lists and zero values; join only the
// verified subscription references already admitted by the wire projection.
import type {WireAccount,WireWindow,WireCockpitData,WireCockpitDetails} from '../generated/wire.js';
export interface PrototypeEngineSupplement {
 readonly todayTokens:number|null; readonly todayAverageGenerationTps:number|null;
 readonly resetCards:WireCockpitDetails['subscriptions'][number]['resetCounts']|null;
 readonly reserveCredits:WireAccount['credits'];
}
export function prototypeEngineSupplement(account:WireAccount,data?:WireCockpitData):PrototypeEngineSupplement {
 const ref=account.subscriptionRef;
 const verified=ref!==null&&data?.subscriptions.some(s=>s.subscriptionRef===ref);
 const matches=verified?data?.details?.subscriptions.filter(s=>s.subscriptionRef===ref)??[]:[];
 const detail=matches.length===1?matches[0]:null;
 // Multiple sources cannot be averaged without their underlying denominators.
 const eligible=detail?.today.filter(t=>t.bindingBasis==='source-wide-current-binding'&&t.observedOutputTokens>=0&&(t.generationTps===null||t.generationTps>=0))??[];
 const today=eligible.length===1&&detail?.today.length===1?eligible[0]:null;
 const wireCredits=detail?.credits;
 return {todayTokens:today?.observedTotalTokens??today?.observedOutputTokens??null,todayAverageGenerationTps:today?.generationTps??null,resetCards:detail?.resetCounts??null,
  reserveCredits:wireCredits?{balance:wireCredits.balance,unit:'credits'}:detail?null:account.credits};
}
export const cockpitDetails=(data:WireCockpitData)=>data.details;
// Settings "Project names" off: labels and session titles are dropped before any surface or accessibility text sees
// them (macrevb-1303-3: with project names off, no project or session name reaches the DOM). References, kinds,
// counts and tokens stay, so the rows still group and rank.
export function withoutProjectNames(data:WireCockpitData):WireCockpitData {
 // A project whose name the page hides is still a project: its state becomes hidden, a session with none stays none.
 const unname=<T extends {projectLabel:string|null;projectState?:'named'|'unnamed'|'hidden'|'none';title?:string|null}>(s:T):T=>{
  const {title:_title,...rest}=s;const out={...rest,projectLabel:null,...(s.projectLabel!==null&&s.projectState&&s.projectState!=='none'?{projectState:'hidden' as const}:{})} as T;
  return 'title' in s&&s.title===null?{...out,title:null}:out;};
 const details=data.details?{...data.details,sessions:data.details.sessions.map(unname),
  ...(data.details.recentSessions?{recentSessions:data.details.recentSessions.map(unname)}:{})}:data.details;
 const hide=<T extends {label:string|null}>(rows:readonly T[])=>rows.map(p=>p.label===null?p:{...p,label:null});
 const usageWindow=(w:NonNullable<NonNullable<WireCockpitData['history']>['usage']>['today'])=>({...w,projects:hide(w.projects),
  sessions:w.sessions.map(x=>({...x,title:null,projectLabel:null,projectState:x.projectState==='none'?x.projectState:'hidden' as const}))});
 // namesHidden tells the page a missing project name is withheld, not unknown (it reads 项目名已隐藏, not 未命名项目).
 const usage=data.history?.usage?{...data.history.usage,namesHidden:true,today:usageWindow(data.history.usage.today),recent7d:usageWindow(data.history.usage.recent7d),recent30d:usageWindow(data.history.usage.recent30d)}:undefined;
 const history=data.history?{...data.history,projects:{recent7d:hide(data.history.projects.recent7d),recent30d:hide(data.history.projects.recent30d)},...(usage?{usage}:{})}:data.history;
 return {...data,details,history};
}

// A producer-current observation ceases to be current at its deadline, even
// when the containing account and other windows are still current.
export function currentWindow(account:WireAccount,window:WireWindow,now:number):boolean {
 return account.valueState==='current' && window.current && window.remainingPercent!==null && window.validUntil!==null && Date.parse(window.validUntil)>now;
}
// Minutes until the engine's forecast run-out. Only a current window qualifies, and a forecast that has
// passed or no longer falls before a known reset is not shown. WP-03: the engine also forecasts a window whose reset time
// is unknown (from the burn rate); `unknownReset` admits that one (the alert model, ALR-51), with no reset to beat.
export function runOutMinutes(data:WireCockpitData|null|undefined,rowId:string,account:WireAccount,window:WireWindow,now:number,unknownReset=false):number|null {
 const ref=account.subscriptionRef,f=ref?data?.details?.forecasts?.find(x=>x.source===rowId&&x.subscriptionRef===ref&&x.windowId===window.id):undefined;
 if(!f?.runsOutAt||(!window.resetsAt&&!unknownReset)||!currentWindow(account,window,now))return null;
 const at=Date.parse(f.runsOutAt),reset=window.resetsAt?Date.parse(window.resetsAt):Infinity;
 return at>now&&at<reset?(at-now)/60000:null;
}
/** The prototype's fields: a negative trend marks the window whose run-out the account's forecast names. */
export const runOutFields=(minutes:number|null)=>({trend:minutes===null?null:-1,runOutMin:minutes});
export const forecastOf=(windows:readonly {trend:number|null;runOutMin:number|null}[])=>{const w=windows.find(x=>x.trend!==null&&x.trend<0);return w?{runOutMin:w.runOutMin}:null;};
export function displayWindow(account:WireAccount,window:WireWindow,now:number):boolean {
 return account.valueState==='retained' || currentWindow(account,window,now);
}

// A window limited to named models or a named pool is a 专项 / scoped extra:
// listed under its subscription, never chosen as the plan-wide tightest window.
export function scopedWindow(window:WireWindow):boolean {
 return (window.modelScope?.models?.length??0)>0 || window.poolKey!=='main';
}

// G3-109: a money balance in its reported ISO 4217 currency ("$12.34"); a money balance without a valid code is a
// plain two-decimal number. Null for anything that is not a finite money balance.
export function moneyText(credits:WireAccount['credits'],locale:'en'|'zh-CN'):string|null {
 const value=credits?.balance;if(!credits||credits.unit!=='money'||typeof value!=='number'||!Number.isFinite(value))return null;
 if(credits.currency&&/^[A-Z]{3}$/.test(credits.currency)){try{return new Intl.NumberFormat(locale,{style:'currency',currency:credits.currency,minimumFractionDigits:2,maximumFractionDigits:2}).format(value);}catch{/* an unknown code falls through */}}
 return new Intl.NumberFormat(locale,{minimumFractionDigits:2,maximumFractionDigits:2}).format(value);
}
