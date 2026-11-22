// SPDX-License-Identifier: MIT
// Map published model verdicts to the study's fader inputs. This does not fill
// missing values. D123 order: models in use (last 7 days, even when no own plan offers them, D135), then the
// publication's starred recommendations, then the others by ability.
import {speedTierFor,type FastTier} from './speed-tiers.js';
type Fader = {id:string;name:string;short:string;rec:string;e:([string,number|null,number|null,number|null]|[string,number|null,number|null,number|null,number])[];accounts:string[];sessions:{ref:string;sub:string|null}[];tier?:FastTier;unlisted?:true};
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
 /** Recorded sessions (details.recentSessions, the 7-day ledger). They count as "in use" like live ones (sampling #930)
  * but never attach to a fader: a fader's `sessions` stay live only. */
 readonly recorded?:readonly unknown[];
 /** Observed output tokens per published model from the history ranking (cockpitHistoryV1 models.recent7d / recent30d), imported
  * or recorded. G3-133: a model the user runs every day leads the unused recommendations even when no session shows it. */
 readonly usage?:ReadonlyMap<string,{readonly d7:number;readonly d30:number}>;
};
/** Model usage from the history ranking, for `FaderSetOptions.usage`. Names are verified publication IDs. */
export function historyUsage(history:{readonly models?:{readonly recent7d?:{readonly top?:readonly {readonly name:string;readonly observedOutputTokens:number}[]};readonly recent30d?:{readonly top?:readonly {readonly name:string;readonly observedOutputTokens:number}[]}}}|null|undefined):Map<string,{d7:number;d30:number}>{
 const out=new Map<string,{d7:number;d30:number}>();
 for(const [key,list] of [['d7',history?.models?.recent7d?.top],['d30',history?.models?.recent30d?.top]] as const)for(const e of list??[]){
  if(typeof e.name!=='string'||!(e.observedOutputTokens>0))continue;
  const row=out.get(e.name)??{d7:0,d30:0};row[key]+=e.observedOutputTokens;out.set(e.name,row);
 }
 return out;
}
/** D391 (owner 11-22): the history ranking carries no tool attribution (`WireCockpitRankedEntity` is name and tokens),
 * so a ranked model contributes only when a ticked subscription runs its developer — its recorded use cannot be the
 * user's own plans'. The conservative plan-filter rule applies: a subscription whose developer is unknown cannot be
 * matched, so then nothing is filtered (null). */
const historyDevelopers=(subscriptions:readonly {readonly developer:string|null}[]):ReadonlySet<string>|null=>
 subscriptions.length>0&&subscriptions.every(s=>s.developer!==null)?new Set(subscriptions.map(s=>s.developer as string)):null;
/** Beyond the engine's three: published models in use (live or recorded), then those of a developer one of the user's
 * subscriptions runs, in publication order. Every subscription counts, whatever the state of its reading: a stale or
 * loading reading is still the user's plan (sampling #930). `publicationFaders` applies the 7-day and own-plan rules.
 * D391: sessions arrive already admitted, and history-ranked models pass the developer rule above. */
