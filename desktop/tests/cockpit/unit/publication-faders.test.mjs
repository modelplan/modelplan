// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {publicationFaders,scopedFaders,moreFaderModels,historyUsage} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';

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

test('D135 models used in the last 7 days stay even when no own plan offers them; others are still filtered',()=>{
 const model=(id,ability,developerId='openai')=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability,cost:1,time:null}]});
 const now=Date.parse('2026-11-11T00:00:00Z'),day=86_400_000;
 const live=[
  {sessionRef:'0000000000000001',subscriptionRef:null,model:'api-key-model',lastObservedAt:new Date(now-2*day).toISOString()},
  {sessionRef:'0000000000000002',subscriptionRef:null,model:'api-key-model',lastObservedAt:new Date(now-3*day).toISOString()},
  {sessionRef:'0000000000000003',subscriptionRef:null,model:'stale-foreign',lastObservedAt:new Date(now-8*day).toISOString()},
  {sessionRef:'0000000000000004',subscriptionRef:null,model:'retired-gone',lastObservedAt:new Date(now-1000).toISOString()},
 ];
 const subs=[{key:'s1',developer:'openai',colour:'#fff'}];
 const publication={contractVersion:1,models:[model('rec1',50,'openai'),model('rec2',60,'openai'),model('rec3',40,'openai')]};
 const more=[model('api-key-model',5,'google'),model('stale-foreign',99,'google'),model('unused-foreign',98,'google'),model('own-other',10)];
 const ids=publicationFaders(publication,live,more,subs,{now,ownPlansOnly:true}).faders.map(f=>f.id);
 // Used within 7 days: shown once, in the in-use group, before the starred recommendations.
 assert.deepEqual(ids,['api-key-model','rec1','rec2','rec3','own-other']);
 // A used model the publication no longer describes (retired) is skipped, not invented.
 assert.ok(!ids.includes('retired-gone'));
 // Show all lifts the plan filter; the in-use model is still listed once.
 const all=publicationFaders(publication,live,more,subs,{now,ownPlansOnly:false}).faders.map(f=>f.id);
 assert.equal(all.filter(id=>id==='api-key-model').length,1);
 assert.ok(all.includes('unused-foreign')&&all.includes('stale-foreign'));
});

test('G3-110 a subscription scope keeps only that subscription\'s faders; All keeps the D123 set',()=>{
 const model=(id,ability,developerId)=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability,cost:1,time:null}]});
 const now=Date.parse('2026-11-13T00:00:00Z');
 const subs=[{key:'codex',developer:'openai',colour:'#fff'},{key:'grok',developer:'xai',colour:'#fff'}];
 // gpt-x in use through the Codex subscription; glm-y in use through the Grok subscription's harness (a bound session).
 const live=[
  {sessionRef:'0000000000000001',subscriptionRef:'codex',model:'gpt-x',lastObservedAt:new Date(now-1000).toISOString()},
  {sessionRef:'0000000000000002',subscriptionRef:'grok',model:'glm-y',lastObservedAt:new Date(now-2000).toISOString()},
 ];
 const publication={contractVersion:1,models:[model('gpt-x',60,'openai'),model('grok-a',70,'xai'),model('gpt-z',50,'openai')]};
 const more=[model('grok-b',40,'xai'),model('glm-y',30,'zhipuai')];
 const {faders}=publicationFaders(publication,live,more,subs,{now,ownPlansOnly:true});
 const all=faders.map(f=>f.id);
 assert.deepEqual(scopedFaders(faders,null,true).map(f=>f.id),all);
 assert.deepEqual(scopedFaders(faders,'grok',true).map(f=>f.id),['glm-y','grok-a','grok-b']);
 assert.deepEqual(scopedFaders(faders,'codex',true).map(f=>f.id),['gpt-x','gpt-z']);
 // A subscription whose developer is unknown cannot be matched: the D123 set stays.
 assert.deepEqual(scopedFaders(faders,'other',false).map(f=>f.id),all);
});

// Sampling #930 (1): the 7-day "in use" set also counts the recorded sessions (details.recentSessions), not only the
// live ones. A recorded session counts for order and the D135 exemption but never attaches to a fader as a live session.
test('sampling-930 recorded sessions of the last 7 days count as in use; only live sessions attach to a fader',()=>{
 const model=(id,ability,developerId='openai')=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability,cost:1,time:null}]});
 const now=Date.parse('2026-11-14T00:00:00Z'),day=86_400_000;
 const recorded=[
  {sessionRef:'00000000000000r1',subscriptionRef:null,model:'foreign',lastObservedAt:new Date(now-2*day).toISOString()},
  {sessionRef:'00000000000000r2',subscriptionRef:null,model:'too-old',lastObservedAt:new Date(now-8*day).toISOString()},
 ];
 const subs=[{key:'s1',developer:'openai',colour:'#fff'}];
 const publication={contractVersion:1,models:[model('rec1',50),model('rec2',60),model('rec3',40)]};
 const published=[...publication.models,model('foreign',99,'google'),model('too-old',99,'google'),model('own',10)];
 const more=moreFaderModels(published,[],recorded,subs);
 assert.deepEqual(more.map(m=>m.id),['foreign','too-old','rec1','rec2','rec3','own']);
 const {faders}=publicationFaders(publication,[],more,subs,{now,ownPlansOnly:true,recorded});
 assert.deepEqual(faders.map(f=>f.id),['foreign','rec1','rec2','rec3','own']);
 assert.deepEqual(faders[0].sessions,[]);
});

