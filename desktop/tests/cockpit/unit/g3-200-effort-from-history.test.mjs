// SPDX-License-Identifier: MIT
// G3-200 (owner row 39): Sol 6.1 had seven days of recorded use but its effort read "unreported", so the effort trial had
// nothing to compare. A fader's effort now falls back to the latest recorded session that reported one (CKP-FAD-53 keeps
// the live 15-minute rule first).
import test from 'node:test';
import assert from 'node:assert/strict';
import {publicationFaders} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';

const now=Date.now(),iso=ms=>new Date(now-ms).toISOString();
const model={id:'sol-6.1',name:'Sol 6.1',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null},{effort:'high',ability:2,cost:2,time:null}]};
const publication={contractVersion:1,models:[model]};
const subs=[{key:'a'.repeat(16),developer:'openai',colour:'#ffffff'}];
const rec=(ref,effort,ms)=>({sessionRef:ref.repeat(16),source:'codex',subscriptionRef:null,model:'sol-6.1',effort,projectLabel:null,lastObservedAt:iso(ms)});
const run=(live,recorded)=>publicationFaders(publication,live,[],subs,{now,recorded}).faders[0];

test('a model with only recorded sessions takes its effort from the latest one that reported it',()=>{
 const f=run([],[rec('1','low',5*86400e3),rec('2','high',2*86400e3),rec('3',null,3600e3)]);
 assert.equal(f.recordedEffort,'High');
});
test('a recorded session older than seven days gives no effort',()=>{
 assert.equal(run([],[rec('1','high',8*86400e3)]).recordedEffort,undefined);
});
