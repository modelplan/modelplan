// SPDX-License-Identifier: MIT
// CKP-STRIP-06 / G3-56: which cautions the owner has already seen. A caution blinks when it is new; pressing the lamp
// acknowledges it; only a real clear-and-return or a red escalation (a different stable identity) blinks it again.
// The identity is tool, window and severity (`CautionItem.stable`), never the reset time or the numbers.
// The acknowledged identities are opaque (no readings). The host keeps them in the app's own preferences: the page
// reports every change through `onChange` and gets them back in the `load` message, so they outlive a restart. The
// page's own web view has a non-persistent store and keeps nothing.
import type {CautionItem} from './caution.js';

const MAX=64;
const window_=(stable:string)=>{try{const p=JSON.parse(stable);return Array.isArray(p)&&p.length===3?JSON.stringify([p[0],p[1]]):null;}catch{return null;}};

export interface CautionMemory {
 /** Records the current lamp conditions; true when one of them is new (never blinked and never acknowledged). */
 update(items:readonly CautionItem[],read:ReadonlySet<string>):boolean;
 /** The lamp was pressed: everything lit is acknowledged. Returns the newest acknowledged caution's stable identity. */
 acknowledge():string|null;
 /** Identities the host remembered from an earlier run. They count as acknowledged and are not reported back. */
 restore(ids:readonly string[]):void;
}
export function createCautionMemory(onChange:(ids:string[])=>void=()=>{}):CautionMemory {
 const acked=new Set<string>(),shown=new Set<string>();let current:string[]=[],newest:string|null=null;
 const report=()=>onChange([...acked].slice(-MAX));
 return {
  restore(ids){for(const id of ids.slice(0,MAX))if(typeof id==='string')acked.add(id);},
  update(items,read){
   const lit=items.filter(x=>x.level!=='blue').map(x=>x.stable);
   // Recurrence: a condition is over only when its window has a real reading and no longer qualifies.
   let changed=false;
   for(const set of [acked,shown])for(const id of [...set]){const w=window_(id);if(w!==null&&read.has(w)&&!lit.includes(id)){set.delete(id);if(set===acked)changed=true;}}
   if(changed)report();
   const fresh=lit.filter(id=>!acked.has(id)&&!shown.has(id));
   for(const id of fresh){shown.add(id);newest=id;}
   current=lit;if(newest!==null&&!lit.includes(newest))newest=lit.find(id=>!acked.has(id))??lit[0]??null;
   return fresh.length>0;
  },
  acknowledge(){
   const before=acked.size;for(const id of current)acked.add(id);if(acked.size!==before)report();
   if(newest===null||!current.includes(newest))newest=current[0]??null;
   return newest;
  },
 };
}
