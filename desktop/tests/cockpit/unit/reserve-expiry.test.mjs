// SPDX-License-Identifier: MIT
// D474 §5.1 / C7: the page's 48 h reserve rule against the shared fixture the native helper also reads (#1289).
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {RESERVE_SOON_H,reserveSoon} from '../../../cockpit/study/rocket-r1/reserve-expiry.js';
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';

const fixture=JSON.parse(readFileSync(new URL('../../shared/reserve-expiry.json',import.meta.url),'utf8'));
const now=Date.parse(fixture.now);

test('the threshold is the fixture\'s 48 h',()=>assert.equal(RESERVE_SOON_H,fixture.hours));
for(const c of fixture.cases)test(`reserve expiry: ${c.name}`,()=>{
 assert.equal(reserveSoon(c.expiresAt,now),c.soon);
 if(c.expiresAt!==null&&Number.isFinite(Date.parse(c.expiresAt)))assert.equal(reserveSoon(Date.parse(c.expiresAt),now),c.soon);
});

test('the band reserve line uses the same rule (no 72 h left)',()=>{
 const account=at=>({id:'z',name:'ZCode',short:'ZCode',colour:'#8f7dff',logo:'',state:'ok',windows:[],cards:[{count:1,expiresAt:at},{count:2,expiresAt:null}]});
 const model=at=>engineModel({now,accounts:[account(at)],alerts:[]},{page:0}).cols[0].reserve;
 assert.equal(model(now+47*3600e3).warn,true);assert.equal(model(now+47*3600e3).expiring,1);assert.equal(model(now+47*3600e3).cards,3);
 assert.equal(model(now+60*3600e3).warn,false);assert.equal(model(now+60*3600e3).expiring,0);
});
