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

test('D123 order: in use by recency, then starred recommendations, then others by ability; own plans only',()=>{
 const model=(id,ability,developerId='openai')=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability,cost:1,time:null}]});
 const now=Date.parse('2026-11-10T00:00:00Z'),day=86_400_000;
 const live=[
  {sessionRef:'0000000000000001',subscriptionRef:null,model:'old',lastObservedAt:new Date(now-1*day).toISOString()},
  {sessionRef:'0000000000000002',subscriptionRef:null,model:'newer',lastObservedAt:new Date(now-1000).toISOString()},
  {sessionRef:'0000000000000003',subscriptionRef:null,model:'stale',lastObservedAt:new Date(now-8*day).toISOString()},
 ];
 const subs=[{key:'s1',developer:'openai',colour:'#fff'}];
 const publication={contractVersion:1,models:[model('rec1',50),model('rec2',60),model('rec3',40)]};
 const more=[model('low',10),model('high',90),model('old',5),model('newer',5),model('stale',20),model('foreign',99,'google')];
 const {faders}=publicationFaders(publication,live,more,subs,{now,ownPlansOnly:true});
 assert.deepEqual(faders.map(f=>f.id),['newer','old','rec1','rec2','rec3','high','stale','low']);
 const all=publicationFaders(publication,live,more,subs,{now,ownPlansOnly:false}).faders.map(f=>f.id);
 assert.ok(all.includes('foreign'));
 // A subscription with no known developer cannot be matched, so nothing is filtered out.
 assert.ok(publicationFaders(publication,[],more,[...subs,{key:'s2',developer:null,colour:'#fff'}],{now,ownPlansOnly:true}).faders.some(f=>f.id==='foreign'));
});
