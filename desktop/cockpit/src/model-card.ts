// SPDX-License-Identifier: MIT
// Model cards (V1-FINAL §7, WP-08): the two facts a card needs beyond the publication, worked out from wire data only.
// cardUsage: a model's use in the chosen time range (tokens, its share, ≈cost when the producer estimated one). currentEffort: the
// effort a model is running at now (CKP-FAD-53). Nothing here invents a value: a missing reading stays missing.

export type CardRange='today'|'7d'|'30d';
/** One model's use in the range. `share` (0..1) is of the priced models' ≈cost when this model has a cost, else of all
 * models' tokens (V1-FINAL §7: "no public price" draws the bar by tokens). `cost` is US dollars, present only when the
 * producer estimated one (WP-06); never guessed. */
export type CardUse={readonly tokens:number;readonly share:number;readonly cost?:number};
type Ranked={readonly name?:unknown;readonly observedOutputTokens?:unknown};
type Window={readonly totalObservedOutputTokens?:unknown;readonly top?:readonly Ranked[]};
// WP-06 (#1050) wire: history.cost.models.{today,recent7d,recent30d}[] = {model, estimatedUsd, pricedTokens, unpricedTokens}.
// Read structurally so this works before and after #1050 lands; an absent or unusable section means "no ≈cost".
type CostRow={readonly model?:unknown;readonly estimatedUsd?:unknown;readonly pricedTokens?:unknown;readonly unpricedTokens?:unknown};
type Cost={readonly basis?:unknown;readonly currency?:unknown;readonly models?:{readonly today?:readonly CostRow[];readonly recent7d?:readonly CostRow[];readonly recent30d?:readonly CostRow[]}|null};
type History={readonly coverage?:unknown;readonly models?:{readonly recentToday?:Window;readonly recent7d?:Window;readonly recent30d?:Window}|null;readonly cost?:Cost|null}|null|undefined;

const finite=(v:unknown):number|null=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=1e15?v:null;
const text=(v:unknown):string|null=>typeof v==='string'&&v.length>0&&v.length<=200?v:null;
const local=(h:History)=>h?.coverage==='local-history';
const windowOf=(h:History,range:CardRange):Window|null=>{
 const m=local(h)?h!.models:null;if(!m)return null;
 return (range==='today'?m.recentToday:range==='7d'?m.recent7d:m.recent30d)??null;
};
const costRowsOf=(h:History,range:CardRange):readonly CostRow[]|null=>{
 const c=local(h)?h!.cost:null;if(!c||c.basis!=='api-list-price'||c.currency!=='USD'||!c.models)return null;
 const rows=range==='today'?c.models.today:range==='7d'?c.models.recent7d:c.models.recent30d;
 return Array.isArray(rows)?rows:null;
};
/** Use per published model id for the range (D474 §2.5, D464): TOTAL tokens, not output only.
 *  - With the producer's cost section: a model's tokens are `pricedTokens + unpricedTokens` from `history.cost.models` for
 *    every range, summed across its source rows; its share is its token share of the range total (every row, including the
 *    `unknown` row the publication cannot name); ≈cost (small) only when the producer estimated one: a model without priced
 *    tokens has none. The bank order is the caller's and does not change.
 *  - Without it (no publication loaded, or "Show estimated cost" off): the history ranking's output tokens and their
 *    share of the ranking total, as before (the one page note for this case is the overview's). */
export function cardUsage(h:History,range:CardRange):Map<string,CardUse>{
 const out=new Map<string,CardUse>(),costRows=costRowsOf(h,range);
 if(costRows){
  const tokens=new Map<string,number>(),usd=new Map<string,number>();let total=0;
  for(const r of costRows.slice(0,500)){
   const name=text(r.model),priced=finite(r.pricedTokens)??0,unpriced=finite(r.unpricedTokens)??0,cost=finite(r.estimatedUsd);
   total+=priced+unpriced;
   if(!name||name==='unknown')continue;
   tokens.set(name,(tokens.get(name)??0)+priced+unpriced);
   if(priced>0&&cost!==null)usd.set(name,(usd.get(name)??0)+cost);
  }
  for(const [name,n] of tokens){
   if(!(n>0))continue;
   const cost=usd.get(name),share=total>0?Math.min(1,n/total):0;
   out.set(name,cost!==undefined?{tokens:n,share,cost}:{tokens:n,share});
  }
  return out;
 }
 const w=windowOf(h,range),tokens=new Map<string,number>();
 for(const e of (w?.top??[]).slice(0,200)){const name=text(e.name),n=finite(e.observedOutputTokens);if(name&&n!==null)tokens.set(name,(tokens.get(name)??0)+n);}
 const total=Math.max(finite(w?.totalObservedOutputTokens)??0,[...tokens.values()].reduce((n,v)=>n+v,0));
 for(const [name,n] of tokens)if(n>0)out.set(name,{tokens:n,share:total>0?n/total:0});
 return out;
}

/** A live session as the current-effort rule reads it. `weight` is its recent token rate (tokens/s) when reported. */
export type EffortSample={readonly effort:string|null;readonly at:number;readonly weight:number|null};
export const CURRENT_WINDOW_MS=15*60_000;
/** The challenger must lead the held effort by this factor before the card switches (hysteresis). */
export const CURRENT_HOLD=1.5;
/** Another effort is "notable" (a white dot beside the slot) from this share of the window. */
export const NOTABLE_SHARE=.25;
/** CKP-FAD-53: the current effort is the one with the most tokens in the last 15 minutes, with hysteresis. The wire
 * reports no per-effort token counts, so a session's recent token rate stands in for its tokens (Assumed in the PR);
 * sessions without a rate count one each, and rates win when any session reports one. Without a reported effort in the
 * window the latest session's effort is kept, as before. `held` is the previous answer for this model. */
export function currentEffort(samples:readonly EffortSample[],now:number,held:string|null):{current:string|null;notable:string[]}{
 const recent=samples.filter(s=>s.effort&&Number.isFinite(s.at)&&s.at<=now+60_000&&now-s.at<=CURRENT_WINDOW_MS);
 const latest=[...samples].sort((a,b)=>b.at-a.at)[0]?.effort??null;
 if(!recent.length)return {current:latest,notable:[]};
 const rated=recent.some(s=>s.weight!==null&&s.weight>0),sum=new Map<string,number>();
 for(const s of recent)sum.set(s.effort!,(sum.get(s.effort!)??0)+(rated?(s.weight!==null&&s.weight>0?s.weight:0):1));
 const total=[...sum.values()].reduce((n,v)=>n+v,0),ranked=[...sum.entries()].sort((a,b)=>b[1]-a[1]);
 let current=ranked[0]![0];
 const heldWeight=held?sum.get(held)??0:0;
 if(held&&heldWeight>0&&current!==held&&ranked[0]![1]<heldWeight*CURRENT_HOLD)current=held;
 const notable=total>0?ranked.filter(([e,v])=>e!==current&&v/total>=NOTABLE_SHARE).map(([e])=>e):[];
 return {current,notable};
}
