// SPDX-License-Identifier: MIT
// Maps cockpitHistoryV1 into the study pages' shapes. Sources are this device's tools, joined to a subscription only
// through the producer's current binding (owner D-D: shown as local records). A day or hour without an observation
// stays null, never zero, and the page says nothing about days before the recording began.
import type {WireCockpitData} from '../generated/wire.js';

const HOUR=36e5,DAYS=182;
const dayKey=(at:number)=>{const d=new Date(at);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const startOfDay=(key:string)=>{const [y,m,d]=key.split('-').map(Number);return new Date(y!,m!-1,d!).getTime();};

export interface HistoryView {
 readonly daily:readonly {accountId:string;values:(number|null)[];coverageStart:number}[];
 readonly hourly:readonly {accountId:string;instants:number[];values:(number|null)[]}[];
 readonly projectRanking:{recent7d:unknown[];recent30d:unknown[]};
 readonly paceHistory:Record<string,Record<string,unknown[]>>;
}
const kinds:Readonly<Record<string,string>>={five_hour:'5h',weekly:'week',monthly:'month'};
export const noHistory:HistoryView={daily:[],hourly:[],projectRanking:{recent7d:[],recent30d:[]},paceHistory:{}};

export function historyView(data:WireCockpitData|null|undefined,ids:ReadonlyMap<string,string>,now:number,locale:string):HistoryView {
 const h=data?.history;if(!h||h.coverage!=='local-history')return noHistory;
 const daily:{accountId:string;values:(number|null)[];coverageStart:number}[]=[],hourly:{accountId:string;instants:number[];values:(number|null)[]}[]=[];
 const first=h.dailyFrom?startOfDay(h.dailyFrom):null;
 // Local top of the hour, which is not a UTC hour in a fractional-offset zone. Steps stay absolute, so a repeated
 // daylight-saving hour keeps its own bucket.
 const clock=new Date(now),top=now-clock.getMinutes()*6e4-clock.getSeconds()*1e3-clock.getMilliseconds();
 const instants=Array.from({length:24},(_,i)=>top-(23-i)*HOUR);
 // The study pages read a series from its end, so index 181 is today and the days before the record began stay null.
 const end=new Date(now),days=Array.from({length:DAYS},(_,i)=>dayKey(new Date(end.getFullYear(),end.getMonth(),end.getDate()-(DAYS-1-i)).getTime()));
 for(const sub of h.subscriptions){
  const accountId=ids.get(sub.subscriptionRef);if(!accountId)continue;
  const sources=new Set(sub.sources.map(s=>s.source));
  if(first!==null){
   const byDay=new Map<string,number>();for(const b of h.daily)if(sources.has(b.source))byDay.set(b.at,(byDay.get(b.at)??0)+b.observedOutputTokens);
   daily.push({accountId,values:days.map(day=>byDay.get(day)??null),coverageStart:first});
  }
  const values:(number|null)[]=instants.map(()=>null);
  for(const b of h.hourly){const index=Math.floor((Date.parse(b.at)-instants[0]!)/HOUR);if(sources.has(b.source)&&index>=0&&index<values.length)values[index]=(values[index]??0)+b.observedOutputTokens;}
  hourly.push({accountId,instants,values});
 }
 const projects=(rows:typeof h.projects.recent7d)=>rows.map((p,i)=>({project:p.label??(locale==='en'?`Project ${i+1}`:`项目 ${i+1}`),tokens:p.observedOutputTokens,tokenScope:'combined',share:p.share,configs:[{model:p.model??'',effort:p.effort,recommendedEffort:null}]}));
 const paceHistory:Record<string,Record<string,unknown[]>>={};
 for(const group of h.cycles){
  const accountId=ids.get(group.subscriptionRef),kind=kinds[group.kind];if(!accountId||!kind)continue;
  (paceHistory[accountId]??={})[kind]=group.cycles.map(c=>({start:c.startedAt,end:c.resetsAt,points:c.points,hadDrop:c.hadDrop,spent:c.spent.map(s=>({model:s.model??'',effort:s.effort,fast:s.fast,points:s.points}))}));
 }
 return {daily,hourly,projectRanking:{recent7d:projects(h.projects.recent7d),recent30d:projects(h.projects.recent30d)},paceHistory};
}

/** The 7|30 usage block for one subscription: several linked tools add up; an unknown kind stays unknown. */
export function usageStats(data:WireCockpitData|null|undefined,ref:string|null|undefined){
 const sources=ref?data?.history?.subscriptions.find(s=>s.subscriptionRef===ref)?.sources:undefined;if(!sources?.length)return null;
 const add=(a:number|null|undefined,b:number|null|undefined)=>a==null||b==null?null:a+b;
 const window=(key:'recent7d'|'recent30d')=>{
  const sums=sources.map(s=>s[key]),one=sums.length===1?sums[0]!.generationTps:null;
  return {sums:{inputTokens:sums.map(s=>s.inputTokens).reduce(add),observedOutputTokens:sums.map(s=>s.outputTokens).reduce((a,b)=>a+b,0),cacheReadTokens:sums.map(s=>s.cacheReadTokens).reduce(add),cacheWriteTokens:sums.map(s=>s.cacheWriteTokens).reduce(add)},
   metrics:{generationTps:one===null?{status:'unknown',value:null}:{status:'ok',value:one}}};
 };
 return {recent7d:window('recent7d'),recent30d:window('recent30d')};
}

/** Reset history for one subscription, newest first: each closed cycle's reset, and public confirmed resets. A drop
 * inside a cycle is shown as a correction, because the readings cannot prove a reset card was used. */
export function resetHistory(data:WireCockpitData|null|undefined,ref:string|null|undefined,rowId:string,now:number) {
 const rows:{kind:string;at:number;source:string}[]=[];
 for(const group of data?.history?.cycles??[]){
  const kind=kinds[group.kind];if(group.subscriptionRef!==ref||!kind)continue;
  for(const c of group.cycles){const at=Date.parse(c.resetsAt);if(Number.isFinite(at)&&at<=now)rows.push({kind,at,source:c.hadDrop?'correction':'natural'});}
 }
 for(const e of data?.details?.resetEvents??[])if(e.rowId===rowId&&e.status==='confirmed'){const at=Date.parse(e.publishedAt);if(Number.isFinite(at))for(const kind of new Set(rows.map(r=>r.kind)))rows.push({kind,at,source:'official'});}
 return rows.sort((a,b)=>b.at-a.at);
}
