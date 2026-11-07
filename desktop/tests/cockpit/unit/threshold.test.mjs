// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { definitions } from '../../../cockpit/.tmp/compiled/generated/wire.js';
import { conforms } from '../../../cockpit/.tmp/compiled/src/schema.js';

test('cockpit query threshold follows the generated committed-setting choices', () => {
  for (const value of [undefined, 10, 15, 20, 25, 30, 40]) {
    const params = value === undefined ? {} : {redBelow: value};
    assert.equal(conforms(params, definitions.CockpitQueryParams, definitions), true);
  }
  for (const value of [null, 0, 16, 17, 26, 41, '15']) {
    assert.equal(conforms({redBelow: value}, definitions.CockpitQueryParams, definitions), false);
  }
});

test('D22 used display keeps severity based on remaining quota', async () => {
 const {positional}=await import('../../../cockpit/study/rocket-r1/engine-model.js');
 for(const [remaining,level] of [[40,'low'],[41,'mid'],[50,'mid'],[51,'ok'],[null,'none']]){
  const a={state:'ok',windows:[{kind:'5h',remaining}]};
  const left=positional(a,{redAt:40,pctMode:'left'},false).first;
  const used=positional(a,{redAt:40,pctMode:'used'},false).first;
  assert.equal(left.level,level);assert.equal(used.level,level);assert.equal(used.value,remaining===null?null:100-remaining);
 }
});
