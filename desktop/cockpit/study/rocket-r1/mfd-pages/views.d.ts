// SPDX-License-Identifier: MIT
export interface CompareArgs {modelId:string;current?:string|null;trial?:string;fast?:boolean;currentFast?:boolean}
export function comparison(d:unknown,ui:unknown,args:CompareArgs):string;
export function compareKeys(d:unknown,ui:unknown,args:CompareArgs,options?:{back?:string}):string;
export function cmpState(d:unknown,ui:unknown,args:CompareArgs):{trial:string;trialFast:boolean;curFast:boolean;tier:unknown}|null;
export const compareView:{onClick(act:string,val:string,ui:unknown,d:unknown,args:CompareArgs):{trial:CompareArgs}|null};
