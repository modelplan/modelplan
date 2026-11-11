// SPDX-License-Identifier: MIT
// CKP-FAD-11: a model's fast tier from the published speedTiers (the shape of /v1/client data.speedTiers), for the
// comparison view's ⚡ key. A model matches a tier entry by its published model id (modelId) or, for a tier entry that
// has no published id, by its vendor model id. Nothing is invented: no entry, no tier, and the key stays dark.
export type FastTier={harness:string;speed:number;cost:number|null;taskTimeUnknown?:true};
const object=(value:unknown):Record<string,unknown>|null=>value!==null&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:null;
const ratio=(value:unknown):number|null=>typeof value==='number'&&Number.isFinite(value)&&value>0&&value<=1e6?value:null;

/** The first published tier that lists this model. Speed is the entry's ratio (1 and `taskTimeUnknown` when the
 * publication states none); cost is the subscription's quota ratio, the one a cockpit subscription pays. */
export function speedTierFor(speedTiers:unknown,id:string):FastTier|null {
 if(!id||!Array.isArray(speedTiers))return null;
 for(const value of speedTiers.slice(0,32)){
  const tier=object(value),harness=typeof tier?.harness==='string'?tier.harness:null;
  if(!tier||!harness||!Array.isArray(tier.models))continue;
  const entry=tier.models.slice(0,256).map(object).find(m=>m!==null&&(m.modelId===id||(m.modelId==null&&m.vendorModelId===id)));
  if(!entry)continue;
  const billing=Array.isArray(tier.billing)?tier.billing.slice(0,8).map(object):[];
  const cost=ratio((billing.find(b=>b?.account==='subscription')??null)?.ratio),speed=ratio(object(entry.speed)?.ratio);
  return speed===null?{harness,speed:1,cost,taskTimeUnknown:true}:{harness,speed,cost};
 }
 return null;
}

// The study view names a tool by pool; its two fast-mode tools.
const POOLS:Readonly<Record<string,string>>={codex:'codex','claude-code':'claude'};
const TOOLS:Readonly<Record<string,string>>={codex:'Codex','claude-code':'Claude Code'};
/** The comparison view's pool and speedTiers for one model, keyed as the study's cmpState reads them. */
export function compareSpeedTiers(model:{id:string},tier:FastTier|null):{pool:string|null;speedTiers:Record<string,{speed:number;cost:number|null;taskTimeUnknown?:true}>} {
 const tool=tier?TOOLS[tier.harness]:undefined;
 if(!tier||!tool)return {pool:null,speedTiers:{}};
 const {harness:_,...value}=tier;
 return {pool:POOLS[tier.harness]!,speedTiers:{[`${tool}|${model.id}`]:value}};
}