export function moreFaderModels<T extends {readonly id:string;readonly developerId:string}>(published:readonly T[],live:readonly {readonly model:string}[],recorded:readonly {readonly model:string}[],subscriptions:readonly {readonly developer:string|null}[],historyModels:ReadonlySet<string>=new Set()):T[]{
 const ranked=historyDevelopers(subscriptions),history=ranked===null?[...historyModels]:[...historyModels].filter(id=>published.some(m=>m.id===id&&ranked.has(m.developerId)));
 const used=new Set([...live,...recorded].map(s=>s.model).concat(history)),vendors=new Set(subscriptions.map(s=>s.developer));
 return [...published.filter(m=>used.has(m.id)),...published.filter(m=>!used.has(m.id)&&vendors.has(m.developerId))];
}
export function publicationFaders(publication:unknown,live:unknown=null,more:readonly unknown[]=[],subscriptions:readonly FaderSubscription[]=[],options:FaderSetOptions={}):{accounts:Account[];faders:Fader[]} {
 const accounts:Account[]=subscriptions.slice(0,100).map(s=>({id:s.key,colour:s.colour}));
 const root=object(publication);
 if(!root||root.contractVersion!==1||!Array.isArray(root.models))return {accounts:[],faders:[]};
 const faders:Fader[]=[],taken=new Set<string>(),lastUsed=new Map<string,number>(),tierOf=new Map<string,number>();
 const planDevelopers=new Set(subscriptions.map(s=>s.developer)),filterPlans=options.ownPlansOnly===true&&subscriptions.length>0&&!planDevelopers.has(null);
 // D391: ranked history has no tool attribution, so usage exempts a model from the plan filter only when a ticked
 // subscription runs its developer; with an unknown developer among the subscriptions nothing can be matched, and the
 // usage keeps its old exempting power (the plan filter is off in that case anyway).
 const ranked=historyDevelopers(subscriptions),historyExempt=(id:string,developer:string|null)=>options.usage?.has(id)===true&&(ranked===null||developer!==null&&ranked.has(developer));
 const recent=[...(Array.isArray(live)?live:[]),...(options.recorded??[])].flatMap(value=>{
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
  if(filterPlans&&!lastUsed.has(id)&&!historyExempt(id,developer)&&!(developer&&planDevelopers.has(developer)))continue;
  const rows:Fader['e']=[],seen=new Set<string>();let recommendedStarred=false;
  for(const value of model.efforts.slice(0,32)){
   const effort=object(value),label=level(effort?.effort),ability=number(effort?.ability),cost=number(effort?.cost),aa=number(effort?.aaScore);
   if(!label||seen.has(label))continue;
   seen.add(label);if(label===recommended&&effort?.star===true)recommendedStarred=true;rows.push(aa!==null&&aa>0?[label,ability,cost,number(effort?.time),aa]:[label,ability,cost,number(effort?.time)]); // aaScore (D292): a reference only, after time
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
 // G3-133: after the sessions, models only the history shows: 7-day tokens, then 30-day tokens.
 const usage=options.usage,past=(f:Fader)=>!used(f)&&((usage?.get(f.id)?.d30??0)>0||(usage?.get(f.id)?.d7??0)>0);
 const inUse=faders.filter(used).sort((a,b)=>(lastUsed.get(b.id)??0)-(lastUsed.get(a.id)??0));
 const history=faders.filter(past).sort((a,b)=>(usage!.get(b.id)!.d7-usage!.get(a.id)!.d7)||(usage!.get(b.id)!.d30-usage!.get(a.id)!.d30));
 const rest=faders.filter(f=>!used(f)&&!past(f)),starred=rest.filter(f=>tierOf.get(f.id)===1),others=rest.filter(f=>tierOf.get(f.id)!==1).sort((a,b)=>ability(b)-ability(a));
 // G3-134: a live session of a model the publication does not list, whose raw ID the producer could read
 // (`modelDisplay`, from modeldisplay.Display), gets a card by that name: no efforts, no lever. One card per name.
 const unlisted:Fader[]=[];
 for(const value of Array.isArray(live)?live:[]){
  const session=object(value),display=text(session?.modelDisplay),ref=text(session?.sessionRef);
  if(!session||session.model!=='unknown'||!display||!ref||display.length>48)continue;
  const id='unlisted:'+display,found=unlisted.find(f=>f.id===id);
  if(found)found.sessions.push({ref,sub:text(session.subscriptionRef)});
  else if(faders.length+unlisted.length<FADER_LIMIT)unlisted.push({id,name:display,short:display,rec:'',e:[],accounts:[],sessions:[{ref,sub:text(session.subscriptionRef)}],unlisted:true});
 }
 return {accounts,faders:[...inUse,...unlisted,...history,...starred,...others]};
}

/** CKP-FAD-32 proposed (G3-110): a subscription scope shows only the faders of that subscription, as the opus-r7 study's faders()
 * does (models of the scoped subscription's pool; core.js scopePools). A fader belongs to the scope when the subscription
 * runs its developer (`accounts`) or when one of its sessions was bound to that subscription. `account` null is the All
 * scope (the D123 set, unchanged). A subscription whose developer is unknown cannot be matched, so nothing is filtered. */
export function scopedFaders<T extends {readonly accounts:readonly string[];readonly sessions:readonly {readonly sub:string|null}[]}>(faders:readonly T[],account:string|null,developerKnown:boolean):T[]{
 if(account===null||!developerKnown)return [...faders];
 return faders.filter(f=>f.accounts.includes(account)||f.sessions.some(s=>s.sub===account));
}
