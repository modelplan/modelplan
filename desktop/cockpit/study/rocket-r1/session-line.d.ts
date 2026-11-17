// SPDX-License-Identifier: MIT
export const UNKNOWN_MODEL:'unknown';
export function toolName(source:string):string;
export function effortName(effort:string|null|undefined):string|null;
export interface SessionLineInput {
 readonly source:string;readonly model:string;readonly effort:string|null;readonly state:string;readonly rate:number|null;
 readonly lastObservedAt:string;readonly startedAt?:string|null;readonly observedOutputTokens?:number|null;
}
export interface SessionLine {
 readonly tool:string;
 /** True when the producer could not name the model: the line shows the dim "Unknown model" text instead. */
 readonly unknownModel:boolean;
 readonly model:string;
 readonly effort:string|null;
 /** d/h/m since the start (running) or between the start and the last reading (idle); "--" when unknown. */
 readonly elapsed:string;
 /** Observed output tokens in k / M; "--" when unknown. */
 readonly tokens:string;
 readonly running:boolean;
 /** Running only: the last-minute speed, or null while it is not measurable. */
 readonly rate:number|null;
 /** Idle only: how long ago the session was last seen ("6m ago" / "6m前"). */
 readonly ago:string|null;
}
export function sessionLine(session:SessionLineInput,now:number,lang:'en'|'zh-CN',modelName?:(id:string)=>string):SessionLine;
