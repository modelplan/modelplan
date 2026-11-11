// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {cockpitMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sample} from '../fixture.mjs';
test('only admitted subscription references yield stable member identities',()=>{
 const data=sample(),row=data.projection.rows[0];data.projection.rows=[row];const account=row.accounts[0];
 assert.equal(cockpitMembers(data)[0].unstable,false);
 data.subscriptions=[];assert.equal(cockpitMembers(data)[0].unstable,true);
 account.subscriptionRef=null;for(const locator of ['1111111111111111',null]){account.accountLocator=locator;const [member]=cockpitMembers(data);assert.equal(member.key,'codex#saved_login_api');assert.equal(member.unstable,true);}
 row.accounts.push(structuredClone(account));const members=cockpitMembers(data);assert.deepEqual(members.map(m=>m.key),['codex#saved_login_api#1','codex#saved_login_api#2']);assert.ok(members.every(m=>m.unstable));
});
import {sessionMember} from '../../../cockpit/.tmp/compiled/src/session-binding.js';
test('a subscriptionRef that matches no member binds nothing, even with one subscription of the tool',()=>{
 const data=sample(),row=data.projection.rows[0];data.projection.rows=[row];row.accounts=[row.accounts[0]];
 const members=cockpitMembers(data),tool=members[0].row.id;
 const source=Object.entries({codex:'codex',claude:'claude'}).find(([,t])=>t===tool)?.[0]??'codex';
 assert.equal(sessionMember(members,{source,subscriptionRef:null})?.key,members[0].key);
 assert.equal(sessionMember(members,{source,subscriptionRef:'ffffffffffffffff'}),null);
});
// Build 14c (owner): the widget showed one Codex subscription while the cockpit added Claude Code, Gemini CLI and Grok
// Build tabs and empty quota columns. The Dock reads only rows on the "dock" surface (native dockRows); the producer
// keeps signed-out, unreadable or unpermitted rows on the menu and settings surfaces only. The cockpit uses that rule.
test('build 14c: rows the widget hides (no dock surface) are not cockpit members, whatever their accounts hold',()=>{
 const data=sample(),seed=data.projection.rows[0];
 const hidden=(id,name,valueState)=>{const row=structuredClone(seed);row.id=id;row.name={en:name,zh:name};row.surfaces=['menu','settings'];row.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;a.valueState=valueState;});return row;};
 seed.surfaces=['dock','menu','settings'];
 data.projection.rows=[hidden('claude','Claude Code','none'),seed,hidden('gemini','Gemini CLI','none'),hidden('grok','Grok Build','retained')];
 assert.deepEqual(cockpitMembers(data).map(m=>m.row.id),['codex']);
 // The same rule as the Dock, which keeps every member of a dock row: a dock row whose account has no value yet is shown.
 const loading=structuredClone(seed);loading.id='kimi';loading.name={en:'Kimi',zh:'Kimi'};loading.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;a.valueState='none';});
 data.projection.rows.push(loading);assert.deepEqual(cockpitMembers(data).map(m=>m.row.id),['codex','kimi']);
});
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';
test('build 14c: one page of subscriptions has exactly one engine bay each and no empty padding bays',()=>{
 const account={name:'Codex',short:'Codex',alias:'Codex',colour:'#6aa8ff',logo:'',state:'ok',ageMin:null,support:'quota-only',windows:[],extras:[],cards:[],credits:null};
 for(const n of [1,2,3,6]){
  const m=engineModel({now:0,accounts:Array.from({length:n},(_,i)=>({...account,id:'a'+i})),alerts:[],caution:{level:null,key:''}},{few:'exact',page:0,scope:null,tint:true,pctMode:'left',redAt:25,lang:'en',now:0});
  assert.equal(m.slots,n);assert.equal(m.cols.length,n);
 }
});
