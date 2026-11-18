// SPDX-License-Identifier: MIT
// CKP-STRIP-06 / G3-56: which cautions the owner has already seen. A caution blinks when it is new; pressing the lamp
// acknowledges it; only a real clear-and-return or a red escalation (a different stable identity) blinks it again.
// The identity is tool, window and severity (`CautionItem.stable`), never the reset time or the numbers.
// G3-106: an amber caution is the engine's run-out forecast, which comes and goes with the recent usage rate (an idle
// hour drops it, the next burst brings it back with another ETA). Its window still has a real reading meanwhile, so the
// G3-56 clear rule took the pause for a clear and the return for a recurrence. An amber acknowledgement therefore keeps
// the window cycle it was given in (`CautionItem.cycle`, the reset moment) and ends only when that window is read in a
// new cycle. A red caution keeps the G3-56 rule: its reading itself must rise above the red line.
// G3-135: blinking itself marks the caution seen (no press needed), so it also reaches the host.
// The acknowledged identities are opaque (no readings). The host keeps them in the app's own preferences: the page
// reports every change through `onChange` and gets them back in the `load` message, so they outlive a restart. The
// page's own web view has a non-persistent store and keeps nothing. A cycle travels as a fourth element (its reset
// moment to the minute), so a new cycle seen only after a restart still blinks.
import type {CautionItem,ReadWindow} from './caution.js';

// ALR-51: only red and amber are lit; blue and grey are list-only, so they never blink and are never acknowledged.
// (The same rule as caution.ts `lights`, kept here so this module loads without the page's string tables.)
const lights=(x:CautionItem)=>x.level==='red'||x.level==='amber';

const MAX=64;
/** The host bounds an identity in UTF-8 bytes (BridgeState.swift), so the page counts bytes too. */
export const MAX_ID_BYTES=200;
export const withinIdBound=(id:string)=>new TextEncoder().encode(id).length<=MAX_ID_BYTES;
// Only a verified subscription reference (16 hex) names the same account after a restart . A fallback
// member's identity (`row#route#position`) holds for one app session only. G3-135: the page still reports and restores it
// (the page is rebuilt on every cockpit open, so a press on an unverified account was lost on the next open); the host
// keeps those in memory for the session and writes only durable ones to disk (CockpitCautionIdentities.durable).
const keepable=(id:string)=>{try{const p=JSON.parse(id);return withinIdBound(id)&&Array.isArray(p)&&typeof p[0]==='string';}catch{return false;}};
const parse=(id:string):unknown[]|null=>{try{const p=JSON.parse(id);return Array.isArray(p)?p:null;}catch{return null;}};
const window_=(stable:string)=>{const p=parse(stable);return p&&p.length===3?JSON.stringify([p[0],p[1]]):null;};
const MINUTE=60000,HOUR=60*MINUTE;
/** The persisted form: the stable identity, plus the cycle's reset moment (to the minute) when it has one. */
const persisted=(stable:string,cycle:number|null)=>{if(cycle===null)return stable;const p=parse(stable)!;return JSON.stringify([...p,new Date(Math.round(cycle/MINUTE)*MINUTE).toISOString().replace('.000Z','Z')]);};
const fromPersisted=(id:string):[string,number|null]|null=>{
 const p=parse(id);if(!p)return null;if(p.length===3)return [id,null];
 if(p.length!==4||typeof p[3]!=='string')return null;const at=Date.parse(p[3]);return Number.isFinite(at)?[JSON.stringify(p.slice(0,3)),at]:null;
};
// Readings of one cycle move the reset moment by seconds to minutes; the next cycle starts a window length later.
const sameCycle=(a:number,b:number,span:number|null)=>Math.abs(a-b)<(span===null?HOUR:span/2);
export interface CautionMemory {
 /** Records the current lamp conditions; true when one of them is new (never blinked and never acknowledged). */
 update(items:readonly CautionItem[],read:ReadonlyMap<string,ReadWindow>,canBlink?:boolean):boolean;
 /** Recovery contract: the lamp memory as it is now; calling the result puts it back (a refused render, glm-990-1). */
 checkpoint():()=>void;
 /** The lamp was pressed: everything lit is acknowledged. Returns the newest acknowledged caution's stable identity. */
 acknowledge():string|null;
 /** Identities the host remembered from an earlier run. They count as acknowledged and are not reported back. */
 restore(ids:readonly string[]):void;
 /** A store or consent barrier: everything acknowledged before it is forgotten, and nothing is reported for it. */
 forget():void;
}
export function createCautionMemory(onChange:(ids:string[])=>void=()=>{}):CautionMemory {
 // stable identity -> the reset moment of the cycle it was seen or acknowledged in (null: no cycle, the G3-56 rule).
 const acked=new Map<string,number|null>(),shown=new Map<string,number|null>();let current:CautionItem[]=[],newest:string|null=null;
 const durable=()=>[...acked].map(([id,cycle])=>persisted(id,cycle)).filter(keepable);
 const report=()=>onChange(durable().slice(-MAX));
 return {
  checkpoint(){const savedAcked=new Map(acked),savedShown=new Map(shown),savedCurrent=current,savedNewest=newest;return ()=>{acked.clear();for(const [k,v] of savedAcked)acked.set(k,v);shown.clear();for(const [k,v] of savedShown)shown.set(k,v);current=savedCurrent;newest=savedNewest;};},
  forget(){acked.clear();shown.clear();current=[];newest=null;},
  restore(ids){for(const id of ids.slice(0,MAX)){if(typeof id!=='string'||!keepable(id))continue;const r=fromPersisted(id);if(r)acked.set(r[0],r[1]);}},
  update(items,read,canBlink=true){
   const lit=items.filter(lights),litIds=lit.map(x=>x.stable);
   // Recurrence: a condition is over only when its window has a real reading and no longer qualifies, or, for one held
   // by its cycle, when the window is read in another cycle.
   let changed=false;
   for(const set of [acked,shown])for(const [id,cycle] of [...set]){
    const w=window_(id),r=w===null?undefined:read.get(w);if(!r)continue;
    let over:boolean;
    if(cycle===null)over=!litIds.includes(id);
    else{const now=lit.find(x=>x.stable===id)?.cycle??r.resetAt;over=now!==null&&now!==undefined&&!sameCycle(cycle,now,r.span);}
    if(over){set.delete(id);if(set===acked&&keepable(persisted(id,cycle)))changed=true;}
   }
   if(changed)report();
   // G3-135: a caution that has blinked counts as seen (acknowledged and kept by the host) with no press; a page that
   // cannot blink yet (inactive, closed) leaves it unseen so the blink is not lost.
   const fresh=canBlink?lit.filter(x=>!acked.has(x.stable)&&!shown.has(x.stable)):[];
   const before=durable().join('|');
   for(const x of fresh){shown.set(x.stable,x.cycle??null);acked.set(x.stable,x.cycle??null);newest=x.stable;}
   if(durable().join('|')!==before)report();
   current=lit;if(newest!==null&&!litIds.includes(newest))newest=litIds.find(id=>!acked.has(id))??litIds[0]??null;
   return fresh.length>0;
  },
  acknowledge(){
   const before=durable().join('|');for(const x of current)if(!acked.has(x.stable))acked.set(x.stable,x.cycle??null);if(durable().join('|')!==before)report();
   const ids=current.map(x=>x.stable);if(newest===null||!ids.includes(newest))newest=ids[0]??null;
   return newest;
  },
 };
}
