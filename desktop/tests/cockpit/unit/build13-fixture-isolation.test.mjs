// SPDX-License-Identifier: MIT
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {build13Profile} from '../build13-fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';

test('synthetic profiles do not share model arrays or nested effort data',()=>{
 const first=build13Profile(),second=build13Profile();
 const expected=second.details.publishedModels.length;
 first.details.publishedModels.push({...first.details.publishedModels[0],id:'test-only'});
 first.details.publishedModels[0].efforts[0].label='changed';
 first.details.publication.models[0].efforts[0].label='changed';
 const next=build13Profile();
 assert.equal(next.details.publishedModels.length,expected);
 assert.equal(next.details.publishedModels[0].efforts[0].label,second.details.publishedModels[0].efforts[0].label);
 assert.equal(next.details.publication.models[0].efforts[0].label,second.details.publication.models[0].efforts[0].label);
});

test('the walk retains its seeded models after another spec expands a profile',()=>{
 const previous=build13Profile();
 for(let i=0;i<12;i++)previous.details.publishedModels.push({...previous.details.publishedModels[0],id:`prior-${i}`});
 const scenarios=walkScenarios();
 const one=scenarios.find(s=>s.name==='one').data.details.publishedModels;
 const readable=scenarios.find(s=>s.name==='zcode-readable').data.details.publishedModels;
 const unreadable=scenarios.find(s=>s.name==='zcode-unreadable').data.details.publishedModels;
 assert.equal(one.length,5);
 assert.equal(readable.filter(m=>m.id==='walk-glm').length,1);
 assert.equal(unreadable.filter(m=>m.id==='walk-glm').length,1);
 assert.ok(!one.some(m=>m.id.startsWith('prior-')));
});
