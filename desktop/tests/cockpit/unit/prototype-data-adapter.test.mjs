// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {prototypeEngineSupplement} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';
import {sample} from '../fixture.mjs';

test('study engine data adapter preserves wire credits and leaves absent metrics unavailable',()=>{
 const account=sample().projection.rows[0].accounts[0];
 account.credits={balance:37,unit:'credits'};
 assert.deepEqual(prototypeEngineSupplement(account),{
  todayTokens:null,todayAverageGenerationTps:null,resetCards:null,reserveCredits:{balance:37,unit:'credits'}
 });
 account.credits=null;
 assert.equal(prototypeEngineSupplement(account).reserveCredits,null);
});

test('details fixture keeps unavailable sources unknown rather than empty',async()=>{
 const {unavailablePrototypeDetailsFixture}=await import('../../../cockpit/.tmp/compiled/src/prototype-details-fixture-adapter.js');
 assert.deepEqual(unavailablePrototypeDetailsFixture(),{liveSessions:null,publication:null,resetEvents:null,history:null});
});

test('today displays total usage while keeping output and generation rate distinct',()=>{
 const account=sample().projection.rows[0].accounts[0];
 const ref=account.subscriptionRef='0123456789abcdef';
 const data={subscriptions:[{subscriptionRef:ref}],details:{subscriptions:[{subscriptionRef:ref,today:[{bindingBasis:'source-wide-current-binding',observedOutputTokens:45000,observedTotalTokens:33900000,generationTps:66}],resetCounts:null}]}};
 const got=prototypeEngineSupplement(account,data);
 assert.equal(got.todayTokens,33900000);
 assert.equal(got.todayAverageGenerationTps,66);
});

test('a subscription with no cockpit detail shows its own reset cards as the reserve (ZCode saved sign-in)',()=>{
 const account=sample().projection.rows[0].accounts[0];
 const at='2026-11-22T18:00:00Z',id=c=>c.repeat(64);
 account.subscriptionRef=null;
 account.resetCards={state:'complete',count:3,earliestExpiresAt:at,items:[{id:id('a'),expiresAt:at},{id:id('b'),expiresAt:at},{id:id('c'),expiresAt:'2026-11-25T00:00:00Z'}],truncated:false,sources:[{source:'zcode-account',observedAt:'2026-11-21T12:00:00Z'}]};
 assert.deepEqual(prototypeEngineSupplement(account).resetCards,[{kind:'reset',count:2,expiresAt:at},{kind:'reset',count:1,expiresAt:'2026-11-25T00:00:00Z'}]);
 // a partial list keeps the unlisted rest, with no expiry
 account.resetCards={...account.resetCards,state:'partial',count:5};
 assert.deepEqual(prototypeEngineSupplement(account).resetCards.at(-1),{kind:'reset',count:2,expiresAt:null});
 // another source's facts never stand in, even with no reference
 account.resetCards={...account.resetCards,sources:[{source:'codex-account',observedAt:'2026-11-21T12:00:00Z'}]};
 assert.equal(prototypeEngineSupplement(account).resetCards,null);
 account.resetCards={...account.resetCards,sources:[]};
 assert.equal(prototypeEngineSupplement(account).resetCards,null);
 account.resetCards={...account.resetCards,sources:[{source:'zcode-account',observedAt:'2026-11-21T12:00:00Z'}]};
 // unknown, none left and an unreadable count say nothing
 for(const facts of [{state:'unknown',count:null,sources:[],truncated:false},{state:'complete',count:0,items:[],sources:[],truncated:false},{state:'partial',count:null,sources:[],truncated:false}]){
  account.resetCards=facts;
  assert.equal(prototypeEngineSupplement(account).resetCards,null);
 }
 // an account that has a reference keeps the detail path only (Codex: no change)
 account.subscriptionRef='fedcba9876543210';
 account.resetCards={state:'complete',count:1,earliestExpiresAt:at,items:[{id:id('e'),expiresAt:at}],truncated:false,sources:[]};
 assert.equal(prototypeEngineSupplement(account).resetCards,null);
 // a verified subscription's detail still wins
 const ref=account.subscriptionRef='0123456789abcdef';
 account.resetCards={state:'complete',count:1,earliestExpiresAt:at,items:[{id:id('d'),expiresAt:at}],truncated:false,sources:[]};
 const detail=[{kind:'full',count:4,expiresAt:null}];
 const got=prototypeEngineSupplement(account,{subscriptions:[{subscriptionRef:ref}],details:{subscriptions:[{subscriptionRef:ref,today:[],resetCounts:detail}]}});
 assert.deepEqual(got.resetCards,detail);
});
