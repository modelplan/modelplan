// SPDX-License-Identifier: MIT
// Map published model verdicts to the study's fader inputs. This does not fill
// missing values. D123 order: models in use (last 7 days, even when no own plan offers them, D135), then the
// publication's starred recommendations, then the others by ability.
import {speedTierFor,type FastTier} from './speed-tiers.js';
type Fader = {id:string;name:string;short:string;rec:string;e:[string,number|null,number|null,number|null][];accounts:string[];sessions:{ref:string;sub:string|null}[];tier?:FastTier};
const object=(value:unknown):Record<string,unknown>|null=>value!==null&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:null;
const text=(value:unknown):string|null=>typeof value==='string'&&value.length>0&&value.length<=200?value:null;
const number=(value:unknown):number|null=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=1e12?value:null;
const level=(value:unknown):string|null=>{
 if(typeof value!=='string')return null;
 const levels:Readonly<Record<string,string>>={low:'Low',med:'Med',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'};
 return levels[value.toLowerCase()]??null;
};

/** One fader per model (CKP-FAD-01, owner: one per model, three per bank). The engine's publication carries at most three
 * models, in use first; `more` adds the other published models the cockpit may show. This is only a safety bound at the
 * deck's own 100-fader read limit; the D123 cap of 12 is `FADER_SET_LIMIT`, which "show all models" lifts. */
export const FADER_LIMIT=100;
/** A subscription a fader can name: its member key, the developer whose models it runs and its identity colour. */
export type FaderSubscription={readonly key:string;readonly developer:string|null;readonly colour:string};
type Account={id:string;colour:string};
/** `subscriptions` gives each fader its vendor strip (CKP-FAD-03): one segment per subscription that runs the model's
 * developer. Sessions keep the subscription they were bound to; `live` should already carry that binding. */
export const FADER_SET_LIMIT=12;
const DAY=86_400_000;
export type FaderSetOptions={
 /** Current time (ms). With it, only sessions seen in the last 7 days count as "in use" (D123). */
 readonly now?:number;
 /** Keep only models of developers the user's subscriptions run (D123). Models used in the last 7 days are exempt (D135);
  * ignored when a subscription's developer is unknown. */
 readonly ownPlansOnly?:boolean;
};
export function publicationFaders(publication:unknown,live:unknown=null,more:readonly unknown[]=[],subscriptions:readonly FaderSubscription[]=[],options:FaderSetOptions={}):{accounts:Account[];faders:Fader[]} {
 const accounts:Account[]=subscriptions.slice(0,100).map(s=>({id:s.key,colour:s.colour}));
 const root=object(publication);
 if(!root||root.contractVersion!==1||!Array.isArray(root.models))return {accounts:[],faders:[]};
 const faders:Fader[]=[],taken=new Set<string>(),lastUsed=new Map<string,number>(),tierOf=new Map<string,number>();
 const planDevelopers=new Set(subscriptions.map(s=>s.developer)),filterPlans=options.ownPlansOnly===true&&subscriptions.length>0&&!planDevelopers.has(null);
 const recent=(Array.isArray(live)?live:[]).flatMap(value=>{
  const s=object(value),model=text(s?.model),at=typeof s?.lastObservedAt==='string'?Date.parse(s.lastObservedAt):NaN;
  if(!model||!text(s?.sessionRef))return [];
  if(options.now===undefined)return [[model,Number.isFinite(at)?at:0] as const];
  return Number.isFinite(at)&&at<=options.now&&options.now-at<=7*DAY?[[model,at] as const]:[];
 });
 for(const [model,at] of recent)lastUsed.set(model,Math.max(lastUsed.get(model)??0,at));
 const candidates=[...root.models.slice(0,3).map(v=>[v,1] as const),...more.map(v=>[v,2] as const)];
 for(const [value,rank] of candidates){
  if(faders.length>=FADER_LIMIT)break;
  const model=object(value),id=text(model?.id),name=text(model?.name),recommended=level(model?.recommended),developer=text(model?.developerId);
  if(!model||!id||!name||!recommended||!Array.isArray(model.efforts)||taken.has(id))continue;
  if(filterPlans&&!lastUsed.has(id)&&!(developer&&planDevelopers.has(developer)))continue;
  const rows:Fader['e']=[],seen=new Set<string>();let recommendedStarred=false;
  for(const value of model.efforts.slice(0,32)){
   const effort=object(value),label=level(effort?.effort),ability=number(effort?.ability),cost=number(effort?.cost);
   if(!label||seen.has(label))continue;
   seen.add(label);if(label===recommended&&effort?.star===true)recommendedStarred=true;rows.push([label,ability,cost,number(effort?.time)]);
  }
  rows.sort((a,b)=>['Low','Med','High','XHigh','Max'].indexOf(a[0])-['Low','Med','High','XHigh','Max'].indexOf(b[0]));
  if(!recommendedStarred)continue;
  const sessions=(Array.isArray(live)?live:[]).flatMap(value=>{const session=object(value),ref=text(session?.sessionRef);return ref&&session?.model===id?[{ref,sub:text(session.subscriptionRef)}]:[];});
  taken.add(id);tierOf.set(id,rank);const tier=speedTierFor(root.speedTiers,id);
  faders.push({id,name,short:name,rec:recommended,e:rows,accounts:developer?subscriptions.filter(s=>s.developer===developer).map(s=>s.key):[],sessions,...(tier?{tier}:{})});
 }
 // D123 order after favourites (applied by the deck): in use, most recent first; then the publication's starred
 // recommendations; then the others by published ability at their recommended effort, strongest first.
 const ability=(f:Fader)=>f.e.find(r=>r[0]===f.rec)?.[1]??-1,used=(f:Fader)=>lastUsed.has(f.id);
 const inUse=faders.filter(used).sort((a,b)=>(lastUsed.get(b.id)??0)-(lastUsed.get(a.id)??0));
 const rest=faders.filter(f=>!used(f)),starred=rest.filter(f=>tierOf.get(f.id)===1),others=rest.filter(f=>tierOf.get(f.id)!==1).sort((a,b)=>ability(b)-ability(a));
 return {accounts,faders:[...inUse,...starred,...others]};
}

/** CKP-FAD-32 proposed (G3-110): a subscription scope shows only the faders of that subscription, as the opus-r7 study's faders()
 * does (models of the scoped subscription's pool; core.js scopePools). A fader belongs to the scope when the subscription
 * runs its developer (`accounts`) or when one of its sessions was bound to that subscription. `account` null is the All
 * scope (the D123 set, unchanged). A subscription whose developer is unknown cannot be matched, so nothing is filtered. */
export function scopedFaders<T extends {readonly accounts:readonly string[];readonly sessions:readonly {readonly sub:string|null}[]}>(faders:readonly T[],account:string|null,developerKnown:boolean):T[]{
 if(account===null||!developerKnown)return [...faders];
 return faders.filter(f=>f.accounts.includes(account)||f.sessions.some(s=>s.sub===account));
}
