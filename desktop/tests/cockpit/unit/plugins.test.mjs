// SPDX-License-Identifier: MIT
// v1.1 cockpit plugin framework (D121, D124, D126, D127): layout rule, pin rule, persisted state and the Swift mirror.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pluginLayout,pageOfSubscription} from '../../../cockpit/.tmp/compiled/src/plugin-layout.js';
import {PluginRegistry} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {builtinPlugins} from '../../../cockpit/.tmp/compiled/src/plugin-builtins.js';
import {parsePluginState,emptyPluginState,materialize,enabledPlugins,enablePlugin,disablePlugin,pinPlugin,movePlugin,setPluginSetting,pluginSettings} from '../../../cockpit/.tmp/compiled/src/plugin-state.js';

const plugin=(id,pinned=false)=>({id,pinned});
const summary=l=>({pages:l.pages.map(p=>[p.from,p.to,p.plugins.join('+'),p.slots]),hidden:l.hidden});

test('D124 columns = max(3, subscriptions + plugins), plugins fill the 3-wide layout before adding a column, max 6',()=>{
 // [subscriptions, plugins] -> [slots, plugins shown, hidden]
 const cases=[
  [1,0,3,'',[]],[1,1,3,'a',[]],[1,2,3,'a+b',[]],
  [2,0,3,'',[]],[2,1,3,'a',[]],[2,2,4,'a+b',[]],
  [3,0,3,'',[]],[3,1,4,'a',[]],[3,2,5,'a+b',[]],
  [4,0,4,'',[]],[4,1,5,'a',[]],[4,2,6,'a+b',[]],
  [5,0,5,'',[]],[5,1,6,'a',[]],[5,2,6,'a',['b']],
  [6,0,6,'',[]],[6,1,6,'',['a']],[6,2,6,'',['a','b']],
 ];
 for(const [subs,n,slots,shown,hidden] of cases){
  const l=pluginLayout(subs,[plugin('a'),plugin('b')].slice(0,n));
  assert.deepEqual(summary(l),{pages:[[0,subs,shown,slots]],hidden},`${subs} subscriptions × ${n} plugins`);
 }
});

test('more than six subscriptions: six-wide pages, unpinned plugins only fill free slots of the last page',()=>{
 assert.deepEqual(summary(pluginLayout(7,[])),{pages:[[0,6,'',6],[6,7,'',6]],hidden:[]});
 assert.deepEqual(summary(pluginLayout(7,[plugin('a'),plugin('b')])),{pages:[[0,6,'',6],[6,7,'a+b',6]],hidden:[]});
 assert.deepEqual(summary(pluginLayout(12,[plugin('a')])),{pages:[[0,6,'',6],[6,12,'',6]],hidden:['a']});
 assert.deepEqual(summary(pluginLayout(16,[plugin('a'),plugin('b')])),{pages:[[0,6,'',6],[6,12,'',6],[12,16,'a+b',6]],hidden:[]});
 assert.equal(pageOfSubscription(pluginLayout(13,[]),12),2);
 assert.equal(pageOfSubscription(pluginLayout(13,[]),5),0);
});

test('pinned plugins (max two) stay on page 1 and push subscriptions to later pages',()=>{
 assert.deepEqual(summary(pluginLayout(6,[plugin('a',true)])),{pages:[[0,5,'a',6],[5,6,'',6]],hidden:[]});
 assert.deepEqual(summary(pluginLayout(6,[plugin('a',true),plugin('b')])),{pages:[[0,5,'a',6],[5,6,'b',6]],hidden:[]});
 assert.deepEqual(summary(pluginLayout(12,[plugin('a',true),plugin('b',true)])),{pages:[[0,4,'a+b',6],[4,10,'',6],[10,12,'',6]],hidden:[]});
 // A third pin is ignored: it behaves as unpinned.
 assert.deepEqual(summary(pluginLayout(12,[plugin('a',true),plugin('b',true),plugin('c',true)])),{pages:[[0,4,'a+b',6],[4,10,'',6],[10,12,'c',6]],hidden:[]});
 // Pinned wins the last slot of a single page over an unpinned plugin earlier in the order.
 assert.deepEqual(summary(pluginLayout(5,[plugin('a'),plugin('b',true)])),{pages:[[0,5,'b',6]],hidden:['a']});
 // Fits on one page: page order follows the user's plugin order, not pin first.
 assert.deepEqual(summary(pluginLayout(3,[plugin('a'),plugin('b',true)])),{pages:[[0,3,'a+b',5]],hidden:[]});
 assert.equal(pageOfSubscription(pluginLayout(6,[plugin('a',true)]),5),1);
});

