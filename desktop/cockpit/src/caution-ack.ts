// SPDX-License-Identifier: MIT
// CKP-STRIP-06 / G3-56: which cautions the owner has already seen. A caution blinks when it is new; pressing the lamp
// acknowledges it; only a real clear-and-return or a red escalation (a different stable identity) blinks it again.
// The identity is tool, window and severity (`CautionItem.stable`), never the reset time or the numbers.
import type {CautionItem} from './caution.js';

// The memory holds only opaque identities (member reference, window id, severity), never readings, so a view clear
// (the host's privacy barrier, also sent when the cockpit reloads) does not drop it: dropping it made every reload re-blink.
// Persistence is best effort: a web view with a non-persistent data store keeps it for the page's life only.
const KEY='mp.cockpit.cautionAck';
const load=():Set<string>=>{try{const raw=JSON.parse(window.localStorage.getItem(KEY)??'[]');return new Set(Array.isArray(raw)?raw.filter((x):x is string=>typeof x==='string').slice(0,200):[]);}catch{return new Set();}};
const save=(acked:Set<string>)=>{try{if(acked.size)window.localStorage.setItem(KEY,JSON.stringify([...acked]));else window.localStorage.removeItem(KEY);}catch{/* storage may be unavailable: the ack then lasts for this page only */}};
const window_=(stable:string)=>{try{const p=JSON.parse(stable);return Array.isArray(p)&&p.length===3?JSON.stringify([p[0],p[1]]):null;}catch{return null;}};

export interface CautionMemory {
 /** Records the current lamp conditions; true when one of them is new (never blinked and never acknowledged). */
 update(items:readonly CautionItem[],read:ReadonlySet<string>):boolean;
 /** The lamp was pressed: everything lit is acknowledged. Returns the newest acknowledged caution's stable identity. */
 acknowledge():string|null;
}
export function createCautionMemory():CautionMemory {
 const acked=load(),shown=new Set<string>();let current:string[]=[],newest:string|null=null;
 return {
  update(items,read){
   const lit=items.filter(x=>x.level!=='blue').map(x=>x.stable);
   // Recurrence: a condition is over only when its window has a real reading and no longer qualifies.
   let changed=false;
   for(const set of [acked,shown])for(const id of [...set]){const w=window_(id);if(w!==null&&read.has(w)&&!lit.includes(id)){set.delete(id);if(set===acked)changed=true;}}
   if(changed)save(acked);
   const fresh=lit.filter(id=>!acked.has(id)&&!shown.has(id));
   for(const id of fresh){shown.add(id);newest=id;}
   current=lit;if(newest!==null&&!lit.includes(newest))newest=lit.find(id=>!acked.has(id))??lit[0]??null;
   return fresh.length>0;
  },
  acknowledge(){
   for(const id of current)acked.add(id);save(acked);
   if(newest===null||!current.includes(newest))newest=current[0]??null;
   return newest;
  },
 };
}
