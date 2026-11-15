// SPDX-License-Identifier: MIT
// D244 (owner 2026-11-13, G3-111): the cockpit's tabs, columns, HUD rows and cautions follow the one saved
// subscription order (Settings › Subscriptions), shared with the widget; with none saved they keep the engine order.
import test from 'node:test';
import assert from 'node:assert/strict';
import {cockpitMembers,memberOrder,setMemberOrder} from '../../../cockpit/.tmp/compiled/src/members.js';
import {CockpitBridge} from '../../../cockpit/.tmp/compiled/src/bridge.js';
import {appearance,commands,pageId,sample,source,shell} from '../fixture.mjs';

const emitted=['0123456789abcdef','claude#saved_login_api','cursor#saved_login_api','gemini#saved_login_api'];
test('saved order puts the members it names first, the rest after in engine order; a refresh never re-sorts',()=>{
 try {
  assert.deepEqual(cockpitMembers(sample()).map(m=>m.key),emitted,'no saved order: engine order');
  assert.equal(setMemberOrder(['gemini#saved_login_api','ffffffffffffffff','0123456789abcdef']),true);
  const expected=['gemini#saved_login_api','0123456789abcdef','claude#saved_login_api','cursor#saved_login_api'];
  assert.deepEqual(cockpitMembers(sample()).map(m=>m.key),expected,'a saved key with no member is skipped');
  // A new delivery (rows re-emitted in another order) keeps the saved order for the members it names.
  const shuffled=sample();shuffled.projection.rows.reverse();
  assert.deepEqual(cockpitMembers(shuffled).map(m=>m.key),['gemini#saved_login_api','0123456789abcdef','cursor#saved_login_api','claude#saved_login_api']);
  assert.equal(setMemberOrder([...memberOrder()]),false,'the same order is no change');
  assert.equal(setMemberOrder([]),true);
  assert.deepEqual(cockpitMembers(sample()).map(m=>m.key),emitted,'reset: engine order again');
 } finally {setMemberOrder([]);}
});

function page() {
 const calls=[];let id=200;
 const view={clear(){},render(){},nextDeadline(){return null;},tick(){},configure(_a,_r,_u,_m,order){calls.push(['configure',order]);},
  updateAppearance(_a,_n,_r,_u,_m,order){calls.push(['appearance',order]);},shell(){},active(){},dispose(){}};
 const bridge=new CockpitBridge(pageId,source.origin,()=>{},view,()=>`00000000-0000-4000-8000-${String(++id).padStart(12,'0')}`);
 return {bridge,calls,send:commands()};
}
test('load and appearance carry the saved order to the view; malformed orders are refused',()=>{
 const order=['gemini#saved_login_api','0123456789abcdef'];
 for(const bad of [[],['all'],['x'],[1],'0123456789abcdef',['0123456789abcdef','0123456789abcdef'],Array.from({length:257},(_,i)=>`row${i}#manual`)]){
  const f=page();f.bridge.documentHidden(false);f.bridge.ready();
  assert.equal(f.bridge.receive(f.send('load',{appearance,shell,memberOrder:bad}),source),false,JSON.stringify(bad).slice(0,40));
 }
 const f=page();f.bridge.documentHidden(false);f.bridge.ready();
 assert.equal(f.bridge.receive(f.send('load',{appearance,shell,memberOrder:order}),source),true);
 assert.deepEqual(f.calls.find(c=>c[0]==='configure')[1],order);
 assert.equal(f.bridge.receive(f.send('appearance',{...appearance,memberOrder:['claude#saved_login_api']}),source),true);
 assert.deepEqual(f.calls.at(-1),['appearance',['claude#saved_login_api']]);
 assert.equal(f.bridge.receive(f.send('appearance',{...appearance}),source),true,'no order is the default order');
 assert.deepEqual(f.calls.at(-1),['appearance',[]]);
 assert.equal(f.bridge.receive(f.send('appearance',{...appearance,memberOrder:['all']}),source),false);
 const plain=page();plain.bridge.documentHidden(false);plain.bridge.ready();
 assert.equal(plain.bridge.receive(plain.send('load',{appearance,shell}),source),true,'a load without an order is unchanged');
 assert.deepEqual(plain.calls.find(c=>c[0]==='configure')[1],[]);
});
