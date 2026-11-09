// SPDX-License-Identifier: MIT
// Maps published public model data to the launch-field scene's model shape. No personal data.
export interface PublishedEffort {readonly effort:string;readonly label:string;readonly star?:boolean;readonly ability?:number|null;readonly cost?:number|null;readonly time?:number|null}
export interface PublishedModel {readonly id:string;readonly name:string;readonly developerId:string;readonly recommended:string;readonly efforts:readonly PublishedEffort[];readonly defaultSelected?:boolean|null}
export type FieldRow=readonly [string,number,number,number];
export interface FieldModel {readonly id:string;readonly name:string;readonly short:string;readonly dev:string;readonly colour:string;readonly rec:string;readonly e:readonly FieldRow[];readonly sel:FieldRow;readonly reportedEffort:null;readonly previewEffort:null;/** The website's default focus set (D93); absent when the publication has none. */readonly site?:boolean}
export const FIELD_LIMIT=10;
// The scene's own developer keys; anything else takes the neutral rocket.
const developers:Readonly<Record<string,{dev:string;colour:string}>>={openai:{dev:'openai',colour:'#6aa8ff'},anthropic:{dev:'anthropic',colour:'#ff9a6a'},zhipuai:{dev:'zhipu',colour:'#8f7dff'},zhipu:{dev:'zhipu',colour:'#8f7dff'}};
/** `short` names the model on narrow surfaces (callers pass the study's shortLabel); the default keeps the full name. */
export function fieldModel(m:PublishedModel,short:(name:string)=>string=name=>name):FieldModel|null {
 const rows:FieldRow[]=[];let star:FieldRow|null=null;
 for(const e of m.efforts){
  if(e.ability==null||e.cost==null)continue;
  const row:FieldRow=[e.label||e.effort,e.ability,e.cost,e.time??0];rows.push(row);
  if(e.star||e.effort===m.recommended)star=star??row;
 }
 const sel=star??rows[0];if(!sel)return null;
 const developer=Object.hasOwn(developers,m.developerId)?developers[m.developerId]!:{dev:m.developerId,colour:'#c6ccd4'};
 return {id:m.id,name:m.name,short:short(m.name),dev:developer.dev,colour:developer.colour,rec:sel[0],e:rows,sel,reportedEffort:null,previewEffort:null,...(typeof m.defaultSelected==='boolean'?{site:m.defaultSelected}:{})};
}
/** The rockets to fly: the chosen IDs in publication order, never more than the field's limit. */
export function fieldFleet(models:readonly FieldModel[],chosen:ReadonlySet<string>):FieldModel[] {
 return models.filter(m=>chosen.has(m.id)).slice(0,FIELD_LIMIT);
}
