// SPDX-License-Identifier: MIT
// ALR-51 / CKP-MFD-57 (WP-11, V1-FINAL §4, §8.6, §11): red and amber light the lamp; blue (announced) and grey
// (unreadable) are list-only, so they never blink and are never acknowledged or kept by the host. Opening the list
// acknowledges what is lit; the same problem never blinks again; amber -> red does. The caution model that produces
// these levels is checked on the built page (ckp-mfd-55-alert-list.spec.mjs); G3-135 rules stay in
// caution-seen-after-blink.test.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCautionMemory} from '../../../cockpit/.tmp/compiled/src/caution-ack.js';
import {isUnreadable} from '../../../cockpit/study/rocket-r1/alert-sentence.js';

const T0=Date.parse('2026-11-18T12:00:00Z'),H=3600000,WEEK=7*24*H;
const ref='0000000000000001',win='weekly:604800:main:main',key=JSON.stringify([ref,win]),reset=T0+2*24*H;
const item=(level,extra={})=>({id:JSON.stringify([ref,win,level]),stable:JSON.stringify([ref,win,level]),level,member:ref,text:{en:level,zh:level},...extra});
const grey={id:JSON.stringify(['unread','0000000000000002','timeout']),stable:JSON.stringify(['unread','0000000000000002']),level:'grey',member:'0000000000000002',settings:true,text:{en:'Kimi no reading',zh:'Kimi 读不到'}};
const blue={id:JSON.stringify(['reset','e1']),stable:JSON.stringify(['reset','e1']),level:'blue',member:ref,text:{en:'b',zh:'b'}};
const read=new Map([[key,{resetAt:reset,span:WEEK}]]);

test('ALR-51 grey and blue never blink, and pressing the lamp acknowledges none of them',()=>{
 let reported=[];const memory=createCautionMemory(ids=>{reported=ids;});
 assert.equal(memory.update([blue,grey],read),false);
 assert.equal(memory.acknowledge(),null);
 assert.deepEqual(reported,[],'nothing list-only reaches the host');
});
test('CKP-MFD-57 opening the list acknowledges the lit caution; the same problem never blinks again',()=>{
 let reported=[];const memory=createCautionMemory(ids=>{reported=ids;});
 const amber=item('amber',{cycle:reset});
 assert.equal(memory.update([amber,blue,grey],read),true,'a new amber blinks');
 assert.equal(memory.acknowledge(),amber.stable,'opening the list acknowledges it');
 assert.deepEqual(reported.map(id=>JSON.parse(id).slice(0,3)),[[ref,win,'amber']],'only the lit caution is kept');
 assert.equal(memory.update([amber,blue,grey],read),false,'reopening: steady');
 assert.equal(memory.update([item('red'),blue,grey],read),true,'amber -> red blinks again');
 assert.equal(memory.update([item('red'),blue,grey],read),false);
});
test('ALR-51 only a failure that stops reading is grey',()=>{
 for(const code of ['not_signed_in','timeout','keychain_denied','other','parse_error'])assert.equal(isUnreadable(code),true,code);
 for(const code of [null,undefined,'','ok','not_read_yet','reader_busy','usage_not_reported','no_usage_windows'])assert.equal(isUnreadable(code),false,String(code));
});
