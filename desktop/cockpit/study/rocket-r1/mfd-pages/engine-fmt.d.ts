export {dhm,tok,when,hm,relativeMoment,approxCost} from './fmt.js';
export function esc(value:unknown):string;
export function countdown(minutes:number|null|undefined,options?:{narrow?:boolean}):string;
export function ago(minutes:number|null|undefined,lang?:string):string;
export function estimateAt(ms:number|null|undefined,options?:{lang?:string}):string;
