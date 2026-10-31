// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { CockpitBridge,MAX_MESSAGE_BYTES } from '../../../cockpit/.tmp/compiled/src/bridge.js';
import { appearance,capture,commands,pageId,sessionId,source } from '../fixture.mjs';
function fixture() {
  const events=[],calls=[];let retained=null,id=100;
  const view={clear(){retained=null;calls.push('clear');},render(data){retained=data;calls.push('render');},configure(){calls.push('configure');},active(v){calls.push('active:'+v);},dispose(){calls.push('dispose');}};
  const bridge=new CockpitBridge(pageId,source.origin,value=>{events.push(JSON.parse(value));calls.push(JSON.parse(value).type);},view,()=>`00000000-0000-4000-8000-${String(++id).padStart(12,'0')}`);
  const send=commands();bridge.documentHidden(false);bridge.ready();assert.equal(bridge.receive(send('load',{appearance}),source),true);
  assert.equal(bridge.receive(send('visibility',{visible:true,occluded:false,key:true}),source),true);
  return {bridge,send,events,calls,retained:()=>retained};
}
test('real Go cockpit encoding is the typed display input, ready once',()=>{
  const f=fixture();f.bridge.ready();assert.equal(f.events.filter(e=>e.type==='ready').length,1);
  const data=capture();assert.equal(f.bridge.receive(f.send('display',{data}),source),true);
  assert.deepEqual(f.retained(),data);assert.notEqual(f.retained(),data);
  assert.equal(f.bridge.state,'ready');
});
test('unknown, malformed, over-limit and unauthorized bridge messages have no effects',()=>{
  const f=fixture(),before=f.calls.length,base=JSON.parse(f.send('display',{data:capture()}));
  const mutations=[
    {...base,type:'credentials/result'}, {...base,type:'plugin/install'}, {...base,type:'openURL',url:'https://example.invalid'},
    {...base,extra:true}, {...base,version:2}, {...base,pageId:sessionId}, {...base,sessionId:pageId}, {...base,generation:'42'},
    {...base,storeEpoch:'epoch-a'}, {...base,generation:41}, {...base,generation:'01'}, {...base,generation:'18446744073709551616'},
    {...base,requestId:'not-an-id'}, {...base,sequence:'-1'}, {...base,viewRevision:'4'}, {...base,storeEpoch:'unavailable'},
    {...base,data:{...base.data,accessToken:'synthetic-secret'}}, {...base,data:{projection:{},subscriptions:[]}},
  ];
  for(const bad of mutations)assert.equal(f.bridge.receive(JSON.stringify(bad),source),false);
  for(const raw of ['null','[]','{','{}','{"version":1,"version":1}',JSON.stringify(base).replace('"data":','"data":null,"data":'),'{"__proto__":{}}',' '.repeat(MAX_MESSAGE_BYTES+1)])assert.equal(f.bridge.receive(raw,source),false);
  assert.equal(f.bridge.receive(JSON.stringify(base),{...source,isMainFrame:false}),false);
  assert.equal(f.bridge.receive(JSON.stringify(base),{...source,origin:'https://other.invalid'}),false);
  assert.equal(f.bridge.clear(' '.repeat(MAX_MESSAGE_BYTES+1),source),false);
  assert.equal(f.calls.length,before);assert.equal(f.retained(),null);
  assert.equal(f.bridge.receive(JSON.stringify(base),source),true,'rejected messages cannot consume sequence');
  assert.equal(f.bridge.receive(JSON.stringify(base),source),false,'replay');
});
test('strict wire validation rejects malformed identities and unauthorized rows',()=>{
  const f=fixture();
  for(const mutate of [
    d=>d.projection.rows.push(d.projection.rows[0]),
    d=>d.projection.rows[0].accounts[0].accountLocator='private/path',
    d=>d.projection.rows[0].consent='denied',
    d=>d.projection.rows[0].accounts[0].windows[0].remainingPercent="not-a-number",
    d=>d.projection.rows[0].accounts[0].observedAt='not-a-date',
    d=>d.projection.rows[0].accounts[0].observedAt='2026-02-30T12:00:00Z',
    d=>d.subscriptions[0].subscriptionRef='arbitrary',
  ]){const data=capture();mutate(data);assert.equal(f.bridge.receive(f.send('display',{data}),source),false);}
});
test('clear removes all retained values before acknowledgement and blocks old contexts',()=>{
  const f=fixture();assert.equal(f.bridge.receive(f.send('display',{data:capture()}),source),true);
  const old=f.send('display',{data:capture()});
  assert.equal(f.bridge.clear(f.send('clear',{generation:'42',viewRevision:'4'}),source),true);
  assert.equal(f.retained(),null);assert.equal(f.bridge.state,'cleared');
  assert.equal(f.calls.lastIndexOf('clear')<f.calls.lastIndexOf('cleared'),true);
  assert.equal(f.bridge.receive(old,source),false);
  assert.equal(f.bridge.receive(f.send('display',{data:capture()}),source),false);
  assert.equal(f.bridge.receive(f.send('display',{generation:'42',viewRevision:'4',data:capture()}),source),true);
  assert.equal(f.bridge.action('openHistory',capture().projection.rows[0].id),true);
});
test('epoch is equality-only; only an authoritative clear can reset the floor',()=>{
  const f=fixture();
  assert.equal(f.bridge.receive(f.send('display',{storeEpoch:'epoch-a',generation:'1',viewRevision:'4',data:capture()}),source),false);
  assert.equal(f.bridge.clear(f.send('clear',{storeEpoch:'epoch-a',generation:'1',viewRevision:'4'}),source),true);
  assert.equal(f.bridge.receive(f.send('display',{storeEpoch:'epoch-a',generation:'1',viewRevision:'4',data:capture()}),source),true);
  assert.equal(f.bridge.clear(f.send('clear',{storeEpoch:'epoch-z',generation:'100',viewRevision:'5'}),source),false);
  assert.equal(f.bridge.clear(f.send('clear',{storeEpoch:'epoch-a',generation:'0',viewRevision:'5',sessionId:pageId}),source),false);
});
test('same-floor invalidation and a new session cannot revive old deliveries',()=>{
  const f=fixture(),old=f.send('display',{data:capture()});
  assert.equal(f.bridge.clear(f.send('clear',{viewRevision:'4'}),source),true);
  assert.equal(f.bridge.receive(old,source),false);
  assert.equal(f.bridge.receive(f.send('display',{data:capture()}),source),false);
  assert.equal(f.bridge.clear(f.send('clear',{viewRevision:'5',sessionId:pageId}),source),true);
  assert.equal(f.bridge.clear(f.send('clear',{viewRevision:'6'}),source),false);
  assert.equal(f.bridge.receive(f.send('display',{viewRevision:'5',sessionId:pageId,data:capture()}),source),true);
});
test('only fixed actions are emitted, history is limited to currently displayed rows',()=>{
  const f=fixture();assert.equal(f.bridge.action('openURL'),false);assert.equal(f.bridge.action('chooseSetup','x'),false);
  assert.equal(f.bridge.action('openHistory','unknown'),false);assert.equal(f.bridge.action('openSettings'),true);
  f.bridge.receive(f.send('display',{data:capture()}),source);
  const tool=capture().projection.rows[0].id;assert.equal(f.bridge.action('openHistory',tool),true);
  f.bridge.clear(f.send('clear',{viewRevision:'4'}),source);assert.equal(f.bridge.action('openHistory',tool),false);
  assert.equal(f.events.filter(e=>e.type==='action').every(e=>e.generation==='41'&&e.requestId&&e.sequence),true);
});
test('visibility gates actions, and unload is terminal with no retained snapshot',()=>{
  const f=fixture();f.bridge.receive(f.send('display',{data:capture()}),source);
  for(const value of [{visible:false,occluded:false,key:true},{visible:true,occluded:true,key:true},{visible:true,occluded:false,key:false}]){
    assert.equal(f.bridge.receive(f.send('visibility',value),source),true);assert.equal(f.bridge.action('openSettings'),false);
  }
  f.bridge.receive(f.send('visibility',{visible:true,occluded:false,key:true}),source);
  f.bridge.documentHidden(true);assert.equal(f.bridge.state,'hidden');assert.equal(f.bridge.action('openSettings'),false);
  f.bridge.documentHidden(false);assert.equal(f.bridge.state,'ready');
  assert.equal(f.bridge.receive(f.send('unload'),source),true);assert.equal(f.retained(),null);
  assert.equal(f.bridge.state,'unloaded');assert.equal(f.bridge.receive(f.send('load',{appearance}),source),false);
  assert.equal(f.bridge.action('openSettings'),false);f.bridge.ready();
});
test('UTF-8 byte cap precedes decode, and non-finite JSON numbers fail the typed boundary',()=>{
  const f=fixture(),base=capture();
  const make=character=>({...base,projection:{...base.projection,rows:Array.from({length:7},(_,index)=>({...base.projection.rows[0],id:'tool-'+index,name:{en:character.repeat(60000),zh:'synthetic'}}))}});
  assert.equal(f.bridge.receive(f.send('display',{data:make('a')}),source),true);
  const oversized=f.send('display',{data:make('汉')});
  assert.ok(oversized.length<MAX_MESSAGE_BYTES&&Buffer.byteLength(oversized)>MAX_MESSAGE_BYTES);
  assert.equal(f.bridge.receive(oversized,source),false);
  const raw=f.send('display',{data:base}).replace(/("remainingPercent":)[^,}]+/,(_,key)=>key+'1e309');
  assert.equal(f.bridge.receive(raw,source),false);
});
test('declared plan rows remain visible but cannot request tool history',()=>{
  const f=fixture(),data=capture();data.projection.rows[0].kind='declared';data.projection.rows[0].id='declared:synthetic';
  assert.equal(f.bridge.receive(f.send('display',{data}),source),true);
  assert.equal(f.retained().projection.rows.length,data.projection.rows.length);
  assert.equal(f.bridge.action('openHistory','declared:synthetic'),false);
});
