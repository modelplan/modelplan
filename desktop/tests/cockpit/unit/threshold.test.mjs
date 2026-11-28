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

test('D22 used display keeps severity based on remaining quota; D474 decision 2 amber is forecast-only', async () => {
 const {positional}=await import('../../../cockpit/study/rocket-r1/engine-model.js');
 // D474 decision 2 (C9): red at or under "turn red below"; amber only when the estimate runs out before the reset;
 // there is no 50 % rule, so a plain 41-51 % reading is ok.
 const plain={trend:null,runOutMin:null,resetIn:120};
 const before={trend:-1,runOutMin:60,resetIn:120};
 const after={trend:-1,runOutMin:180,resetIn:120};
 for(const [remaining,shape,forecast,level] of [
  [40,plain,false,'low'],[41,plain,false,'ok'],[50,plain,false,'ok'],[51,plain,false,'ok'],[null,plain,false,'none'],
  [41,before,true,'mid'],[50,before,true,'mid'],[80,before,true,'mid'],[40,before,true,'low'],
  [50,after,true,'ok'],[50,before,false,'ok'],
 ]){
  const a={state:'ok',forecast,windows:[{kind:'5h',remaining,...shape}]};
  const left=positional(a,{redAt:40,pctMode:'left'},false).first;
  const used=positional(a,{redAt:40,pctMode:'used'},false).first;
  const label=`${remaining}% ${JSON.stringify(shape)} forecast=${forecast}`;
  assert.equal(left.level,level,label);assert.equal(used.level,level,label);assert.equal(used.value,remaining===null?null:100-remaining);
 }
});
