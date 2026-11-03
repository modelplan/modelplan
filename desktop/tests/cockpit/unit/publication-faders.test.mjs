// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {publicationFaders} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';

test('maps published model verdicts without inventing unknown readings',()=>{
 const input={contractVersion:1,models:[{id:'example',name:'Example',recommended:'medium',efforts:[
  {effort:'low',ability:20,cost:1,time:null},{effort:'medium',ability:30,cost:2,time:50},
  {effort:'high',ability:null,cost:3,time:60},
 ]}]};
 assert.deepEqual(publicationFaders(input),{accounts:[],faders:[{id:'example',name:'Example',short:'Example',rec:'Med',
  e:[['Low',20,1,null],['Med',30,2,50]],accounts:[],sessions:[]}]});
 assert.deepEqual(publicationFaders(null),{accounts:[],faders:[]});
 assert.deepEqual(publicationFaders({...input,contractVersion:2}),{accounts:[],faders:[]});
 assert.deepEqual(publicationFaders({contractVersion:1,models:[{...input.models[0],recommended:'high'}]}),{accounts:[],faders:[]});
});
