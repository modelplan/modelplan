// SPDX-License-Identifier: MIT
// Pointer event timestamps share a monotonic time origin. Invalid or backwards
// samples cannot turn into a long press.
export function isFaderLongPress(start:number,end:number):boolean {
 return Number.isFinite(start)&&Number.isFinite(end)&&start>=0&&end>=start&&end-start>=520;
}

export type FaderPress={pointer:number;started:number;sourceId:string;pinned:boolean};
export function beginFaderPress(active:FaderPress|null,candidate:FaderPress):FaderPress {
 return active??candidate;
}
export function endFaderPress(active:FaderPress|null,pointer:number,ended:number,kind:'up'|'cancel'):{active:FaderPress|null;commit:FaderPress|null} {
 if(!active||active.pointer!==pointer)return {active,commit:null};
 return {active:null,commit:kind==='up'&&isFaderLongPress(active.started,ended)?active:null};
}
