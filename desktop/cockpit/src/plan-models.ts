// SPDX-License-Identifier: MIT
import type {WireCockpitData} from '../generated/wire.js';

// D86: the published plan ids are prefixed by the tool's vendor (openai-plus, claude-max-5x); a harness reports only "plus" or "max".
const planPrefixes:Readonly<Record<string,string>>={codex:'openai',claude:'claude'};
/** Models a member's plan lets its subscriber use, from the publication's planModels; null when the plan cannot be pinned
 * to published plans (then the developer match decides). A harness plan that covers several published tiers (Pro, Max) gets
 * only the models every one of those tiers lists, never the widest guess. */
export function memberPlanModels(data:WireCockpitData,toolId:string,planId:string|undefined):ReadonlySet<string>|null {
 const lists=data.details?.planModels;if(!lists?.length||!planId||planId==='unknown')return null;
 const prefix=planPrefixes[toolId],id=planId.toLowerCase();
 const matched=lists.filter(p=>p.planId===id||(prefix!==undefined&&(p.planId===`${prefix}-${id}`||p.planId.startsWith(`${prefix}-${id}-`))));
 if(!matched.length)return null;
 return new Set(matched[0]!.modelIds.filter(m=>matched.every(p=>p.modelIds.includes(m))));
}
/** D98: the models the tool itself reports for this subscription's signed-in account (details.subscriptions[].reportedModels,
 * already mapped to published ids); null when the tool did not report, then the published plan list, then the developer match. */
export function memberReportedModels(data:WireCockpitData,subscriptionRef:string|null|undefined):ReadonlySet<string>|null {
 if(!subscriptionRef)return null;
 const ids=data.details?.subscriptions.find(s=>s.subscriptionRef===subscriptionRef)?.reportedModels;
 return ids?.length?new Set(ids):null;
}
/** The model list that decides for one member: reported by the tool, else the published plan list, else null (developer match). */
export function memberModelList(data:WireCockpitData,toolId:string,planId:string|undefined,subscriptionRef:string|null|undefined):ReadonlySet<string>|null {
 return memberReportedModels(data,subscriptionRef)??memberPlanModels(data,toolId,planId);
}
