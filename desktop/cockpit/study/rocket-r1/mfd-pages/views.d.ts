// SPDX-License-Identifier: MIT
export interface CompareArgs {modelId:string;current?:string|null;trial?:string;fast?:boolean;currentFast?:boolean}
export function comparison(d:unknown,ui:unknown,args:CompareArgs):string;
export function compareKeys(d:unknown,ui:unknown,args:CompareArgs,options?:{back?:string}):string;
export function cmpState(d:unknown,ui:unknown,args:CompareArgs):{trial:string;trialFast:boolean;curFast:boolean;tier:unknown}|null;
export const compareView:{onClick(act:string,val:string,ui:unknown,d:unknown,args:CompareArgs):{trial:CompareArgs}|null};
export function configShare(m:{e:[string,number|null,number|null,number|null][]},tier:{speed:number;cost:number;taskTimeUnknown?:boolean}|null,label:string,fast?:boolean):{abl:number|null;cost:number|null;time:number|null}|null;
