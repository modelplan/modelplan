// SPDX-License-Identifier: MIT
// The models a HUD or chart scope lists, from public published data. Pure: no DOM, and no study import (the short-label function is passed in).
import type {WireCockpitData} from '../generated/wire.js';
import {FIELD_LIMIT,fieldModel,type FieldModel} from './field-model.js';
import {cockpitMembers} from './members.js';
import {memberModelList} from './plan-models.js';
import {sessionMember,toolDevelopers} from './session-binding.js';

type ShortLabel=(name:string)=>string;
const WEEK=7*864e5,USED_LIMIT=3;
export interface HudOptions {readonly scope?:string;readonly now?:number;readonly selected?:string|null;readonly closed?:boolean}
export type HudModel=FieldModel&{readonly dominated:boolean;readonly latestEffort?:string|null;readonly running?:boolean};
function roundRobin(list:readonly HudModel[]) {
 const groups=new Map<string,HudModel[]>();for(const m of list)(groups.get(m.dev)??groups.set(m.dev,[]).get(m.dev)!).push(m);
 const out:HudModel[]=[];for(let slot=0;slot<Math.max(0,...[...groups.values()].map(g=>g.length));slot++)for(const g of groups.values())if(g[slot])out.push(g[slot]!);
 return out;
}
/** One order for the scope (the enlarged chart's field) (hud-selection/selection.js): models used this week, the lineup, then developers in turn; dominated last. */
export function fleetOf(shortLabel:ShortLabel,data:WireCockpitData|null|undefined,scope='all',now=Date.now(),limit=FIELD_LIMIT,usedLimit=USED_LIMIT):HudModel[] {
 const published=data?.details?.publishedModels??[],developerOf=new Map(published.map(m=>[m.id,m.developerId]));
 const members=data?cockpitMembers(data):[],member=scope==='all'?null:members.find(m=>m.key===scope)??null;
 if(scope!=='all'&&!member)return [];
 // D86: "All" is the union of the user's own subscriptions, never the whole published field. A model counts when its plan lists it (planModels), or, without a list, when its
 // developer is one of those subscriptions' developers, or a session bound to one of them used it this week (on a model that subscription carries).
 const owned=member?[member]:members;
 // The models the tool reports for the account (D98), else a published plan model list the member's plan matches, decide for that subscription; otherwise its developer does.
 const lists=new Map(data?owned.map(m=>[m.key,{list:memberModelList(data,m.row.id,m.account.plan.id,m.account.subscriptionRef),developer:toolDevelopers[m.row.id]}]):[]);
 const carries=(l:{list:ReadonlySet<string>|null|undefined;developer:string|undefined},id:string)=>l.list?l.list.has(id):l.developer!==undefined&&l.developer===developerOf.get(id);
 const usable=(id:string)=>[...lists.values()].some(l=>carries(l,id));
 // WP-14 (V1-FINAL §5): a session adds its model only when its subscription carries it; a subscription that names neither a model list nor a developer
 // (OpenCode Go, Cursor) cannot say, so its sessions still count. A Claude Code session pointed at another vendor's model is not that subscription's model.
 const recent=[...(data?.details?.sessions??[])].filter(s=>{const at=Date.parse(s.lastObservedAt),bound=sessionMember(members,s),l=bound?lists.get(bound.key):undefined;return !!l&&(!l.list&&l.developer===undefined||carries(l,s.model))&&at>=now-WEEK&&at<=now;}).sort((a,b)=>Date.parse(b.lastObservedAt)-Date.parse(a.lastObservedAt));
 const latest=new Map<string,string|null>();for(const s of recent)if(!latest.has(s.model))latest.set(s.model,s.effort);
 const running=new Set(recent.filter(s=>s.state==='running').map(s=>s.model));
 const candidates=published.flatMap(m=>{const f=fieldModel(m,shortLabel);return f&&(usable(m.id)||latest.has(m.id))?[f]:[];});
 const beaten=(m:FieldModel)=>candidates.some(n=>n.id!==m.id&&n.sel[2]>0&&m.sel[2]>0&&n.sel[1]>=m.sel[1]&&n.sel[2]<=m.sel[2]&&(n.sel[1]>m.sel[1]||n.sel[2]<m.sel[2]));
 const models=candidates.map((m):HudModel=>({...m,dominated:beaten(m),...(latest.has(m.id)?{latestEffort:latest.get(m.id)??null}:{}),...(running.has(m.id)?{running:true}:{})}));
 const byId=new Map(models.map(m=>[m.id,m]));
 const used=[...latest.keys()].flatMap(id=>{const m=byId.get(id);return m?[m]:[];}).slice(0,usedLimit),taken=new Set(used.map(m=>m.id));
 const rest=models.filter(m=>!taken.has(m.id)),lineup=(data?.details?.publication?.models??[]).flatMap(p=>{const m=rest.find(x=>x.id===p.id&&!x.dominated);return m?[m]:[];}),picked=new Set(lineup.map(m=>m.id));
 return [...used,...lineup,...roundRobin(rest.filter(m=>!m.dominated&&!picked.has(m.id))),...roundRobin(rest.filter(m=>m.dominated&&!picked.has(m.id)))].slice(0,limit);
}
/** D386 (supersedes the CKP-PORT-04/07 order): the ability frontier of the scope, the yellow line of the ability-vs-cost chart: models no other model
 *  beats on both ability and cost at ★ effort, best ability first. Models off the frontier are not listed. */
export function frontierOf(fleet:readonly HudModel[]):HudModel[] {
 return fleet.filter(m=>!m.dominated).sort((a,b)=>b.sel[1]-a.sel[1]||a.sel[2]-b.sel[2]);
}
export const frontierFleetOf=(shortLabel:ShortLabel,data:WireCockpitData|null|undefined,scope='all',now=Date.now()):HudModel[]=>frontierOf(fleetOf(shortLabel,data,scope,now,Infinity));
/** The enlarged chart's field: the frontier first, in the HUD's order, then the beaten models as dim points, up to the field limit. */
export function chartFleetOf(shortLabel:ShortLabel,data:WireCockpitData|null|undefined,scope='all',now=Date.now(),limit=FIELD_LIMIT):HudModel[] {
 const all=fleetOf(shortLabel,data,scope,now,Infinity);
 return [...frontierOf(all),...all.filter(m=>m.dominated).sort((a,b)=>b.sel[1]-a.sel[1])].slice(0,limit);
}
