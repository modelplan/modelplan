// SPDX-License-Identifier: MIT
// ≈cost (WP-06, D291): what the counted tokens would cost at each model's public API list price. It is an
// estimate, not what a subscription charges, so the page labels it "≈" and never colours it as a status.
// The producer computes it on this device; this module only sums the wire's buckets. Usage without a
// public price counts in tokens and in the unpriced share, never in ≈cost. No price means no figure:
// a range without priced usage has cost null, never $0.
import type {WireCockpitData,WireCockpitCost} from '../generated/wire.js';

export type CostRange='today'|'last7d'|'last30d';
export const costRanges:readonly CostRange[]=['today','last7d','last30d'];
/** usd: the estimate; approximate: part of it could not apply a long-context price per request (tooltip line). */
export interface EstCost { readonly usd:number; readonly approximate:boolean }
export interface CostSum {
 readonly cost:EstCost|null;
 readonly tokens:number;
 /** Unpriced tokens ÷ all tokens, 0…1; null without tokens. Shown as "x% of use has no public price". */
 readonly unpricedShare:number|null;
}
export interface CostModelRow {
 readonly model:string; // published model ID, or "unknown"
 readonly cost:EstCost|null; // null: no public API price
 readonly tokens:number;
 /** Share of the range's ≈cost; null for a model without a price (COST-54 falls back to tokenShare). */
 readonly share:number|null;
 readonly tokenShare:number;
}
export interface CostBar { readonly at:string; readonly subscriptionRef:string|null; readonly usd:number }
export interface CostView {
 readonly pricesAsOf:string|null;
 readonly total:Readonly<Record<CostRange,CostSum>>;
 /** Per verified subscription, through the producer's one current source binding. */
 readonly bySubscription:ReadonlyMap<string,Readonly<Record<CostRange,CostSum>>>;
 /** Overview bars: per local day (last 30) and per local hour (last 48), stacked by subscription. */
 readonly daily:readonly CostBar[];
 readonly hourly:readonly CostBar[];
 readonly models:Readonly<Record<CostRange,readonly CostModelRow[]>>;
}