const registry=new PluginRegistry(builtinPlugins);
test('host state is parsed strictly and bounded',()=>{
 const good={version:1,entries:[{id:'placeholder',enabled:true,pinned:true},{id:'future-plugin',enabled:true,pinned:false}],settings:{placeholder:{intervalSeconds:5}}};
 assert.deepEqual(parsePluginState(good),good);
 for(const bad of [
  null,[],{version:2,entries:[],settings:{}},{version:1,entries:[],settings:{},extra:1},
  {version:1,entries:[{id:'Bad id',enabled:true,pinned:false}],settings:{}},
  {version:1,entries:[{id:'a',enabled:true,pinned:false},{id:'a',enabled:false,pinned:false}],settings:{}},
  {version:1,entries:[{id:'a',enabled:false,pinned:true}],settings:{}},
  {version:1,entries:['a','b','c'].map(id=>({id,enabled:true,pinned:true})),settings:{}},
  {version:1,entries:Array.from({length:33},(_,i)=>({id:'p'+i,enabled:false,pinned:false})),settings:{}},
  {version:1,entries:[],settings:{placeholder:{intervalSeconds:2.5}}},
  {version:1,entries:[],settings:{placeholder:{intervalSeconds:'10'}}},
  {version:1,entries:[{id:'a',enabled:'yes',pinned:false}],settings:{}},
 ])assert.equal(parsePluginState(bad),null,JSON.stringify(bad));
});

test('registry defaults, enable/remove, pin limit, order and setting ranges',()=>{
 // The placeholder is registered but off by default; the calendar is default-on (D121) once a host sent plugin state.
 // Without host state (defaults=false) nothing is on, so an older host draws the v1 table.
 assert.deepEqual(enabledPlugins(emptyPluginState,registry),[{id:'calendar',pinned:false,settings:{}}]);
 assert.deepEqual(enabledPlugins(emptyPluginState,registry,false),[]);
 assert.deepEqual(materialize(emptyPluginState,registry).entries,[{id:'placeholder',enabled:false,pinned:false},{id:'calendar',enabled:true,pinned:false}]);
 assert.deepEqual(materialize(emptyPluginState,registry,false).entries,[{id:'placeholder',enabled:false,pinned:false},{id:'calendar',enabled:false,pinned:false}]);
 assert.deepEqual(enablePlugin(emptyPluginState,registry,'placeholder',false).entries.filter(e=>e.enabled).map(e=>e.id),['placeholder'],'a page edit before host state does not switch defaults on');
 const on=disablePlugin(enablePlugin(emptyPluginState,registry,'placeholder'),registry,'calendar');
 assert.deepEqual(enabledPlugins(on,registry),[{id:'placeholder',pinned:false,settings:{intervalSeconds:10}}]);
 assert.equal(enablePlugin(emptyPluginState,registry,'unknown'),null);
 const pinned=pinPlugin(on,registry,'placeholder',true);assert.equal(pinned.entries[0].pinned,true);
 assert.equal(pinPlugin(emptyPluginState,registry,'placeholder',true),null,'an off plugin cannot be pinned');
 const off=disablePlugin(pinned,registry,'placeholder');assert.deepEqual(off.entries[0],{id:'placeholder',enabled:false,pinned:false});
 // Two other pins already: a third is refused. Unknown ids keep their place and survive edits.
 const crowded=parsePluginState({version:1,entries:[{id:'x',enabled:true,pinned:true},{id:'y',enabled:true,pinned:true},{id:'placeholder',enabled:true,pinned:false}],settings:{}});
 assert.equal(pinPlugin(crowded,registry,'placeholder',true),null);
 assert.deepEqual(movePlugin(crowded,registry,'placeholder',-1).entries.map(e=>e.id),['x','placeholder','y','calendar']);
 assert.equal(movePlugin(crowded,registry,'x',-1),null);
 assert.deepEqual(enabledPlugins(crowded,registry).map(p=>p.id),['placeholder','calendar'],'unregistered ids are kept but not drawn');
 // D124: sampling interval 3–30 s; out-of-range saved values fall back to the default.
 assert.equal(setPluginSetting(on,registry,'placeholder','intervalSeconds',2),null);
 assert.equal(setPluginSetting(on,registry,'placeholder','intervalSeconds',31),null);
 assert.deepEqual(pluginSettings(setPluginSetting(on,registry,'placeholder','intervalSeconds',3),registry,'placeholder'),{intervalSeconds:3});
 assert.deepEqual(pluginSettings(parsePluginState({version:1,entries:[],settings:{placeholder:{intervalSeconds:99}}}),registry,'placeholder'),{intervalSeconds:10});
});

test('the Swift Settings catalogue mirrors the web registry (ids, setting keys and ranges)',()=>{
 const swift=readFileSync(new URL('../../../native/ModelPlanSettings/Sources/ModelPlanSettings/CockpitPluginPreferences.swift',import.meta.url),'utf8');
 const ids=[...swift.matchAll(/CockpitPluginDefinition\(id: "([^"]+)"/g)].map(m=>m[1]);
 assert.deepEqual(ids,registry.list().map(p=>p.id));
 for(const plugin of registry.list())for(const s of plugin.settings)
  assert.match(swift,new RegExp(`CockpitPluginSettingSpec\\(key: "${s.key}", minimum: ${s.min}, maximum: ${s.max}, defaultValue: ${s.default}`),`${plugin.id}.${s.key}`);
 assert.match(swift,/maximumPinned = 2\b/);assert.match(swift,/maximumEntries = 32\b/);
});
