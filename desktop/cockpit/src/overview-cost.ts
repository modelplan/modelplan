// SPDX-License-Identifier: MIT
// Overview bars (WP-12, V1-FINAL §8.1): one ≈cost value per local day and per local hour for each subscription, read from the
// wire's cost section (WP-06: history.cost, API list price). A day with no record is null, never zero; a recorded day
// whose use has no public price is a recorded zero (it keeps the 3 px base). Without any priced usage there is no
// series at all: the page then draws no bars and builds no fallback from tokens.
import type {WireCockpitCost,WireCockpitCostBucket} from '../generated/wire.js';
type CostBucket=WireCockpitCostBucket;
interface HistoryLike {readonly coverage?:string;readonly subscriptions?:readonly {readonly subscriptionRef:string;readonly sources:readonly {readonly source:string}[]}[];readonly cost?:WireCockpitCost|null}
export interface OverviewCost {
 readonly daily:readonly {accountId:string;values:(number|null)[]}[];
 readonly hourly:readonly {accountId:string;instants:number[];values:(number|null)[]}[];
 /** Unpriced tokens ÷ all tokens in the last 24 h / 7 / 30 days, 0…1; null without tokens. */
 readonly unpriced:{readonly today:number|null;readonly d7:number|null;readonly d30:number|null};
}
const HOUR=36e5,DAYS=182;
const dayKey=(at:number)=>{const d=new Date(at);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};

export function overviewCost(data:{readonly history?:HistoryLike|null}|null|undefined,ids:ReadonlyMap<string,string>,now:number):OverviewCost|null {
 const h=data?.history,c=h?.cost;
 if(!h||h.coverage!=='local-history'||!c||c.basis!=='api-list-price'||c.currency!=='USD'||!h.subscriptions)return null;
 const daily=c.daily,hourly=c.hourly;
 if(!daily.some(b=>b.pricedTokens>0)&&!hourly.some(b=>b.pricedTokens>0))return null;
 const clock=new Date(now),top=now-clock.getMinutes()*6e4-clock.getSeconds()*1e3-clock.getMilliseconds();
 const instants=Array.from({length:24},(_,i)=>top-(23-i)*HOUR);
 const days=Array.from({length:DAYS},(_,i)=>dayKey(new Date(clock.getFullYear(),clock.getMonth(),clock.getDate()-(DAYS-1-i)).getTime()));
 const out:{accountId:string;values:(number|null)[]}[]=[],outHours:{accountId:string;instants:number[];values:(number|null)[]}[]=[];
 for(const sub of h.subscriptions){
  const accountId=ids.get(sub.subscriptionRef);if(!accountId)continue;
  const sources=new Set(sub.sources.map(s=>s.source)),byDay=new Map<string,number>();
  for(const b of daily)if(sources.has(b.source))byDay.set(b.at,(byDay.get(b.at)??0)+(b.pricedTokens>0?b.estimatedUsd:0));
  out.push({accountId,values:days.map(day=>byDay.get(day)??null)});
  const values:(number|null)[]=instants.map(()=>null);
  for(const b of hourly){const index=Math.floor((Date.parse(b.at)-instants[0]!)/HOUR);if(sources.has(b.source)&&index>=0&&index<values.length)values[index]=(values[index]??0)+(b.pricedTokens>0?b.estimatedUsd:0);}
  outHours.push({accountId,instants,values});
 }
 const share=(from:string)=>{let all=0,unpriced=0;for(const b of daily)if(b.at>=from){all+=b.pricedTokens+b.unpricedTokens;unpriced+=b.unpricedTokens;}return all>0?unpriced/all:null;};
 const back=(n:number)=>dayKey(new Date(clock.getFullYear(),clock.getMonth(),clock.getDate()-n).getTime());
 return {daily:out,hourly:outHours,unpriced:{today:share(back(0)),d7:share(back(6)),d30:share(back(29))}};
}
