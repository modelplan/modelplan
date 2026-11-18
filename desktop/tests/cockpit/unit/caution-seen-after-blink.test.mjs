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
