// SPDX-License-Identifier: MIT
// Maps cockpitHistoryV1 into the study pages' shapes. Sources are this device's tools, joined to a subscription only
// through the producer's current binding (owner D-D: shown as local records). A day or hour without an observation
// stays null, never zero, and the page says nothing about days before the recording began.
import {ht} from './host-text.js';
import {costView} from './prototype-cost.js';
import type {WireCockpitData} from '../generated/wire.js';
import {overviewCost,type OverviewCost} from './overview-cost.js';

const HOUR=36e5,DAYS=182,LONG_DAYS=30;
const dayKey=(at:number)=>{const d=new Date(at);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
/** Hour series keyed by the producer's own bucket instants. The nominal grid steps in whole absolute hours from a local anchor,
 * which is not where a bucket falls after a fractional-offset change (Lord Howe's 30-minute fall-back), so a recorded instant
 * is never floored into a grid slot: it is added as its own slot and keeps its wall-clock hour. */
function hourSeries(grid:number[],rows:ReadonlyArray<{at:string;source:string;observedOutputTokens:number}>,sources:ReadonlySet<string>,to:number){
 const from=grid[0]!,at=new Set(grid);
 for(const b of rows){const ms=Date.parse(b.at);if(sources.has(b.source)&&ms>=from&&ms<=to)at.add(ms);}
 const instants=[...at].sort((a,b)=>a-b),index=new Map(instants.map((ms,i)=>[ms,i] as const)),values:(number|null)[]=instants.map(()=>null);
 for(const b of rows){const i=index.get(Date.parse(b.at));if(sources.has(b.source)&&i!==undefined)values[i]=(values[i]??0)+b.observedOutputTokens;}
 return {instants,values};
}
const startOfDay=(key:string)=>{const [y,m,d]=key.split('-').map(Number);return new Date(y!,m!-1,d!).getTime();};

export interface HistoryView {
 readonly daily:readonly {accountId:string;values:(number|null)[];imported:(number|null)[];coverageStart:number}[];
 readonly hourly:readonly {accountId:string;instants:number[];values:(number|null)[]}[];
 /** D390: the same hourly series over the 30 days the wire keeps (D402), for the day-by-hour heatmap. */
 readonly hourlyLong:readonly {accountId:string;instants:number[];values:(number|null)[]}[];
 readonly projectRanking:{recent7d:unknown[];recent30d:unknown[]};
 readonly paceHistory:Record<string,Record<string,unknown[]>>;
 /** ≈cost per day and hour for the overview bars (WP-12); null without priced usage. */
 readonly cost:OverviewCost|null;
 /** WP-13: the Models page's usage list, by model id, observed output tokens per range. */
 readonly modelRanking:{recent7d:{top:{name:string;tokens:number}[]};recent30d:{top:{name:string;tokens:number}[]}};
 /** WP-13 + WP-06: the producer's ≈cost (US dollars) per model id for the 7- and 30-day ranges, and each range's total; absent without price data. */
 readonly modelCost:{recent7d:Readonly<Record<string,number>>;recent30d:Readonly<Record<string,number>>;total:{recent7d:number|null;recent30d:number|null}};
}
const kinds:Readonly<Record<string,string>>={five_hour:'5h',weekly:'week',monthly:'month'};
export const noHistory:HistoryView={daily:[],hourly:[],hourlyLong:[],projectRanking:{recent7d:[],recent30d:[]},paceHistory:{},cost:null,modelRanking:{recent7d:{top:[]},recent30d:{top:[]}},modelCost:{recent7d:{},recent30d:{},total:{recent7d:null,recent30d:null}}};

export function historyView(data:WireCockpitData|null|undefined,ids:ReadonlyMap<string,string>,now:number,locale:string):HistoryView {
 const h=data?.history;if(!h||h.coverage!=='local-history')return noHistory;
 const daily:{accountId:string;values:(number|null)[];imported:(number|null)[];coverageStart:number}[]=[],hourly:{accountId:string;instants:number[];values:(number|null)[]}[]=[],hourlyLong:{accountId:string;instants:number[];values:(number|null)[]}[]=[];
 const first=h.dailyFrom?startOfDay(h.dailyFrom):null;
 // Local top of the hour, which is not a UTC hour in a fractional-offset zone. Steps stay absolute, so a repeated
 // daylight-saving hour keeps its own bucket.
 const clock=new Date(now),top=now-clock.getMinutes()*6e4-clock.getSeconds()*1e3-clock.getMilliseconds();
 const instants=Array.from({length:24},(_,i)=>top-(23-i)*HOUR);
 // The study pages read a series from its end, so index 181 is today and the days before the record began stay null.
 // D390 (macrevb-1212-1) + D402: from local midnight 29 days ago (30 local days, today included) to the current hour, in absolute
 // steps, so a 25-hour fall-back day keeps every hour the producer records (a fixed 720 hours would drop its first one).
 const firstDay=new Date(clock.getFullYear(),clock.getMonth(),clock.getDate()-(LONG_DAYS-1)).getTime(),longInstants=Array.from({length:Math.max(1,Math.floor((top-firstDay)/HOUR)+1)},(_,i)=>firstDay+i*HOUR);
 const end=new Date(now),days=Array.from({length:DAYS},(_,i)=>dayKey(new Date(end.getFullYear(),end.getMonth(),end.getDate()-(DAYS-1-i)).getTime()));
 for(const sub of h.subscriptions){
  const accountId=ids.get(sub.subscriptionRef);if(!accountId)continue;
  const sources=new Set(sub.sources.map(s=>s.source));
  if(first!==null){
   // A day's value is live and imported output together; `imported` is the imported part alone (null: none), so the chart can
   // draw a day that only older, imported history covers lighter. Imported history never replaces a live figure.
   const byDay=new Map<string,number>(),importedByDay=new Map<string,number>();
   for(const b of h.daily)if(sources.has(b.source)){byDay.set(b.at,(byDay.get(b.at)??0)+b.observedOutputTokens);if(b.origin==='import')importedByDay.set(b.at,(importedByDay.get(b.at)??0)+b.observedOutputTokens);}
   daily.push({accountId,values:days.map(day=>byDay.get(day)??null),imported:days.map(day=>importedByDay.get(day)??null),coverageStart:first});
  }
  hourly.push({accountId,...hourSeries(instants,h.hourly,sources,top)});
  hourlyLong.push({accountId,...hourSeries(longInstants,h.hourly,sources,top)});
 }
 const projects=(rows:typeof h.projects.recent7d)=>rows.map((p,i)=>({project:p.label??ht(locale,'host.projectN',{n:i+1}),tokens:p.observedOutputTokens,tokenScope:'combined',share:p.share,configs:[{model:p.model??'',effort:p.effort,recommendedEffort:null}]}));
 const paceHistory:Record<string,Record<string,unknown[]>>={};
 for(const group of h.cycles){
  const accountId=ids.get(group.subscriptionRef),kind=kinds[group.kind];if(!accountId||!kind)continue;
  (paceHistory[accountId]??={})[kind]=group.cycles.map(c=>({start:c.startedAt,end:c.resetsAt,points:c.points,hadDrop:c.hadDrop,spent:c.spent.map(s=>({model:s.model??'',effort:s.effort,fast:s.fast,points:s.points}))}));
 }
 const models=(w:{top:ReadonlyArray<{name:string;observedOutputTokens:number}>})=>({top:w.top.map(e=>({name:e.name,tokens:e.observedOutputTokens}))});
 const cv=costView(data,now),costOf=(range:'last7d'|'last30d')=>Object.fromEntries((cv?.models[range]??[]).flatMap(r=>r.cost&&r.cost.usd>=0&&r.model!=='unknown'?[[r.model,r.cost.usd] as const]:[]));

 return {daily,hourly,hourlyLong,projectRanking:{recent7d:projects(h.projects.recent7d),recent30d:projects(h.projects.recent30d)},paceHistory,cost:overviewCost(data,ids,now),modelRanking:{recent7d:models(h.models.recent7d),recent30d:models(h.models.recent30d)},
  modelCost:{recent7d:costOf('last7d'),recent30d:costOf('last30d'),total:{recent7d:cv?.total.last7d.cost?.usd??null,recent30d:cv?.total.last30d.cost?.usd??null}}};
}

/** The 7|30 usage block for one subscription: several linked tools add up; an unknown kind stays unknown. */
export function usageStats(data:WireCockpitData|null|undefined,ref:string|null|undefined){
 const sources=ref?data?.history?.subscriptions.find(s=>s.subscriptionRef===ref)?.sources:undefined;if(!sources?.length)return null;
 const add=(a:number|null|undefined,b:number|null|undefined)=>a==null||b==null?null:a+b;
 const window=(key:'recent7d'|'recent30d')=>{
  const sums=sources.map(s=>s[key]),one=sums.length===1?sums[0]!.generationTps:null;
  return {sums:{totalTokens:sums.map(s=>s.totalTokens??null).reduce(add),inputTokens:sums.map(s=>s.inputTokens).reduce(add),observedOutputTokens:sums.map(s=>s.outputTokens).reduce((a,b)=>a+b,0),cacheReadTokens:sums.map(s=>s.cacheReadTokens).reduce(add),cacheWriteTokens:sums.map(s=>s.cacheWriteTokens).reduce(add)},
   metrics:{generationTps:one===null?{status:'unknown',value:null}:{status:'ok',value:one}}};
 };
 return {recent7d:window('recent7d'),recent30d:window('recent30d')};
}

/** Reset history for one subscription, newest first: each closed cycle's reset, and public confirmed resets. A drop
 * inside a cycle is shown as a correction, because the readings cannot prove a banked reset was used. */
export function resetHistory(data:WireCockpitData|null|undefined,ref:string|null|undefined,rowId:string,now:number) {
 const rows:{kind:string;at:number;source:string}[]=[];
 for(const group of data?.history?.cycles??[]){
  const kind=kinds[group.kind];if(group.subscriptionRef!==ref||!kind)continue;
  for(const c of group.cycles){const at=Date.parse(c.resetsAt);if(Number.isFinite(at)&&at<=now)rows.push({kind,at,source:c.hadDrop?'correction':'natural'});}
 }
 for(const e of data?.details?.resetEvents??[])if(e.rowId===rowId&&e.status==='confirmed'){const at=Date.parse(e.publishedAt);if(Number.isFinite(at))for(const kind of new Set(rows.map(r=>r.kind)))rows.push({kind,at,source:'official'});}
 return rows.sort((a,b)=>b.at-a.at);
}
