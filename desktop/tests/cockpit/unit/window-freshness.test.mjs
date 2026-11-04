// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {currentWindow,displayWindow} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';
import {sample} from '../fixture.mjs';

test('window freshness follows producer current flag and deadline independently of the account',()=>{
 const account=sample().projection.rows[0].accounts[0],window={...account.windows[0],current:true,validUntil:'2026-10-29T13:00:00Z'};
 const now=Date.parse('2026-10-29T12:00:00Z');account.valueState='current';
 assert.equal(currentWindow(account,window,now),true);
 assert.equal(currentWindow(account,{...window,current:false},now),false);
 assert.equal(currentWindow(account,{...window,remainingPercent:null},now),false);
 assert.equal(currentWindow(account,{...window,validUntil:null},now),false);
 assert.equal(currentWindow(account,{...window,validUntil:'invalid'},now),false);
 assert.equal(currentWindow(account,window,Date.parse(window.validUntil)),false);
 account.valueState='retained';assert.equal(currentWindow(account,window,now),false);assert.equal(displayWindow(account,window,now),true);
 account.valueState='none';assert.equal(displayWindow(account,window,now),false);
});
