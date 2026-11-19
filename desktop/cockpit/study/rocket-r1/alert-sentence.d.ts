export interface Both {readonly en:string;readonly zh:string}
export interface AlertSentence {
 /** The full sentence: with the reset when it is known. */
 readonly text:Both;
 /** Without the reset, for a place the full sentence does not fit. */
 readonly short:Both;
}
export type AlertSentenceInput=
 | {readonly kind:'quota';readonly subscription:Both;readonly window:Both;readonly remaining:number;readonly runOutMinutes:number|null;readonly resetMinutes:number|null}
 | {readonly kind:'unreadable';readonly subscription:Both;readonly cause:string|null}
 | {readonly kind:'unreadableMany';readonly count:number};
export function alertDuration(minutes:number):string;
export function unreadableCause(code:string):Both|null;
export function isUnreadable(code:string|null|undefined):boolean;
export function alertSentence(input:AlertSentenceInput):AlertSentence;
export function openSettingsAction():Both;
export function resetsAvailable(n:number|null):Both;
