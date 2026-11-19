// SPDX-License-Identifier: MIT
// G3-135 / CKP-STRIP-06 (owner 11-18): no click is needed. A caution that has blinked once counts as seen, survives
// close/reopen and an app restart (host-kept identities), and blinks again only when new or escalated.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCautionMemory} from '../../../cockpit/.tmp/compiled/src/caution-ack.js';

const T0=Date.parse('2026-11-13T12:00:00Z'),H=3600000,D=24*H,WEEK=7*D;
const ref='0000000000000001',win='weekly:604800:main:main',key=JSON.stringify([ref,win]);
function reading({remaining,resetAt,level}){
 const items=[];
 if(level==='red')items.push({id:JSON.stringify([ref,win,new Date(resetAt).toISOString()]),stable:JSON.stringify([ref,win,'red']),level:'red',member:ref,text:{en:'',zh:`${remaining}%`}});
 if(level==='amber')items.push({id:JSON.stringify([ref,win,new Date(resetAt).toISOString(),'forecast']),stable:JSON.stringify([ref,win,'amber']),level:'amber',member:ref,cycle:resetAt,text:{en:'',zh:`${remaining}%`}});
 return {items,read:new Map([[key,{resetAt,span:WEEK}]])};
}
function entry(host){const m=createCautionMemory(ids=>{host.ids=ids;});m.restore(host.ids);return m;}
const show=(m,r,canBlink)=>m.update(r.items,r.read,canBlink);
const reset=T0+5*D;

test('a blinked caution is seen without any press, across reopen and restart',()=>{
 const host={ids:[]};
 let page=entry(host);
 assert.equal(show(page,reading({remaining:48,resetAt:reset,level:'amber'})),true,'new caution blinks');
 assert.equal(host.ids.length,1,'blinking alone is reported to the host');
 page=entry(host);
 assert.equal(show(page,reading({remaining:47,resetAt:reset+30000,level:'amber'})),false,'reopen with drifted numbers is steady');
 page=entry({ids:[...host.ids]});
 assert.equal(show(page,reading({remaining:46,resetAt:reset,level:'amber'})),false,'restart is steady');
});

test('yellow to red escalation blinks again, once',()=>{
 const host={ids:[]};let page=entry(host);
 show(page,reading({remaining:48,resetAt:reset,level:'amber'}));
 page=entry(host);
 assert.equal(show(page,reading({remaining:20,resetAt:reset,level:'red'})),true);
 page=entry(host);
 assert.equal(show(page,reading({remaining:19,resetAt:reset,level:'red'})),false);
});

test('a caution that disappears and returns is new; a new cycle is new',()=>{
 const host={ids:[]};let page=entry(host);
 const red=n=>reading({remaining:n,resetAt:reset,level:'red'});
 show(page,red(20));
 show(page,reading({remaining:80,resetAt:reset,level:null}));
 page=entry(host);
 assert.equal(show(page,red(20)),true,'cleared then back blinks');
 const a=entry({ids:[]});show(a,reading({remaining:48,resetAt:reset,level:'amber'}));
 assert.equal(show(a,reading({remaining:48,resetAt:reset+WEEK,level:'amber'})),true,'next cycle blinks');
});

test('a caution not blinked (page inactive) is not marked seen',()=>{
 const host={ids:[]};let page=entry(host);
 assert.equal(show(page,reading({remaining:48,resetAt:reset,level:'amber'}),false),false);
 assert.equal(host.ids.length,0);
 assert.equal(show(page,reading({remaining:48,resetAt:reset,level:'amber'}),true),true,'blinks once it can');
});

test('a press on an unverified (fallback-keyed) account survives the next open within the session',()=>{
 const fb='codex#main',w='weekly:604800:main:main',fkey=JSON.stringify([fb,w]);
 const r=n=>({items:[{id:'x',stable:JSON.stringify([fb,w,'red']),level:'red',member:fb,text:{en:'',zh:`${n}%`}}],read:new Map([[fkey,{resetAt:reset,span:WEEK}]])});
 const host={ids:[]};let page=entry(host);
 assert.equal(show(page,r(20)),true);page.acknowledge();
 assert.equal(host.ids.length,1,'the host is told, so a rebuilt page can get it back');
 page=entry(host);
 assert.equal(show(page,r(19)),false,'reopen is steady');
});

