// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {cockpitMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sessionAdmittedBy,toolDevelopers} from '../../../cockpit/.tmp/compiled/src/session-binding.js';
import {publicationFaders,moreFaderModels,historyUsage} from '../../../cockpit/.tmp/compiled/src/publication-faders.js';
import {sample} from '../fixture.mjs';

// D391 (owner 11-22): a subscription unticked in Settings has no subscription card, so its sessions never add models
// to any cockpit model view, even when local sessions use them. This replaces the D123/D135 live-use inclusion
// (the G3-176 report: ZCode unticked, yet GLM-5.3 showed under All as a fader card and an unlisted card).
test('D391 an unticked subscription contributes no models; its live and recorded sessions add none',()=>{
 const data=sample(),codex=data.projection.rows[0],seed=structuredClone(codex);
 codex.surfaces=['dock','menu','settings'];
 // ZCode unticked in Settings: the row keeps the menu/settings surfaces but has no card, so it is no cockpit member.
 const zai=seed;zai.id='zai';zai.name={en:'ZCode',zh:'ZCode'};zai.surfaces=['menu','settings'];zai.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});
 data.projection.rows=[codex,zai];
 const members=cockpitMembers(data);
 assert.deepEqual(members.map(m=>m.row.id),['codex']);
 const now=Date.now(),model=(id,developerId)=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 // A ticked codex session; a live ZCode session on a published GLM model; one on a model the producer cannot map.
 const live=[
  {sessionRef:'0000000000000001',source:'codex',subscriptionRef:null,model:'gpt-5',effort:'medium',projectLabel:null,lastObservedAt:new Date(now-60e3).toISOString(),state:'running',rate:null},
  {sessionRef:'0000000000000002',source:'zcode',subscriptionRef:null,model:'glm-5',effort:'medium',projectLabel:null,lastObservedAt:new Date(now-60e3).toISOString(),state:'running',rate:null},
  {sessionRef:'0000000000000003',source:'zcode',subscriptionRef:null,model:'unknown',modelDisplay:'GLM-5.3',effort:null,projectLabel:null,lastObservedAt:new Date(now-60e3).toISOString(),state:'running',rate:null},
 ];
 const recorded=[{sessionRef:'0000000000000004',source:'zcode',subscriptionRef:null,model:'glm-5',effort:null,projectLabel:null,lastObservedAt:new Date(now-3600e3).toISOString()}];
 // The deck's own wiring (prototype-deck render): only admitted sessions reach the model views.
 const admittedLive=live.filter(x=>sessionAdmittedBy(members,x)),admittedRecorded=recorded.filter(x=>sessionAdmittedBy(members,x));
 assert.deepEqual(admittedLive.map(s=>s.sessionRef),['0000000000000001']);
 assert.deepEqual(admittedRecorded.map(s=>s.sessionRef),[]);
 // A session of a ticked tool stays even when its subscriptionRef names no member (the account cannot be told apart).
 assert.equal(sessionAdmittedBy(members,{source:'codex',subscriptionRef:'ffffffffffffffff'}),true);
 const subscriptions=members.map(m=>({key:m.key,developer:toolDevelopers[m.row.id]??null,colour:'#ffffff'}));
 const publication={contractVersion:1,models:[model('gpt-5','openai')]};
 const published=[...publication.models,model('glm-5','zhipuai')];
 const more=moreFaderModels(published,admittedLive,admittedRecorded,subscriptions);
 const {faders}=publicationFaders(publication,admittedLive,more,subscriptions,{now,ownPlansOnly:true,recorded:admittedRecorded});
 // The ticked subscription's model leads as in use; the unticked one's models, listed or unlisted, never show.
 assert.deepEqual(faders.map(f=>f.id),['gpt-5']);
 assert.ok(faders.every(f=>f.unlisted!==true));
});

// ghglm-1171-1 (the D391×G3-133 overlap): the history ranking has no tool attribution, so usage recorded before
// unticking kept putting the unticked developer's models into the fader set for up to 30 days. A ranked model now
// passes the same developer rule as the plan filter; a ticked developer's ranked model still leads (G3-133).
test('D391 history usage of an unticked developer adds no fader; a ticked developer\'s ranked model still leads',()=>{
 const data=sample(),codex=data.projection.rows[0],seed=structuredClone(codex);
 codex.surfaces=['dock','menu','settings'];
 const zai=seed;zai.id='zai';zai.name={en:'ZCode',zh:'ZCode'};zai.surfaces=['menu','settings'];zai.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});
 data.projection.rows=[codex,zai];
 const subscriptions=cockpitMembers(data).map(m=>({key:m.key,developer:toolDevelopers[m.row.id]??null,colour:'#ffffff'}));
 const model=(id,developerId)=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 const publication={contractVersion:1,models:[model('gpt-5','openai')]};
 const published=[...publication.models,model('glm-5','zhipuai'),model('gpt-hist','openai')];
 const usage=historyUsage({models:{recent7d:{top:[
  {name:'glm-5',observedOutputTokens:10,observedRequests:1,share:1},
  {name:'gpt-hist',observedOutputTokens:99,observedRequests:9,share:9},
 ]}}});
 // No sessions at all: only the ranking could put glm-5 in (the deck passes the same map and key set).
 const more=moreFaderModels(published,[],[],subscriptions,new Set(usage.keys()));
 const {faders}=publicationFaders(publication,[],more,subscriptions,{now:Date.now(),ownPlansOnly:true,usage});
 assert.ok(!faders.some(f=>f.id==='glm-5'),'the unticked developer\'s ranked model must not show');
 assert.ok(faders.some(f=>f.id==='gpt-hist'),'a ticked developer\'s ranked model stays (G3-133)');
 // An unknown developer cannot establish ownership of unattributed history.
 const unknown=[...subscriptions,{key:'unknown-tool',developer:null,colour:'#ffffff'}];
 const loose=publicationFaders(publication,[],moreFaderModels(published,[],[],unknown,new Set(['glm-5'])),unknown,{now:Date.now(),ownPlansOnly:true,usage:historyUsage({models:{recent7d:{top:[{name:'glm-5',observedOutputTokens:10,observedRequests:1,share:1}]}}})});
 assert.ok(!loose.faders.some(f=>f.id==='glm-5'));
});

// ghglm-1171-1 round 2: with NOTHING ticked (no member rows at all), no ranked model can be the user's own plans'
// use, so history contributes nothing either — the empty developer set filters every id.
test('D391 with no ticked subscription, history usage adds no model at all',()=>{
 const data=sample(),seed=data.projection.rows[0];
 const zai=structuredClone(seed);zai.id='zai';zai.name={en:'ZCode',zh:'ZCode'};zai.surfaces=['menu','settings'];zai.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});
 data.projection.rows=[zai];
 assert.deepEqual(cockpitMembers(data),[]);
 const model=(id,developerId)=>({id,name:id,developerId,recommended:'medium',efforts:[{effort:'medium',star:true,ability:1,cost:1,time:null}]});
 const publication={contractVersion:1,models:[model('gpt-5','openai')]};
 const published=[...publication.models,model('glm-5','zhipuai')];
 const usage=historyUsage({models:{recent7d:{top:[{name:'glm-5',observedOutputTokens:10,observedRequests:1,share:1}]}}});
 assert.deepEqual(moreFaderModels(published,[],[],[],new Set(usage.keys())).map(m=>m.id),[]);
 assert.ok(!publicationFaders(publication,[],[],[],{now:Date.now(),ownPlansOnly:true,usage}).faders.some(f=>f.id==='glm-5'));
});
