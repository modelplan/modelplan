// SPDX-License-Identifier: MIT
// Maps published public model data to the launch-field scene's model shape. No personal data.
import {brandColour,NEUTRAL} from './livery.js';
export interface PublishedEffort {readonly effort:string;readonly label:string;readonly star?:boolean;readonly ability?:number|null;readonly cost?:number|null;readonly time?:number|null}
export interface PublishedModel {readonly id:string;readonly name:string;readonly developerId:string;readonly recommended:string;readonly efforts:readonly PublishedEffort[]}
export type FieldRow=readonly [string,number,number,number];
export interface FieldModel {readonly id:string;readonly name:string;readonly short:string;readonly dev:string;readonly colour:string;readonly rec:string;readonly e:readonly FieldRow[];readonly sel:FieldRow;readonly reportedEffort:null;readonly previewEffort:null}
export const FIELD_LIMIT=10;
// The scene's own developer keys; anything else takes the neutral rocket.
const developers:Readonly<Record<string,{dev:string;colour:string}>>={openai:{dev:'openai',colour:brandColour('openai')},anthropic:{dev:'anthropic',colour:brandColour('anthropic')},zhipuai:{dev:'zhipu',colour:brandColour('zhipuai')},zhipu:{dev:'zhipu',colour:brandColour('zhipuai')}};
/** `short` names the model on narrow surfaces (callers pass the study's shortLabel); the default keeps the full name. */
export function fieldModel(m:PublishedModel,short:(name:string)=>string=name=>name):FieldModel|null {
 const rows:FieldRow[]=[];let star:FieldRow|null=null;
 for(const e of m.efforts){
  if(e.ability==null||e.cost==null)continue;
  const row:FieldRow=[e.label||e.effort,e.ability,e.cost,e.time??0];rows.push(row);
  if(e.star||e.effort===m.recommended)star=star??row;
 }
 const sel=star??rows[0];if(!sel)return null;
 const developer=Object.hasOwn(developers,m.developerId)?developers[m.developerId]!:{dev:m.developerId,colour:NEUTRAL};
 return {id:m.id,name:m.name,short:short(m.name),dev:developer.dev,colour:developer.colour,rec:sel[0],e:rows,sel,reportedEffort:null,previewEffort:null};
}
/** The rockets to fly: the chosen IDs in publication order, never more than the field's limit. */
export function fieldFleet(models:readonly FieldModel[],chosen:ReadonlySet<string>):FieldModel[] {
 return models.filter(m=>chosen.has(m.id)).slice(0,FIELD_LIMIT);
}
