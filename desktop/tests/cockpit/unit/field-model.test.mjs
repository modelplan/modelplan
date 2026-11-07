// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {fieldFleet,fieldModel,FIELD_LIMIT} from '../../../cockpit/.tmp/compiled/src/field-model.js';

const model=(id,efforts,developerId='openai')=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts});
test('a published model becomes the scene shape, on its starred effort',()=>{
 const m=fieldModel(model('a',[{effort:'low',label:'Low',ability:30,cost:.1,time:20},{effort:'medium',label:'Med',star:true,ability:40,cost:.2,time:30}]));
 assert.equal(m.rec,'Med');assert.deepEqual(m.sel,['Med',40,.2,30]);assert.equal(m.dev,'openai');assert.equal(m.e.length,2);
});
test('an effort without published ability or cost is not plotted, and a model with none is left out',()=>{
 assert.equal(fieldModel(model('a',[{effort:'low',label:'Low',ability:null,cost:.1},{effort:'medium',label:'Med',ability:40}])),null);
 assert.equal(fieldModel(model('b',[{effort:'low',label:'',ability:30,cost:.1,time:null},{effort:'high',label:'High',cost:.1}])).e.length,1);
});
test('developers map to the scene keys, others stay neutral',()=>{
 const efforts=[{effort:'low',label:'Low',ability:30,cost:.1}];
 assert.equal(fieldModel(model('a',efforts,'zhipuai')).dev,'zhipu');assert.equal(fieldModel(model('b',efforts,'someone')).colour,'#c6ccd4');
});
test('the fleet keeps publication order and the limit',()=>{
 const all=Array.from({length:14},(_,i)=>fieldModel(model('m'+i,[{effort:'low',label:'Low',ability:30,cost:.1}])));
 const fleet=fieldFleet(all,new Set(all.map(m=>m.id).reverse()));assert.equal(fleet.length,FIELD_LIMIT);assert.equal(fleet[0].id,'m0');
});
