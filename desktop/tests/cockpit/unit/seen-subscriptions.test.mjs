// SPDX-License-Identifier: MIT
// D474 decision 3 (C13, C45): the page side of the `seen` bridge, held to tests/shared/seen-subscriptions.json (the
// host side, #1289, reads the same file). Strict message validation, and the column rule in cockpitMembers.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CockpitBridge} from '../../../cockpit/.tmp/compiled/src/bridge.js';
import {cockpitMembers,setSeenSubscriptions,unseenMembers} from '../../../cockpit/.tmp/compiled/src/members.js';
import {appearance,capture,commands,pageId,source,shell} from '../fixture.mjs';

const fixture=JSON.parse(readFileSync(new URL('../../shared/seen-subscriptions.json',import.meta.url),'utf8'));
const refs=n=>Array.from({length:n},(_,i)=>(i+1).toString(16).padStart(16,'0'));
function bridge(){
 const events=[],got=[];let id=100;
 const view={clear(){},render(){},nextDeadline(){return null;},tick(){},configure(){},updateAppearance(){},shell(){},active(){},seen(ids){got.push(ids);}};
 const b=new CockpitBridge(pageId,source.origin,v=>events.push(JSON.parse(v)),view,()=>`00000000-0000-4000-8000-${String(++id).padStart(12,'0')}`);
 const send=commands();b.documentHidden(false);b.ready();assert.equal(b.receive(send('load',{appearance,shell}),source),true);
 return {b,send,got};
}

for(const m of fixture.messages)test(`seen message: ${m.name}`,()=>{
 const f=bridge(),ids=m.count?refs(m.count):m.ids;
 assert.equal(f.b.receive(f.send('seen',{ids}),source),m.valid);
 assert.equal(f.got.length,m.valid?1:0);
 if(m.valid)assert.deepEqual(f.got[0],ids);
});

test('seen message: extra fields are refused',()=>{
 const f=bridge();
 assert.equal(f.b.receive(f.send('seen',{ids:[],at:'1'}),source),false);
 assert.equal(f.b.receive(f.send('seen',{}),source),false);
 assert.equal(f.got.length,0);
});

// One emitted member per case member, in order: a dock row with one account each.
function data(members){
 const base=capture(),seed=base.projection.rows[0];
 base.projection.rows=[];base.subscriptions=[];
 for(const [i,m] of members.entries()){
  const row=structuredClone(seed),a=row.accounts[0];row.id=`synthetic-${i+1}`;row.surfaces=[...new Set([...(row.surfaces??[]),'dock'])];
  Object.assign(a,{subscriptionRef:m.key,accountLocator:m.key,valueState:m.valueState});row.accounts=[a];
  base.projection.rows.push(row);base.subscriptions.push({subscriptionRef:m.key,accounts:[{tool:row.id,account:structuredClone(a)}]});
 }
 return base;
}
for(const c of fixture.columns.cases)test(`seen columns: ${c.name}`,()=>{
 try{
  setSeenSubscriptions(c.seen);
  const d=data(c.members);
  assert.deepEqual(cockpitMembers(d).map(m=>m.key),c.shown);
  assert.deepEqual(unseenMembers(d).map(m=>m.key).sort(),c.members.map(m=>m.key).filter(k=>!c.shown.includes(k)).sort());
 }finally{setSeenSubscriptions(null);}
});

// macrevb-1290-6: a privacy clear drops the host's seen set. Until fresh seen state arrives, only a good reading gives a
// column (the never-read rule still applies: the host negotiated it); an old key no longer authorizes anything.
test('macrevb-1290-6 a privacy clear drops the seen set; fresh seen state authorizes again',async()=>{
 const {forgetSeenSubscriptions}=await import('../../../cockpit/.tmp/compiled/src/members.js');
 try{
  const d=data([{key:'0000000000000001',valueState:'none'},{key:'0000000000000002',valueState:'current'}]);
  setSeenSubscriptions(['0000000000000001']);
  assert.deepEqual(cockpitMembers(d).map(m=>m.key),['0000000000000001','0000000000000002']);
  forgetSeenSubscriptions();
  assert.deepEqual(cockpitMembers(d).map(m=>m.key),['0000000000000002'],'the old key cannot authorize the column');
  setSeenSubscriptions(['0000000000000001']);
  assert.deepEqual(cockpitMembers(d).map(m=>m.key),['0000000000000001','0000000000000002']);
  // A page that never got a seen set keeps today's rule across a clear.
  setSeenSubscriptions(null);forgetSeenSubscriptions();
  assert.deepEqual(cockpitMembers(d).map(m=>m.key),['0000000000000001','0000000000000002']);
 }finally{setSeenSubscriptions(null);}
});
