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
 return data.details?{...data,details:{...data.details,sessions:data.details.sessions.map(s=>s.projectLabel===null?s:{...s,projectLabel:null})}}:data;
}

// A producer-current observation ceases to be current at its deadline, even
// when the containing account and other windows are still current.
export function currentWindow(account:WireAccount,window:WireWindow,now:number):boolean {
 return account.valueState==='current' && window.current && window.remainingPercent!==null && window.validUntil!==null && Date.parse(window.validUntil)>now;
}
export function displayWindow(account:WireAccount,window:WireWindow,now:number):boolean {
 return account.valueState==='retained' || currentWindow(account,window,now);
}
