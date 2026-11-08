// SPDX-License-Identifier: MIT
// Map published model verdicts to the study's fader inputs. This does not fill
// missing values. Models in use lead, then the publication's own recommended order.
type Fader = {id:string;name:string;short:string;rec:string;e:[string,number|null,number|null,number|null][];accounts:string[];sessions:{ref:string;sub:string|null}[]};
const object=(value:unknown):Record<string,unknown>|null=>value!==null&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:null;
const text=(value:unknown):string|null=>typeof value==='string'&&value.length>0&&value.length<=200?value:null;
const number=(value:unknown):number|null=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=1e12?value:null;
const level=(value:unknown):string|null=>{
 if(typeof value!=='string')return null;
 const levels:Readonly<Record<string,string>>={low:'Low',med:'Med',medium:'Med',high:'High',xhigh:'XHigh',max:'Max'};
 return levels[value.toLowerCase()]??null;
};

/** One fader per model (CKP-FAD-01, owner: one per model, three per bank). The engine's publication carries at most three
 * models, in use first; `more` adds the other published models the cockpit may show, after them and in their order. */
export const FADER_LIMIT=30;
export function publicationFaders(publication:unknown,live:unknown=null,more:readonly unknown[]=[]):{accounts:never[];faders:Fader[]} {
 const root=object(publication);
 if(!root||root.contractVersion!==1||!Array.isArray(root.models))return {accounts:[],faders:[]};
 const faders:Fader[]=[],taken=new Set<string>();
 for(const value of [...root.models.slice(0,3),...more]){
  if(faders.length>=FADER_LIMIT)break;
  const model=object(value),id=text(model?.id),name=text(model?.name),recommended=level(model?.recommended);
  if(!model||!id||!name||!recommended||!Array.isArray(model.efforts)||taken.has(id))continue;
  const rows:Fader['e']=[],seen=new Set<string>();let recommendedStarred=false;
  for(const value of model.efforts.slice(0,32)){
   const effort=object(value),label=level(effort?.effort),ability=number(effort?.ability),cost=number(effort?.cost);
   if(!label||seen.has(label))continue;
   seen.add(label);if(label===recommended&&effort?.star===true)recommendedStarred=true;rows.push([label,ability,cost,number(effort?.time)]);
  }
  rows.sort((a,b)=>['Low','Med','High','XHigh','Max'].indexOf(a[0])-['Low','Med','High','XHigh','Max'].indexOf(b[0]));
  if(!recommendedStarred)continue;
  const sessions=(Array.isArray(live)?live:[]).flatMap(value=>{const session=object(value),ref=text(session?.sessionRef);return ref&&session?.model===id?[{ref,sub:text(session.subscriptionRef)}]:[];});
  taken.add(id);faders.push({id,name,short:name,rec:recommended,e:rows,accounts:[],sessions});
 }
 return {accounts:[],faders:[...faders.filter(f=>f.sessions.length),...faders.filter(f=>!f.sessions.length)]};
}
