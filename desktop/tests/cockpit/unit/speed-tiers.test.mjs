// SPDX-License-Identifier: MIT
// CKP-FAD-11: the comparison's fast key follows the published speedTiers (the /v1/client data.speedTiers shape).
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {speedTierFor,compareSpeedTiers} from '../../../cockpit/.tmp/compiled/src/speed-tiers.js';
import {publicationFaders} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';
import {compareKeys,cmpState} from '../../../cockpit/study/rocket-r1/mfd-pages/views.js';

const {speedTiers}=JSON.parse(readFileSync(new URL('./client-speed-tiers.fixture.json',import.meta.url),'utf8')).data;

test('a published model id matches its tier entry, and a vendor model id matches when there is no published id',()=>{
 assert.deepEqual(speedTierFor(speedTiers,'sol-6.1'),{harness:'codex',speed:1.5,cost:2.5});
 assert.deepEqual(speedTierFor(speedTiers,'opus'),{harness:'claude-code',speed:2.5,cost:2});
 assert.deepEqual(speedTierFor(speedTiers,'gpt-6-sol'),{harness:'codex',speed:1.5,cost:2.5});
 assert.deepEqual(speedTierFor(speedTiers,'claude-opus-4-8'),{harness:'claude-code',speed:2.5,cost:2});
});
test('an unstated speed keeps the tier but marks the task time unknown; an unlisted model has no tier',()=>{
 assert.deepEqual(speedTierFor(speedTiers,'auto:openai:51617927bdb7d656'),{harness:'codex',speed:1,cost:2.5,taskTimeUnknown:true});
 assert.equal(speedTierFor(speedTiers,'not-a-model'),null);
 assert.equal(speedTierFor(speedTiers,''),null);
 assert.equal(speedTierFor(null,'sol-6.1'),null);
 assert.equal(speedTierFor([{id:'x',harness:'codex',models:'bad'},null,7],'sol-6.1'),null);
});
test('the first published tier wins when a model has several (fast before ultrafast)',()=>{
 assert.equal(speedTierFor(speedTiers,'astra').speed,1.5);
});
test('publicationFaders attaches the tier, only when one exists',()=>{
 const model=id=>({id,name:id,developerId:'d',recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 const {faders}=publicationFaders({contractVersion:1,models:[model('sol-6.1'),model('plain')],speedTiers});
 assert.deepEqual(faders.find(f=>f.id==='sol-6.1').tier,{harness:'codex',speed:1.5,cost:2.5});
 assert.equal('tier' in faders.find(f=>f.id==='plain'),false);
});
test('the fast key is dark without a tier and shows off|on with one (no session needed)',()=>{
 const model={id:'model0',name:'Sol',short:'Sol',rec:'Med',e:[['Med',1,1,50],['High',2,2,60]]};
 const dark=compareSpeedTiers(model,null),lit=compareSpeedTiers(model,{harness:'codex',speed:1.5,cost:2.5});
 const view=x=>({models:[{...model,pool:x.pool}],speedTiers:x.speedTiers,sessionRanking:[],accounts:[],now:0});
 const args={modelId:'model0',current:null,currentFast:false};
 assert.match(compareKeys(view(dark),{scope:null},args),/vk-fast" data-mat="part" aria-hidden="true"/);
 const html=compareKeys(view(lit),{scope:null},args);
 assert.match(html,/data-mfd="fast"/);assert.match(html,/aria-pressed="false"/);
 assert.deepEqual(cmpState(view(lit),{scope:null},args).tier,{speed:1.5,cost:2.5});
 const claude=compareSpeedTiers(model,{harness:'claude-code',speed:2.5,cost:2});
 assert.ok(cmpState(view(claude),{scope:null},args).tier);
});