// Sampling #930 (2): a subscription whose reading is stale or still loading is still the user's plan, so its developer's
// published models stay candidates; the deck passes every member, whatever its reading state.
test('sampling-930 every subscription developer adds its published models, in publication order',()=>{
 const model=(id,developerId)=>({id,name:id,developerId});
 const published=[model('a','openai'),model('b','anthropic'),model('c','google'),model('d','anthropic')];
 const subs=[{key:'s1',developer:'openai',colour:'#fff'},{key:'s2',developer:'anthropic',colour:'#fff'},{key:'s3',developer:null,colour:'#fff'}];
 assert.deepEqual(moreFaderModels(published,[{model:'c'}],[],subs).map(m=>m.id),['c','a','b','d']);
});

// G3-133 (owner test build 15): "in use" came only from live sessions and the 7-day session ledger, so a model the owner
// uses every day (history ranking, imported or recorded) sat behind an unused starred one. The history ranking
// (cockpitHistoryV1 models.recent7d / recent30d) orders models that no session shows: 7-day tokens, then 30-day tokens.
test('G3-133 history usage orders the faders: 7-day then 30-day tokens, before unused recommendations',()=>{
 const model=(id,ability)=>({id,name:id,developerId:'openai',recommended:'medium',efforts:[{effort:'medium',star:true,ability,cost:1,time:null}]});
 const publication={contractVersion:1,models:[model('astra',90),model('terra',80),model('sol',70)]};
 const usage=new Map([['sol',{d7:500,d30:900}],['terra',{d7:0,d30:50}]]);
 const {faders}=publicationFaders(publication,[],[],[],{now:Date.parse('2026-11-18T00:00:00Z'),usage});
 assert.deepEqual(faders.map(f=>f.id),['sol','terra','astra']);
 // A session seen in the last 7 days still leads the history order.
 const live=[{sessionRef:'0123456789abcdef',subscriptionRef:null,model:'astra',lastObservedAt:'2026-11-17T23:00:00Z'}];
 assert.deepEqual(publicationFaders(publication,live,[],[],{now:Date.parse('2026-11-18T00:00:00Z'),usage}).faders.map(f=>f.id),['astra','sol','terra']);
});
test('G3-133 a model used only in history stays in the own-plans set and in the extra candidates',()=>{
 const model=(id,developerId)=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 const publication={contractVersion:1,models:[model('a','openai')]};
 const subs=[{key:'s1',developer:'openai',colour:'#fff'}];
 const published=[model('a','openai'),model('b','openai'),model('g','google')];
 // D391 (ghglm-1171-1): ranked history has no tool attribution, so a model of a developer the subscriptions do not
 // run ('g') is dropped; a history-only model of a run developer ('b') stays — the G3-133 order case is Sol and
 // Astra, two models of one ticked plan.
 assert.deepEqual(moreFaderModels(published,[],[],subs,new Set(['b','g'])).map(m=>m.id),['b','a']);
 const {faders}=publicationFaders(publication,[],[published[1]],subs,{now:1,ownPlansOnly:true,usage:new Map([['b',{d7:1,d30:1}],['g',{d7:1,d30:1}]])});
 assert.deepEqual(faders.map(f=>f.id),['b','a']);
});

test('macrevd-1039-1 historyUsage sums rows that map to one canonical model',()=>{
 const top=(name,n)=>({name,observedOutputTokens:n});
 const usage=historyUsage({models:{recent7d:{top:[top('sol',300),top('sol',200),top('terra',400)]},recent30d:{top:[top('sol',10),top('sol',5)]}}});
 assert.deepEqual(usage.get('sol'),{d7:500,d30:15});
 assert.deepEqual(usage.get('terra'),{d7:400,d30:0});
});

// WP-05 (D292, owner 11-17): aaScore rides along as a fifth reading only when published; ability (index 1) stays our score.
test('WP-05 carries a published aaScore as a reference after time, never in place of ability',()=>{
 const p={contractVersion:1,models:[{id:'m',name:'M',recommended:'high',efforts:[
  {effort:'high',star:true,ability:42.8,cost:.375,time:104,aaScore:61.5},{effort:'max',star:false,ability:47.5,cost:1.056,time:221},
  {effort:'low',star:false,ability:33.9,cost:.132,time:38,aaScore:-1}]}]};
 assert.deepEqual(publicationFaders(p).faders[0].e,[['Low',33.9,.132,38],['High',42.8,.375,104,61.5],['Max',47.5,1.056,221]]);
});
