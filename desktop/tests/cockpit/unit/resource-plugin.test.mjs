// SPDX-License-Identifier: MIT
// Resource plugin (owner D324, D327): the page side. The host samples (ModelPlanResources ResourceSampler, system calls
// only) and pushes `pluginData` readings; the plugin folds them into a 10-minute in-memory history and describes the
// column (CPU · 内存 · 磁盘 cells) and the big screen. Order CPU · memory · disk everywhere a list is drawn (board 11-20).
import test from 'node:test';
import assert from 'node:assert/strict';
import {PluginRegistry,builtinPlugins,PLUGIN_INKS} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {resourcePlugin,RESOURCE_INK,RESOURCE_WINDOW_MS,resourceLevels} from '../../../cockpit/.tmp/compiled/src/resource-plugin.js';
import {tables} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/plugins.js';

const GB=1024**3;
const fill=(text,vars)=>text.replace(/\{(\w+)\}/g,(m,n)=>String(vars?.[n]??m));
const context=(locale,intervalSeconds=5)=>({locale,settings:{intervalSeconds},words:(key,vars)=>{
 assert.ok(tables[locale][key],`missing ${locale} ${key}`);
 return {full:fill(tables[locale][key],vars),short:fill(tables[locale][key+'Short']??tables[locale][key],vars)};
}});
/** One host sample (the ResourcePagePayload shape). */
const BYTES=['memTotal','memApp','memWired','memCompressed','memCached','memFree','swapUsed','diskTotal','diskFree'];
const sample=(t,o={})=>{const s={t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:9.2*GB,memWired:4.5*GB,memCompressed:1.4*GB,memCached:12.8*GB,memFree:4.1*GB,swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB,...o};
 for(const k of BYTES)if(typeof s[k]==='number'&&!(k in o&&!Number.isInteger(o[k])&&o[k]<1000))s[k]=Math.round(s[k]);return s;};
const T0=Date.UTC(2026,10,19,12);