const dayKey=(at:number)=>{const d=new Date(at);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const daysAgo=(now:number,n:number)=>{const d=new Date(now);return dayKey(new Date(d.getFullYear(),d.getMonth(),d.getDate()-n).getTime());};

/** Settings › Cockpit "Show estimated cost" off (SET-9-50): the ≈cost section is dropped before any surface sees it. */
export function withoutEstimatedCost(data:WireCockpitData):WireCockpitData {
 if(!data.history?.cost)return data;
 const {cost:_drop,...history}=data.history;
 return {...data,history};
}

const usable=(c:WireCockpitCost|null|undefined):c is WireCockpitCost=>!!c&&c.basis==='api-list-price'&&c.currency==='USD';

class Acc {
 usd=0;priced=0;unpriced=0;approximate=false;
 add(usd:number,priced:number,unpriced:number,approximate=false){this.usd+=usd;this.priced+=priced;this.unpriced+=unpriced;this.approximate||=approximate;}
 sum():CostSum{const tokens=this.priced+this.unpriced;return {cost:this.priced>0?{usd:this.usd,approximate:this.approximate}:null,tokens,unpricedShare:tokens>0?this.unpriced/tokens:null};}
}

/** The ≈cost view for the cockpit, or null when there is none (no published prices, or the setting is off). */
export function costView(data:WireCockpitData|null|undefined,now:number):CostView|null {
 const h=data?.history,c=h?.cost;if(!h||h.coverage!=='local-history'||!usable(c))return null;
 const owner=new Map<string,string>();
 for(const sub of h.subscriptions)if(data!.subscriptions.some(s=>s.subscriptionRef===sub.subscriptionRef))for(const s of sub.sources)owner.set(s.source,sub.subscriptionRef);
 const from:Record<CostRange,string>={today:daysAgo(now,0),last7d:daysAgo(now,6),last30d:daysAgo(now,29)},today=from.today;
 const total={today:new Acc(),last7d:new Acc(),last30d:new Acc()},subs=new Map<string,Record<CostRange,Acc>>();
 const daily=new Map<string,number>();
 for(const b of c.daily){
  if(b.at>today||b.at<from.last30d)continue;
  const ref=owner.get(b.source)??null;
  for(const r of costRanges){if(b.at<from[r])continue;total[r].add(b.estimatedUsd,b.pricedTokens,b.unpricedTokens,b.approximate);
   if(ref){const s=subs.get(ref)??{today:new Acc(),last7d:new Acc(),last30d:new Acc()};subs.set(ref,s);s[r].add(b.estimatedUsd,b.pricedTokens,b.unpricedTokens,b.approximate);}}
  if(b.pricedTokens>0){const k=`${b.at}\u0000${ref??''}`;daily.set(k,(daily.get(k)??0)+b.estimatedUsd);}
 }
 const hourly=new Map<string,number>();
 for(const b of c.hourly){const at=Date.parse(b.at);if(!Number.isFinite(at)||at>now||b.pricedTokens<=0)continue;const k=`${b.at}\u0000${owner.get(b.source)??''}`;hourly.set(k,(hourly.get(k)??0)+b.estimatedUsd);}
 // Bars run in time order: an hour's offset-bearing timestamp sorts by its instant, so the repeated hour of a
 // daylight-saving fall-back keeps its order.
 const instant=(at:string)=>{const t=Date.parse(at);return Number.isFinite(t)?t:0;};
 const bars=(m:Map<string,number>)=>[...m].map(([k,usd])=>{const [at,ref]=k.split('\u0000');return {at:at!,subscriptionRef:ref||null,usd};}).sort((a,b)=>instant(a.at)-instant(b.at)||(a.at<b.at?-1:a.at>b.at?1:0)||((a.subscriptionRef??'')<(b.subscriptionRef??'')?-1:1));
 // Shares are of the whole range (COST-54): the producer lists at most 64 model rows, so the denominators are the
 // range totals from the day buckets, never the sum of the listed rows.
 const models=(rows:WireCockpitCost['models']['today'],range:Acc):CostModelRow[]=>{
  const by=new Map<string,Acc>();for(const m of rows){const a=by.get(m.model)??new Acc();by.set(m.model,a);a.add(m.estimatedUsd??0,m.pricedTokens,m.unpricedTokens,m.approximate);}
  const usd=range.priced>0?range.usd:0,tokens=range.priced+range.unpriced;
  return [...by].map(([model,a])=>{const s=a.sum();return {model,cost:s.cost,tokens:s.tokens,share:s.cost&&usd>0?Math.min(1,s.cost.usd/usd):null,tokenShare:tokens>0?Math.min(1,s.tokens/tokens):0};})
   .sort((a,b)=>(b.cost?.usd??-1)-(a.cost?.usd??-1)||b.tokens-a.tokens||(a.model<b.model?-1:1));
 };
 const bySubscription=new Map<string,Record<CostRange,CostSum>>();
 for(const [ref,s] of subs)bySubscription.set(ref,{today:s.today.sum(),last7d:s.last7d.sum(),last30d:s.last30d.sum()});
 return {pricesAsOf:c.pricesAsOf,total:{today:total.today.sum(),last7d:total.last7d.sum(),last30d:total.last30d.sum()},bySubscription,
  daily:bars(daily),hourly:bars(hourly),models:{today:models(c.models.today,total.today),last7d:models(c.models.recent7d,total.last7d),last30d:models(c.models.recent30d,total.last30d)}};
}

/** One subscription's ≈cost per range, or null when the view has none for it (no ≈$ is drawn). */
export function subscriptionCost(view:CostView|null,ref:string|null|undefined):Readonly<Record<CostRange,EstCost|null>>|null {
 const s=ref?view?.bySubscription.get(ref):undefined;if(!s)return null;
 return {today:s.today.cost,last7d:s.last7d.cost,last30d:s.last30d.cost};
}

/** V1-FINAL §0: "≈$64". Below $100 two significant digits, from $100 whole dollars, from $1000 "≈$1.2k".
 * The same in both languages. A figure that rounds to nothing still says "<$0.01" rather than $0. */
export function estCostText(usd:number):string|null {
 if(!Number.isFinite(usd)||usd<0)return null;
 if(usd===0)return '≈$0';
 if(usd<0.01)return '<$0.01';
 if(usd<100)return `≈$${Number(usd.toPrecision(2))}`;
 if(usd<999.5)return `≈$${Math.round(usd)}`;
 const k=usd/1000;
 if(k<999.5)return `≈$${Number(k.toPrecision(k<100?2:3))}k`;
 return `≈$${Number((k/1000).toPrecision(2))}M`;
}

/** The band range row's figures for one subscription (D474 §2.5, G-a): total tokens, never output only.
 *  - 今天: Σ(pricedTokens + unpricedTokens) of `cost.daily` for today over the subscription's sources, counted only when each
 *    source serves exactly this one subscription; a source shared with another subscription (two Codex accounts) cannot be
 *    split, so the cell is `shared` (it shows `—` and the tool total in its hover).
 *  - 7天 / 30天: `history.subscriptions[].sources[].recentNd.totalTokens` (exact per subscription). When every source of the
 *    subscription binds only it, `cost.daily` gives the same figure the 总览 total reads, so the band equals 总览.
 *  Without prices (`cost` absent) there is no `cost.*` figure: the caller falls back to its output-token reading. */
export interface BandUsage {
 /** Total tokens in the range, or null when there is none (or when the source is shared). */
 readonly tokens:number|null;
 /** The cost basis the figure came from: the day buckets or the history sums. */
 readonly from:'cost'|'history'|null;
 /** Two or more subscriptions share a source of this one: the figure cannot be split. `total` is the tool's total in the range. */
 readonly shared:{readonly subscriptions:number;readonly total:number}|null;
 /** Unpriced tokens ÷ all tokens in the range (the "9% has no public price" note), null without tokens or without cost. */
 readonly unpricedShare:number|null;
 /** 7天 / 30天 only (G-b: 今天 has none): the token kinds behind the total, from the subscription's own history sums. */
 readonly kinds:{readonly input:number;readonly cacheWrite:number;readonly cacheRead:number;readonly output:number;readonly reasoning:number}|null;
}
export function bandUsage(data:WireCockpitData,ref:string|null,range:CockpitRangeKey,now:number):BandUsage {
 const none:BandUsage={tokens:null,from:null,shared:null,unpricedShare:null,kinds:null};
 const h=data.history,sub=ref===null?undefined:h?.subscriptions.find(x=>x.subscriptionRef===ref);
 if(!h||!sub||sub.sources.length===0)return none;
 const verified=new Set(data.subscriptions.map(s=>s.subscriptionRef)),servers=new Map<string,Set<string>>();
 for(const s of h.subscriptions)if(verified.has(s.subscriptionRef))for(const x of s.sources){const set=servers.get(x.source)??new Set<string>();set.add(s.subscriptionRef);servers.set(x.source,set);}
 const mine=sub.sources.map(x=>x.source),exclusive=mine.length>0&&mine.every(s=>(servers.get(s)?.size??0)===1);
 const c=h.cost,priced=h.coverage==='local-history'&&usable(c);
 const days=range==='today'?1:range==='7d'?7:30,from=daysAgo(now,days-1),today=daysAgo(now,0);
 const fromCost=()=>{let p=0,u=0;for(const b of c!.daily)if(mine.includes(b.source)&&b.at>=from&&b.at<=today){p+=b.pricedTokens;u+=b.unpricedTokens;}const total=p+u;return {tokens:total,unpricedShare:total>0?u/total:null};};
 if(range==='today'){
  if(!priced)return none;
  if(!exclusive){
   const shared=mine.filter(s=>(servers.get(s)?.size??0)>1);let total=0;
   for(const b of c!.daily)if(shared.includes(b.source)&&b.at===today)total+=b.pricedTokens+b.unpricedTokens;
   return {tokens:null,from:null,shared:{subscriptions:Math.max(...shared.map(s=>servers.get(s)!.size)),total},unpricedShare:null,kinds:null};
  }
  const f=fromCost();return f.tokens>0?{tokens:f.tokens,from:'cost',shared:null,unpricedShare:f.unpricedShare,kinds:null}:none;// nothing recorded today is "no usage", never a 0
 }
 const bound=sub.sources.every(x=>x.bindingBasis==='source-wide-current-binding');
 let sum=0,requests=0;const kinds={input:0,cacheWrite:0,cacheRead:0,output:0,reasoning:0};
 for(const x of sub.sources){const w=range==='7d'?x.recent7d:x.recent30d;if(!w)continue;sum+=w.totalTokens??w.outputTokens;requests+=w.observedRequests;kinds.input+=w.inputTokens??0;kinds.cacheWrite+=w.cacheWriteTokens??0;kinds.cacheRead+=w.cacheReadTokens??0;kinds.output+=w.outputTokens;kinds.reasoning+=w.reasoningTokens??0;}
 const split=requests>0?kinds:null;
 if(priced&&exclusive){const f=fromCost();if(f.tokens>0)return {tokens:f.tokens,from:'cost',shared:null,unpricedShare:f.unpricedShare,kinds:split};}
 if(!bound)return none;
 return requests>0&&sum>=0?{tokens:sum,from:'history',shared:null,unpricedShare:null,kinds:split}:none;
}
export type CockpitRangeKey='today'|'7d'|'30d';
