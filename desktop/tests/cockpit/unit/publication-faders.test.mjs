// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {publicationFaders} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';

test('maps published model verdicts without inventing unknown readings',()=>{
 const input={contractVersion:1,models:[{id:'example',name:'Example',recommended:'medium',efforts:[
  {effort:'high',star:false,ability:null,cost:3,time:60},{effort:'low',star:false,ability:20,cost:1,time:null},
  {effort:'medium',star:true,ability:30,cost:2,time:50},
 ]}]};
 assert.deepEqual(publicationFaders(input),{accounts:[],faders:[{id:'example',name:'Example',short:'Example',rec:'Med',
  e:[['Low',20,1,null],['Med',30,2,50],['High',null,3,60]],accounts:[],sessions:[]}]});
 assert.deepEqual(publicationFaders({contractVersion:1,models:[{...input.models[0],efforts:input.models[0].efforts.map(e=>({...e,star:false}))}]}),{accounts:[],faders:[]});
 assert.deepEqual(publicationFaders(null),{accounts:[],faders:[]});
 assert.deepEqual(publicationFaders({...input,contractVersion:2}),{accounts:[],faders:[]});
 assert.deepEqual(publicationFaders({contractVersion:1,models:[{...input.models[0],recommended:'max'}]}),{accounts:[],faders:[]});
});

test('glm-450-4 ignores a starred duplicate when the retained recommended row is unstarred',()=>{
 const p={contractVersion:1,models:[{id:'model',name:'Example',recommended:'medium',efforts:[
  {effort:'medium',star:false,ability:10,cost:1,time:null},
  {effort:'medium',star:true,ability:20,cost:2,time:null},
 ]}]};
 assert.deepEqual(publicationFaders(p),{accounts:[],faders:[]});
});

test('CKP-FAD-02 models in use lead, then the publication order',()=>{
 const model=id=>({id,name:id,recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 const live=[{sessionRef:'0123456789abcdef',subscriptionRef:null,model:'c'},{sessionRef:'fedcba9876543210',subscriptionRef:null,model:'unknown'}];
 const {faders}=publicationFaders({contractVersion:1,models:[model('a'),model('b'),model('c')]},live);
 assert.deepEqual(faders.map(f=>f.id),['c','a','b']);
 assert.deepEqual(faders[0].sessions,[{ref:'0123456789abcdef',sub:null}]);
 assert.deepEqual(faders[1].sessions,[]);
});
