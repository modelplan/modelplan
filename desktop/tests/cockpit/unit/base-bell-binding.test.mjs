// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {cockpitMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sessionMemberKey} from '../../../cockpit/.tmp/compiled/src/prototype-base.js';
import {visualFixture} from '../visual-fixture.mjs';

// CKP-ENG-17 (D73): a bell burns from the real session signal, bound like the faders and the record strip
// (session-binding.ts sessionMember(), #761): a verified ref wins, an unknown ref binds nothing, and a session
// without one joins its tool's only subscription.
test('base bells bind running sessions by the session-binding rule',()=>{
 const data=visualFixture().data,members=cockpitMembers(data);
 const codex=members.find(m=>m.row.id==='codex'),claude=members.find(m=>m.row.id==='claude');
 assert.ok(codex&&claude);
 assert.equal(sessionMemberKey(members,{source:'Codex',subscriptionRef:null}),codex.key);
 assert.equal(sessionMemberKey(members,{source:'claude-code',subscriptionRef:null}),claude.key);
 assert.equal(sessionMemberKey(members,{source:'Codex',subscriptionRef:claude.key}),claude.key);
 assert.equal(sessionMemberKey(members,{source:'Codex',subscriptionRef:'ffffffffffffffff'}),null);
 assert.equal(sessionMemberKey(members,{source:'unknown-harness',subscriptionRef:null}),null);
 // Two subscriptions of one tool: nothing says which account ran it.
 const two=[...members,{...codex,key:'0000000000000099'}];
 assert.equal(sessionMemberKey(two,{source:'Codex',subscriptionRef:null}),null);
});