test('activating the page re-syncs the lamp, so a caution that arrived while inactive blinks on activation',async()=>{
 const {readFileSync}=await import('node:fs');
 const view=readFileSync(new URL('../../../cockpit/src/view.ts',import.meta.url),'utf8');
 assert.match(view,/active\(value,now\)\{const was=active;[^}]*\}else if\(!was&&lastData\)\{if\(now!==undefined\)lastRenderedAt=now;syncCaution\(lastData,lastRenderedAt\);\}\}/);
});

// macrev2 11-19 (CKP-MFD-57): an amber forecast whose reset time is unknown has no cycle, yet an ordinary pause of the
// forecast (the window keeps a real reading) must not make its return blink again. Only a refill of the window (a new
// allowance) or a red escalation does.
function unknownReset({remaining,level}){
 const items=[];
 if(level==='amber')items.push({id:JSON.stringify([ref,win,null,'forecast']),stable:JSON.stringify([ref,win,'amber']),level:'amber',member:ref,text:{en:'',zh:`${remaining}%`}});
 if(level==='red')items.push({id:JSON.stringify([ref,win,null]),stable:JSON.stringify([ref,win,'red']),level:'red',member:ref,text:{en:'',zh:`${remaining}%`}});
 return {items,read:new Map([[key,{resetAt:null,span:WEEK,remaining}]])};
}
test('an unknown-reset forecast that pauses and returns does not blink again; a refill or a red escalation does',()=>{
 const host={ids:[]};let page=entry(host);
 assert.equal(show(page,unknownReset({remaining:48,level:'amber'})),true,'new forecast blinks');
 assert.equal(show(page,unknownReset({remaining:47,level:null})),false,'pause');
 assert.equal(show(page,unknownReset({remaining:45,level:'amber'})),false,'the forecast returns: steady');
 assert.equal(show(page,unknownReset({remaining:44,level:null})),false);
 assert.equal(show(page,unknownReset({remaining:46,level:'amber'})),false,'a small rise is not a refill');
 assert.equal(show(page,unknownReset({remaining:95,level:null})),false,'refill: the old condition is over');
 assert.equal(show(page,unknownReset({remaining:90,level:'amber'})),true,'a forecast after a refill is a recurrence');
 assert.equal(show(page,unknownReset({remaining:20,level:'red'})),true,'amber to red blinks');
});
test('an unknown-reset forecast acknowledged before a restart stays steady across a pause and return',()=>{
 const host={ids:[]};let page=entry(host);
 show(page,unknownReset({remaining:48,level:'amber'}));
 page=entry({ids:[...host.ids]});
 assert.equal(show(page,unknownReset({remaining:47,level:null})),false);
 assert.equal(show(page,unknownReset({remaining:46,level:'amber'})),false);
});

test('a restored or manually acknowledged unknown-reset forecast still detects a refill',()=>{
 // Restored after a restart: the stored identity has no cycle and was never shown on this page.
 const host={ids:[]};let page=entry(host);show(page,unknownReset({remaining:48,level:'amber'}));
 page=entry({ids:[...host.ids]});
 assert.equal(show(page,unknownReset({remaining:47,level:null})),false);
 assert.equal(show(page,unknownReset({remaining:95,level:null})),false,'refill');
 assert.equal(show(page,unknownReset({remaining:90,level:'amber'})),true,'recurrence after restore');
 // Acknowledged by a press before it ever blinked (page could not blink).
 const p2=entry({ids:[]});
 show(p2,unknownReset({remaining:48,level:'amber'}),false);p2.acknowledge();
 assert.equal(show(p2,unknownReset({remaining:47,level:null}),true),false);
 assert.equal(show(p2,unknownReset({remaining:95,level:null}),true),false);
 assert.equal(show(p2,unknownReset({remaining:90,level:'amber'}),true),true,'recurrence after a press');
});
