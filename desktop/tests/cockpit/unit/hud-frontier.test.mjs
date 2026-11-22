// SPDX-License-Identifier: MIT
// D386 (supersedes the CKP-PORT-04/07 order): the porthole HUD lists only the ability frontier of the selected scope, best ability first.
import test from 'node:test';
import assert from 'node:assert/strict';
import {frontierFleetOf,fleetOf,chartFleetOf} from '../../../cockpit/.tmp/compiled/src/hud-fleet.js';
import {shortLabel} from '../../../cockpit/study/rocket-r1/short-label.js';
import {cockpitMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sampleWithDetails} from '../fixture.mjs';

const eff=(ability,cost)=>[{effort:'low',label:'low',star:false,ability:ability-8,cost:cost/3,time:30},{effort:'high',label:'high',star:true,ability,cost,time:30}];
const model=(id,ability,cost,developerId='openai')=>({id,name:'Synthetic '+id,developerId,recommended:'high',efforts:eff(ability,cost)});
function data(published){const d=sampleWithDetails();d.details.publishedModels=published;return d;}
// cheap-weak, mid, strong are on the frontier; beaten costs more than mid and is weaker.
const field=[model('beaten',44,.9),model('strong',70,.9),model('cheap',40,.1),model('mid',55,.4)];

test('D386 an off-frontier model is not listed',()=>{
 const ids=frontierFleetOf(shortLabel,data(field),'all').map(m=>m.id);
 assert.ok(!ids.includes('beaten'));
 assert.ok(chartFleetOf(shortLabel,data(field),'all').some(m=>m.id==='beaten'),'the enlarged chart still has it as a dim point');
});
test('D386 the list is ordered by ability at ★ effort, high to low',()=>{
 assert.deepEqual(frontierFleetOf(shortLabel,data(field),'all').map(m=>m.id),['strong','mid','cheap']);
});
test('D386 the scope switch changes the list',()=>{
 const d=data([...field,model('claude-a',50,.2,'anthropic'),model('claude-b',60,.5,'anthropic')]);
 const members=cockpitMembers(d),claude=members.find(m=>m.row.id==='claude');
 assert.ok(claude,'fixture has a claude subscription');
 const all=frontierFleetOf(shortLabel,d,'all').map(m=>m.id),one=frontierFleetOf(shortLabel,d,claude.key).map(m=>m.id);
 assert.deepEqual(one,['claude-b','claude-a']);
 assert.notDeepEqual(all,one);
});
test('D386 the enlarged chart takes the same frontier first, then the beaten models as dim points',()=>{
 assert.deepEqual(chartFleetOf(shortLabel,data(field),'all').map(m=>m.id),['strong','mid','cheap','beaten']);
 assert.equal(fleetOf(shortLabel,data(field),'all').find(m=>m.id==='beaten').dominated,true);
});
