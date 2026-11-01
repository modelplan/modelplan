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
