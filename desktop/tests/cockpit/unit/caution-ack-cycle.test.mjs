// SPDX-License-Identifier: MIT
// G3-106 / CKP-STRIP-06: a pressed quota caution stays acknowledged across cockpit entries. Only a new reset cycle of
// its window or a red escalation is a recurrence. The amber "won't last" caution comes from the engine's forecast,
// which comes and goes with the recent usage rate (an idle hour drops it, the next burst brings it back with other
// numbers); that drift is the same caution, not a clear and return. Normal entry path: open, press, close, reopen
// (a new page restored from what the host kept), with the percent, the ETA and the reset time drifting.
// The items have the shape caution.ts gives them (stable [member, window, severity], amber with its cycle); the full
// page path is in tests/cockpit/browser/c-lamp-ack.spec.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCautionMemory} from '../../../cockpit/.tmp/compiled/src/caution-ack.js';

const T0=Date.parse('2026-11-13T12:00:00Z'),H=3600000,D=24*H,WEEK=7*D;
const ref='0000000000000001',win='weekly:604800:main:main',key=JSON.stringify([ref,win]);
// One reading of the Codex weekly window: what caution.ts lights and which windows have a real reading.
function reading({remaining,resetAt,forecast}){
 const items=[];
 if(remaining<=25)items.push({id:JSON.stringify([ref,win,new Date(resetAt).toISOString()]),stable:JSON.stringify([ref,win,'red']),level:'red',member:ref,text:{en:'',zh:`Codex 每周 剩 ${remaining}%`}});
 else if(forecast)items.push({id:JSON.stringify([ref,win,new Date(resetAt).toISOString(),'forecast']),stable:JSON.stringify([ref,win,'amber']),level:'amber',member:ref,cycle:resetAt,text:{en:'',zh:`Codex 每周 ${remaining}% · 撑不到 5d2h 后重置`}});
 return {items,read:new Map([[key,{resetAt,span:WEEK}]])};
}
// One cockpit entry: a new page whose memory the host restored from the ids the previous page reported.
function entry(host){const memory=createCautionMemory(ids=>{host.ids=ids;});memory.restore(host.ids);return memory;}
const show=(memory,r)=>memory.update(r.items,r.read);

test('G3-106 a pressed amber caution stays steady on the next entry while its forecast drifts or pauses',()=>{
 const host={ids:[]},reset=T0+5*D+2*H;
 let page=entry(host);assert.equal(show(page,reading({remaining:60,resetAt:reset,forecast:true})),true,'a new caution blinks');
 page.acknowledge();assert.equal(host.ids.length,1,'the press is reported to the host');
 // Close and reopen: other numbers and the reset time jittered by half a minute.
 page=entry(host);assert.equal(show(page,reading({remaining:59,resetAt:reset+30000,forecast:true})),false,'drifted numbers are the same caution');
 // An idle hour: the recent rate falls away, so the engine has no run-out for a while. The window is still read.
 assert.equal(show(page,reading({remaining:59,resetAt:reset,forecast:false})),false);
 assert.equal(host.ids.length,1,'a paused forecast is not a clear, so the host keeps the press');
 // Next entry, usage resumes: the forecast is back with another ETA. Same window, same cycle, same severity.
 page=entry(host);assert.equal(show(page,reading({remaining:57,resetAt:reset-45000,forecast:true})),false,'the returning forecast stays steady');
 // The same within one page (no reopen).
 assert.equal(show(page,reading({remaining:57,resetAt:reset,forecast:false})),false);
 assert.equal(show(page,reading({remaining:56,resetAt:reset,forecast:true})),false);
});

test('G3-106 a red escalation, and then a new reset cycle, are recurrences and blink again',()=>{
 const host={ids:[]},reset=T0+5*D+2*H;
 let page=entry(host);show(page,reading({remaining:60,resetAt:reset,forecast:true}));page.acknowledge();
 assert.equal(show(page,reading({remaining:20,resetAt:reset,forecast:true})),true,'crossing the red line blinks');page.acknowledge();
 // The window resets: a fresh reading in the next cycle clears both, and the next cycle's amber caution is new.
 page=entry(host);assert.equal(show(page,reading({remaining:100,resetAt:reset+WEEK,forecast:false})),false);
 assert.deepEqual(host.ids,[]);
 page=entry(host);assert.equal(show(page,reading({remaining:50,resetAt:reset+WEEK,forecast:true})),true,'the next cycle blinks again');
});

test('G3-106 a new cycle seen only after a restart still blinks, because the cycle travels with the id',()=>{
 const host={ids:[]},reset=T0+5*D+2*H;
 let page=entry(host);show(page,reading({remaining:60,resetAt:reset,forecast:true}));page.acknowledge();
 // The app was closed over the reset; the first reading after relaunch is already amber in the next cycle.
 page=entry(host);assert.equal(show(page,reading({remaining:40,resetAt:reset+WEEK,forecast:true})),true);
});

test('G3-106 persisted ids: amber carries its cycle, red keeps the G3-56 form, all within the host bound',()=>{
 const host={ids:[]},reset=T0+5*D+2*H;
 const page=entry(host);show(page,reading({remaining:60,resetAt:reset,forecast:true}));page.acknowledge();
 show(page,reading({remaining:10,resetAt:reset,forecast:true}));page.acknowledge();
 for(const id of host.ids)assert.ok(new TextEncoder().encode(id).length<=200);
 const parsed=host.ids.map(id=>JSON.parse(id));
 assert.deepEqual(parsed.find(p=>p[2]==='red'),[ref,win,'red']);
 assert.deepEqual(parsed.find(p=>p[2]==='amber'),[ref,win,'amber',new Date(reset).toISOString().replace('.000Z','Z')]);
 // A red caution still clears on a real reading above the red line in the same cycle (G3-56), and returns blinking.
 assert.equal(show(page,reading({remaining:30,resetAt:reset,forecast:true})),false);
 assert.ok(!host.ids.some(id=>JSON.parse(id)[2]==='red'));
 assert.equal(show(page,reading({remaining:10,resetAt:reset,forecast:true})),true);
});
