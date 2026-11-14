// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {memberPlanModels,memberReportedModels,memberModelList} from '../../../cockpit/.tmp/compiled/src/plan-models.js';
import {sample} from '../fixture.mjs';
// D86: published planModels pin a subscription's plan to the models it lets its user use; null means "use the developer match".
const withPlans=planModels=>{const data=sample();data.details={...(data.details??{}),...(planModels?{planModels}:{})};return data;};
test('a harness plan resolves to its published plan list',()=>{
 const data=withPlans([{planId:'openai-plus',basis:'access',modelIds:['astra','sol']}]);
 assert.deepEqual([...memberPlanModels(data,'codex','plus')].sort(),['astra','sol']);
});
test('without planModels, an unknown plan or a plan matching no published plan there is no list',()=>{
 assert.equal(memberPlanModels(withPlans(null),'codex','plus'),null);
 const data=withPlans([{planId:'claude-pro',basis:'access',modelIds:['opus']}]);
 assert.equal(memberPlanModels(data,'codex','plus'),null);
 assert.equal(memberPlanModels(data,'codex','unknown'),null);
 assert.equal(memberPlanModels(data,'codex',undefined),null);
 assert.equal(memberPlanModels(data,'gemini','pro'),null);
});
test('a harness plan covering several published tiers keeps only the models every tier lists',()=>{
 const data=withPlans([
  {planId:'openai-pro-5x',basis:'access',modelIds:['astra','sol','luna']},
  {planId:'openai-pro-100',basis:'access',modelIds:['astra','sol']},
  {planId:'openai-plus',basis:'access',modelIds:['luna']},
 ]);
 assert.deepEqual([...memberPlanModels(data,'codex','pro')].sort(),['astra','sol']);
});
test('a plan id that is itself published matches exactly, for any tool',()=>{
 const data=withPlans([{planId:'cursor-pro',basis:'access',modelIds:['sonnet']}]);
 assert.deepEqual([...memberPlanModels(data,'cursor','cursor-pro')],['sonnet']);
});

// D98: what the tool reports for the account decides first, then the published plan list, then the developer match (null).
test('the tool-reported models win over the published plan list, which wins over the developer match',()=>{
 const data=withPlans([{planId:'openai-plus',basis:'access',modelIds:['astra','sol']}]);
 data.details.subscriptions=[{subscriptionRef:'aaaaaaaaaaaaaaaa',resetCounts:[],credits:null,today:[],reportedModels:['luna']}];
 assert.deepEqual([...memberModelList(data,'codex','plus','aaaaaaaaaaaaaaaa')],['luna']);
 assert.deepEqual([...memberModelList(data,'codex','plus','bbbbbbbbbbbbbbbb')].sort(),['astra','sol']);
 assert.deepEqual([...memberModelList(data,'codex','plus',null)].sort(),['astra','sol']);
 assert.equal(memberModelList(data,'gemini','pro','bbbbbbbbbbbbbbbb'),null);
});
test('a subscription without reportedModels, or with an empty list, has no reported list',()=>{
 const data=withPlans(null);
 data.details.subscriptions=[{subscriptionRef:'aaaaaaaaaaaaaaaa',resetCounts:[],credits:null,today:[]},{subscriptionRef:'cccccccccccccccc',resetCounts:[],credits:null,today:[],reportedModels:[]}];
 assert.equal(memberReportedModels(data,'aaaaaaaaaaaaaaaa'),null);
 assert.equal(memberReportedModels(data,'cccccccccccccccc'),null);
 assert.equal(memberReportedModels(data,undefined),null);
});
