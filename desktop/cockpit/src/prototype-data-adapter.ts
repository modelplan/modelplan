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
 return {todayTokens:today?.observedOutputTokens??null,todayAverageGenerationTps:today?.generationTps??null,resetCards:detail?.resetCounts??null,
  reserveCredits:wireCredits?{balance:wireCredits.balance,unit:'credits'}:detail?null:account.credits};
}
export const cockpitDetails=(data:WireCockpitData)=>data.details;
// Settings "Project names" off: labels are dropped before any surface or accessibility text sees them.
export function withoutProjectNames(data:WireCockpitData):WireCockpitData {
 const details=data.details?{...data.details,sessions:data.details.sessions.map(s=>s.projectLabel===null?s:{...s,projectLabel:null}),
  ...(data.details.recentSessions?{recentSessions:data.details.recentSessions.map(s=>s.projectLabel===null?s:{...s,projectLabel:null})}:{})}:data.details;
 const hide=<T extends {label:string|null}>(rows:readonly T[])=>rows.map(p=>p.label===null?p:{...p,label:null});
 const history=data.history?{...data.history,projects:{recent7d:hide(data.history.projects.recent7d),recent30d:hide(data.history.projects.recent30d)}}:data.history;
 return {...data,details,history};
}

// A producer-current observation ceases to be current at its deadline, even
// when the containing account and other windows are still current.
export function currentWindow(account:WireAccount,window:WireWindow,now:number):boolean {
 return account.valueState==='current' && window.current && window.remainingPercent!==null && window.validUntil!==null && Date.parse(window.validUntil)>now;
}
// Minutes until the engine's forecast run-out. Only a current window qualifies, and a forecast that has
// passed or no longer falls before the reset is not shown.
export function runOutMinutes(data:WireCockpitData|null|undefined,rowId:string,account:WireAccount,window:WireWindow,now:number):number|null {
 const ref=account.subscriptionRef,f=ref?data?.details?.forecasts?.find(x=>x.source===rowId&&x.subscriptionRef===ref&&x.windowId===window.id):undefined;
 if(!f?.runsOutAt||!window.resetsAt||!currentWindow(account,window,now))return null;
 const at=Date.parse(f.runsOutAt),reset=Date.parse(window.resetsAt);
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
