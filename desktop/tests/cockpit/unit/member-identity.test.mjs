// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {cockpitMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sample} from '../fixture.mjs';
test('only admitted subscription references yield stable member identities',()=>{
 const data=sample(),row=data.projection.rows[0];data.projection.rows=[row];const account=row.accounts[0];
 assert.equal(cockpitMembers(data)[0].unstable,false);
 data.subscriptions=[];assert.equal(cockpitMembers(data)[0].unstable,true);
 account.subscriptionRef=null;for(const locator of ['1111111111111111',null]){account.accountLocator=locator;const [member]=cockpitMembers(data);assert.equal(member.key,'codex#saved_login_api');assert.equal(member.unstable,true);}
 row.accounts.push(structuredClone(account));const members=cockpitMembers(data);assert.deepEqual(members.map(m=>m.key),['codex#saved_login_api#1','codex#saved_login_api#2']);assert.ok(members.every(m=>m.unstable));
});
