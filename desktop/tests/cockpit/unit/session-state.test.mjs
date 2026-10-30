// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {SessionStateTracker} from '../../../cockpit/.tmp/compiled/src/session-state.js';
test('first observation and unchanged state never flash, even after cooldown',()=>{
 const model=new SessionStateTracker();
 for(const now of [0,1,30_000,90_000])assert.equal(model.update('a','idle',now).flash,false);
});
test('rapid transitions coalesce into one flash and keep the final state',()=>{
 const model=new SessionStateTracker();model.update('a','idle',0);
 const results=['working','done','error','idle'].map((state,i)=>model.update('a',state,100+i));
 assert.equal(results.filter(r=>r.flash).length,1);assert.equal(results.at(-1).state,'idle');
 assert.equal(model.update('a','idle',30_100).flash,false,'cooldown expiry queues nothing');
});
test('cooldown boundary is per session, not global',()=>{
 const model=new SessionStateTracker();model.update('a','idle',0);model.update('b','idle',0);
 assert.equal(model.update('a','working',100).flash,true);assert.equal(model.update('b','working',101).flash,true);
 assert.equal(model.update('a','done',30_099).flash,false);assert.equal(model.update('a','error',30_100).flash,true);
 assert.equal(model.update('b','done',30_100).flash,false);assert.equal(model.update('b','error',30_101).flash,true);
});
test('reduced motion and invisible changes never queue a later flash',()=>{
 const model=new SessionStateTracker();model.update('a','idle',0);
 assert.equal(model.update('a','working',10,true,true).flash,false);
 assert.equal(model.update('a','working',20,true,false).flash,false);
 assert.equal(model.update('a','done',30,false,false).flash,false);
 assert.equal(model.update('a','done',40,true,false).flash,false);
 assert.equal(model.update('a','error',50,true,false).flash,true);
});
test('clock reversal cannot bypass cooldown; clear forgets private session state',()=>{
 const model=new SessionStateTracker();model.update('a','idle',0);model.update('a','working',100);
 assert.equal(model.update('a','done',90).flash,false);model.clear();
 assert.deepEqual(model.update('a','error',200),{state:'error',changed:false,flash:false});
 for(const args of [['','idle',0],['a','unknown',0],['a','idle',NaN]])assert.throws(()=>model.update(...args));
});