test('D327 the resource plugin is registered, default on, orchid underline and ink, sampling 2/5/10 s (default 5)',()=>{
 const registry=new PluginRegistry(builtinPlugins);
 assert.equal(registry.get('resources'),resourcePlugin);
 assert.equal(RESOURCE_INK,'#da66c2');
 assert.ok(PLUGIN_INKS.includes('#da66c2'));
 assert.equal(resourcePlugin.underline,RESOURCE_INK);assert.equal(resourcePlugin.ink,RESOURCE_INK);
 assert.equal(resourcePlugin.defaultEnabled,true);
 assert.equal(resourcePlugin.hostSampled,true,'drawn only for a host that negotiated plugins (it samples)');
 assert.deepEqual(resourcePlugin.settings,[{key:'intervalSeconds',kind:'seconds',min:2,max:10,default:5}]);
 // White line art in the vendor-mark frame: rounded screen + heartbeat line, currentColor only.
 assert.match(resourcePlugin.icon,/currentColor/);assert.doesNotMatch(resourcePlugin.icon,/#[0-9a-f]{3,6}/i);
 for(const key of [resourcePlugin.title,resourcePlugin.title+'Short',resourcePlugin.summary])assert.ok(tables.en[key]&&tables['zh-CN'][key],key);
});

test('accept: strict sample shape, merged by time, 10-minute window, bounded',()=>{
 const a=resourcePlugin.accept({samples:[sample(T0),sample(T0+5000)]},undefined);
 assert.equal(a.samples.length,2);
 // A repeat of an old sample and a newer one: kept once, in time order.
 const b=resourcePlugin.accept({samples:[sample(T0+5000),sample(T0+10000)]},a);
 assert.deepEqual(b.samples.map(s=>s.t),[T0,T0+5000,T0+10000]);
 // Older than ten minutes before the newest sample: dropped (the page keeps no more than the host's ring buffer).
 const c=resourcePlugin.accept({samples:[sample(T0+RESOURCE_WINDOW_MS+5000)]},b);
 assert.deepEqual(c.samples.map(s=>s.t),[T0+10000,T0+RESOURCE_WINDOW_MS+5000]);
 // The host sends the whole ten minutes when the column starts (300 samples at 2 s); at most 360 per reading.
 const many=Array.from({length:400},(_,i)=>sample(T0+i*2000));
 assert.equal(resourcePlugin.accept({samples:many.slice(0,300)},undefined).samples.length,300);
 assert.equal(resourcePlugin.accept({samples:many.slice(0,360)},undefined).samples.length,300,'still only ten minutes kept');
 assert.equal(resourcePlugin.accept({samples:many},undefined),undefined,'at most 360 samples per reading');
 for(const bad of [null,{},{samples:[]},{samples:[sample(T0)],extra:1},{samples:[{...sample(T0),extra:1}]},
  {samples:[sample(T0,{cpuUser:101})]},{samples:[sample(T0,{cpuUser:80,cpuSystem:30})]},{samples:[sample(T0,{cpuSystem:-1})]},
  {samples:[sample(T0,{memTotal:0})]},{samples:[sample(T0,{memApp:1.5})]},{samples:[sample(T0,{memApp:40*GB})]},
  {samples:[sample(T0,{pressure:'high'})]},{samples:[sample(T0,{diskFree:600*GB})]},{samples:[sample(T0,{t:'now'})]},
  {samples:[sample(T0,{load:Number.NaN})]}])
  assert.equal(resourcePlugin.accept(bad,a),undefined,JSON.stringify(bad));
});

test('D327 column: CPU · memory · disk cells, numbers turn amber/red, memory follows macOS pressure, bottom line = pressure',()=>{
 // No reading: tags only, no "--" (V1-FINAL rule 2).
 const empty=resourcePlugin.column(undefined,context('zh-CN'));
 assert.deepEqual(empty.cells.map(c=>c.tag.full),['CPU','内存','磁盘']);
 assert.ok(empty.cells.every(c=>c.value==null&&c.bar==null));
 assert.equal(empty.foot.label.full,'内存压力');assert.equal(empty.foot.value,null);

 let state;for(let i=0;i<6;i++)state=resourcePlugin.accept({samples:[sample(T0+i*10000,{cpuUser:i===2?58:19,cpuSystem:3})]},state);
 const zh=resourcePlugin.column(state,context('zh-CN'));
 const [cpu,mem,disk]=zh.cells;
 assert.equal(cpu.value,22);assert.equal(cpu.unit,'%');assert.equal(cpu.side.full,'最高 61%');assert.equal(cpu.level,null);
 assert.equal(cpu.bar,.22);assert.equal(cpu.trend.length,6);
 assert.equal(mem.value,47);assert.equal(mem.side.full,'15.1 / 32 GB');assert.equal(mem.level,null);assert.ok(Math.abs(mem.bar-15.1/32)<.001);
 assert.equal(disk.value,76);assert.equal(disk.side.full,'剩 120 GB');assert.equal(disk.level,null);assert.equal(disk.trend,undefined);
 assert.equal(zh.foot.value.full,'正常');
 const en=resourcePlugin.column(state,context('en'));
 assert.deepEqual(en.cells.map(c=>c.tag.full),['CPU','Memory','Disk']);
 assert.equal(en.cells[0].side.full,'peak 61%');assert.equal(en.cells[2].side.full,'120 GB free');assert.equal(en.foot.value.full,'Normal');

 // A 94% memory reading with normal pressure keeps its ink: macOS uses free memory as cache (board section 2).
 const full=resourcePlugin.accept({samples:[sample(T0,{memApp:20.4*GB,memWired:5.2*GB,memCompressed:4.6*GB,memCached:1.2*GB,memFree:.6*GB})]},undefined);
 assert.equal(resourcePlugin.column(full,context('en')).cells[1].value,94);
 assert.equal(resourcePlugin.column(full,context('en')).cells[1].level,null);
 const warn=resourcePlugin.accept({samples:[sample(T0,{pressure:'warn',swapUsed:2.1*GB})]},undefined);
 assert.equal(resourcePlugin.column(warn,context('en')).cells[1].level,'mid');
 assert.equal(resourcePlugin.column(warn,context('zh-CN')).foot.value.full,'偏高 · 交换 2.1 GB');
 const critical=resourcePlugin.accept({samples:[sample(T0,{pressure:'critical'})]},undefined);
 assert.equal(resourcePlugin.column(critical,context('en')).cells[1].level,'low');
 const spike=resourcePlugin.accept({samples:[sample(T0,{cpuUser:71,cpuSystem:25,diskFree:40*GB})]},undefined);
 const s=resourcePlugin.column(spike,context('en')).cells;
 assert.equal(s[0].value,96);assert.equal(s[0].level,'low');assert.equal(s[2].level,'mid');
});

test('D327 levels: CPU amber from 70 %, red from 90 %; memory by pressure only; disk amber from 90 %',()=>{
 assert.deepEqual(resourceLevels({cpu:69.9,pressure:'normal',disk:89.9}),{cpu:null,memory:null,disk:null});
 assert.deepEqual(resourceLevels({cpu:70,pressure:'warn',disk:90}),{cpu:'mid',memory:'mid',disk:'mid'});
 assert.deepEqual(resourceLevels({cpu:90,pressure:'critical',disk:99}),{cpu:'low',memory:'low',disk:'mid'});
});

test('screen (interim lines until the D323 draw hook): CPU, memory with the four kinds, disk, sampling interval',()=>{
 assert.deepEqual(resourcePlugin.screen(undefined,context('en')).lines.map(l=>l.label),['Sampling']);
 let state;for(let i=0;i<3;i++)state=resourcePlugin.accept({samples:[sample(T0+i*10000)]},state);
 const lines=resourcePlugin.screen(state,context('zh-CN',10)).lines;
 assert.deepEqual(lines.map(l=>l.label),['CPU','用户 · 系统','负载','10 分钟最高','内存','内存压力','联动 · App · 压缩','已缓存 · 空闲','磁盘','采样']);
 assert.equal(lines[0].value,'22%');assert.equal(lines[1].value,'19% · 3%');assert.equal(lines[2].value,'2.4');
 assert.equal(lines[4].value,'47% · 15.1 / 32 GB');assert.equal(lines[5].value,'正常');
 assert.equal(lines[6].value,'4.5 · 9.2 · 1.4 GB');assert.equal(lines[7].value,'12.8 · 4.1 GB');
 assert.equal(lines[8].value,'76% · 剩 120 GB');assert.equal(lines[9].value,'每 10 秒');
 assert.ok(lines.length<=12);
});
