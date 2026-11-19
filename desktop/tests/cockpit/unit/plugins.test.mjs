// SPDX-License-Identifier: MIT
// Cockpit plugin framework (D121, D124, D293; CKP-PLG-50…54): layout rule, pin rule, persisted state, the plugin contract
// (cells in the Other-cell grammar, declared colours, long and short strings) and the Swift Settings mirror.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pluginLayout,pageOfSubscription} from '../../../cockpit/.tmp/compiled/src/plugin-layout.js';
import {PluginRegistry,builtinPlugins,placeholderPlugin,PLUGIN_INKS,PLUGIN_TOKENS} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {checkBudgets,tables} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/plugins.js';
import {parsePluginState,emptyPluginState,materialize,enabledPlugins,enablePlugin,disablePlugin,pinPlugin,movePlugin,setPluginSetting,pluginSettings} from '../../../cockpit/.tmp/compiled/src/plugin-state.js';

const plugin=(id,pinned=false)=>({id,pinned});
const summary=l=>({pages:l.pages.map(p=>[p.from,p.to,p.plugins.join('+'),p.slots]),hidden:l.hidden});

test('CKP-PLG-52 (D124) columns = max(3, subscriptions + plugins), plugins fill the 3-wide layout before adding a column, max 6',()=>{
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

test('CKP-PLG-52 pinned plugins (max two) stay on page 1 and push subscriptions to later pages',()=>{
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
 // The placeholder is registered but off by default, so a host without plugin state draws the v1 table.
 assert.deepEqual(enabledPlugins(emptyPluginState,registry),[]);
 assert.deepEqual(materialize(emptyPluginState,registry).entries,[{id:'placeholder',enabled:false,pinned:false}]);
 const on=enablePlugin(emptyPluginState,registry,'placeholder');
 assert.deepEqual(enabledPlugins(on,registry),[{id:'placeholder',pinned:false,settings:{intervalSeconds:10}}]);
 assert.equal(enablePlugin(emptyPluginState,registry,'unknown'),null);
 const pinned=pinPlugin(on,registry,'placeholder',true);assert.equal(pinned.entries[0].pinned,true);
 assert.equal(pinPlugin(emptyPluginState,registry,'placeholder',true),null,'an off plugin cannot be pinned');
 const off=disablePlugin(pinned,registry,'placeholder');assert.deepEqual(off.entries[0],{id:'placeholder',enabled:false,pinned:false});
 // Two other pins already: a third is refused. Unknown ids keep their place and survive edits.
 const crowded=parsePluginState({version:1,entries:[{id:'x',enabled:true,pinned:true},{id:'y',enabled:true,pinned:true},{id:'placeholder',enabled:true,pinned:false}],settings:{}});
 assert.equal(pinPlugin(crowded,registry,'placeholder',true),null);
 assert.deepEqual(movePlugin(crowded,registry,'placeholder',-1).entries.map(e=>e.id),['x','placeholder','y']);
 assert.equal(movePlugin(crowded,registry,'x',-1),null);
 assert.deepEqual(enabledPlugins(crowded,registry).map(p=>p.id),['placeholder'],'unregistered ids are kept but not drawn');
 // D124: sampling interval 3–30 s; out-of-range saved values fall back to the default.
 assert.equal(setPluginSetting(on,registry,'placeholder','intervalSeconds',2),null);
 assert.equal(setPluginSetting(on,registry,'placeholder','intervalSeconds',31),null);
 assert.deepEqual(pluginSettings(setPluginSetting(on,registry,'placeholder','intervalSeconds',3),registry,'placeholder'),{intervalSeconds:3});
 assert.deepEqual(pluginSettings(parsePluginState({version:1,entries:[],settings:{placeholder:{intervalSeconds:99}}}),registry,'placeholder'),{intervalSeconds:10});
});

test('CKP-PLG-50/51 plugin contract: cells in the Other-cell grammar, history kept by the plugin, declared colours only',()=>{
 // The page resolves plugin.* keys from the string tables (plugin-host pluginWords); the same rule here.
 const fill=(text,vars)=>text.replace(/\{(\w+)\}/g,(m,n)=>String(vars?.[n]??m));
 const context=locale=>({locale,settings:{intervalSeconds:10},words:(key,vars)=>({full:fill(tables[locale][key],vars),short:fill(tables[locale][key+'Short']??tables[locale][key],vars)})});
 // No reading yet: the tag and side text only, never a "--" number (V1-FINAL rule 2).
 const empty=placeholderPlugin.column(undefined,context('en'));
 assert.equal(empty.cells.length,1);assert.equal(empty.cells[0].value,null);assert.equal(empty.cells[0].bar,null);
 assert.deepEqual(empty.cells[0].tag,{full:'Last value',short:'Value'});
 assert.deepEqual(empty.cells[0].side,{full:'every 10 s',short:'10s'});
 assert.deepEqual(placeholderPlugin.screen(undefined,context('en')).lines.map(l=>l.label),['Update interval']);
 let state;for(const value of [10,40,25])state=placeholderPlugin.accept({value},state);
 const cell=placeholderPlugin.column(state,context('zh-CN')).cells[0];
 assert.equal(cell.value,25);assert.equal(cell.unit,'%');assert.equal(cell.bar,.25);assert.deepEqual(cell.trend,[.1,.4,.25]);
 assert.deepEqual(cell.tag,{full:'最近读数',short:'读数'});
 for(const bad of [{value:101},{value:-1},{value:1.5},{value:'1'},{value:1,extra:1},null])assert.equal(placeholderPlugin.accept(bad,state),undefined,JSON.stringify(bad));
 assert.equal(placeholderPlugin.accept({value:1},Array.from({length:24},()=>0)).length,24,'history is bounded');
 // Colours: only the V1-FINAL instrument white and grey and the D293 resource silver.
 assert.deepEqual([...PLUGIN_INKS],['#87939e','#e9edf0','#b9c7d6']);
 assert.throws(()=>new PluginRegistry([{...placeholderPlugin,underline:'#6aa8ff'}]),/colour/);
 assert.throws(()=>new PluginRegistry([{...placeholderPlugin,ink:'#ff0000'}]),/colour/);
 assert.throws(()=>new PluginRegistry([{...placeholderPlugin,title:'Placeholder'}]),/Invalid cockpit plugin/);
 // Every registered plugin's title (with its short form) and summary exist in both string tables.
 for(const plugin of registry.list())for(const key of [plugin.title,plugin.title+'Short',plugin.summary])assert.ok(tables.en[key]&&tables['zh-CN'][key],key);
});

test('plugin strings: both languages, the same variables, within budget, and a short form for every drawn label',()=>{
 const keys=Object.keys(tables.en).filter(k=>k.startsWith('plugin.'));
 assert.ok(keys.length>=20);
 const vars=v=>(v.match(/\{\w+\}/g)??[]).sort().join();
 for(const key of keys){assert.ok(tables['zh-CN'][key],key+' has no zh-CN');assert.equal(vars(tables.en[key]),vars(tables['zh-CN'][key]),key);}
 assert.deepEqual(checkBudgets().filter(x=>x.key.startsWith('plugin.')),[]);
 // Drawn in the table, the menus or the key: each has a <key>Short form (rule 1: long and short forms).
 for(const key of ['plugin.remove','plugin.close','plugin.connect','plugin.detected','plugin.notConnected','plugin.allSubscriptions','plugin.addPlugin','plugin.added',
  'plugin.placeholderTitle','plugin.placeholderTag','plugin.placeholderEvery','plugin.placeholderFoot'])assert.ok(tables.en[key+'Short']&&tables['zh-CN'][key+'Short'],key+' has no short form');
});

test('CKP-PLG-54 the Swift Settings catalogue mirrors the web registry (ids, summary, setting keys and ranges)',()=>{
 const swift=readFileSync(new URL('../../../native/ModelPlanSettings/Sources/ModelPlanSettings/CockpitPluginPreferences.swift',import.meta.url),'utf8');
 const ids=[...swift.matchAll(/CockpitPluginDefinition\(id: "([^"]+)"/g)].map(m=>m[1]);
 assert.deepEqual(ids,registry.list().map(p=>p.id));
 for(const plugin of registry.list())for(const s of plugin.settings)
  assert.match(swift,new RegExp(`CockpitPluginSettingSpec\\(key: "${s.key}", minimum: ${s.min}, maximum: ${s.max}, defaultValue: ${s.default}`),`${plugin.id}.${s.key}`);
 // CKP-PLG-54: Settings shows the page's own one sentence, in both languages.
 for(const plugin of registry.list())assert.ok(swift.includes(`summary: .init("${tables.en[plugin.summary]}", "${tables['zh-CN'][plugin.summary]}")`),`${plugin.id} summary`);
 assert.match(swift,/maximumPinned = 2\b/);assert.match(swift,/maximumEntries = 32\b/);
});

test('D323 custom draw: the registry stays DOM-free and the draw tokens are cockpit variables the sheets define',()=>{
 const source=readFileSync(new URL('../../../cockpit/src/plugin-registry.ts',import.meta.url),'utf8');
 assert.doesNotMatch(source,/\bdocument\.|\bwindow\.|^import (?!type)[^;]*from '\.\/(?:plugin-host|view|prototype-[a-z]+)\.js'/m);
 const sheets=['web/cockpit.css',...['theme','engine','mfd'].map(n=>`prototype/prototype-${n}.css`)].map(f=>readFileSync(new URL('../../../cockpit/'+f,import.meta.url),'utf8')).join('\n');
 for(const [name,value] of Object.entries(PLUGIN_TOKENS)){
  const variable=/^var\((--[a-z0-9-]+)\)$/.exec(value)?.[1];
  assert.ok(variable,name);assert.match(sheets,new RegExp(variable+':'),`${name} ${variable} is defined`);
 }
 // A plugin without draw is drawn from its cells exactly as before.
 assert.equal(placeholderPlugin.column(undefined,{locale:'en',settings:{intervalSeconds:10},words:k=>({full:k,short:k})}).draw,undefined);
});
