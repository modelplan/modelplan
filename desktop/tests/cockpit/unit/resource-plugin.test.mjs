// SPDX-License-Identifier: MIT
// Resource plugin (owner D324, D327): the page side. The host samples (ModelPlanResources ResourceSampler, system calls
// only) and pushes `pluginData` readings; the plugin folds them into a 10-minute in-memory history and describes the
// column (CPU · 内存 · 磁盘 cells) and the big screen. Order CPU · memory · disk everywhere a list is drawn (board 11-20).
import test from 'node:test';
import assert from 'node:assert/strict';
import {PluginRegistry,PLUGIN_INKS} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {builtinPlugins} from '../../../cockpit/.tmp/compiled/src/plugin-builtins.js';
import {resourcePlugin,RESOURCE_INK,RESOURCE_WINDOW_MS,resourceLevels,chartData} from '../../../cockpit/.tmp/compiled/src/resource-plugin.js';
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
 assert.deepEqual(resourcePlugin.settings,[{key:'intervalSeconds',kind:'seconds',min:2,max:10,default:5,choices:[2,5,10]}]);
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

 // D371 B4c: a 94% memory reading is red by percentage even at normal pressure (status colour, same family as the quota rings).
 const full=resourcePlugin.accept({samples:[sample(T0,{memApp:20.4*GB,memWired:5.2*GB,memCompressed:4.6*GB,memCached:1.2*GB,memFree:.6*GB})]},undefined);
 assert.equal(resourcePlugin.column(full,context('en')).cells[1].value,94);
 assert.equal(resourcePlugin.column(full,context('en')).cells[1].level,'low');
 const warn=resourcePlugin.accept({samples:[sample(T0,{pressure:'warn',swapUsed:2.1*GB})]},undefined);
 assert.equal(resourcePlugin.column(warn,context('en')).cells[1].level,'mid');
 assert.equal(resourcePlugin.column(warn,context('zh-CN')).foot.value.full,'偏高 · 交换 2.1 GB');
 const critical=resourcePlugin.accept({samples:[sample(T0,{pressure:'critical'})]},undefined);
 assert.equal(resourcePlugin.column(critical,context('en')).cells[1].level,'low');
 const spike=resourcePlugin.accept({samples:[sample(T0,{cpuUser:71,cpuSystem:25,diskFree:40*GB})]},undefined);
 const s=resourcePlugin.column(spike,context('en')).cells;
 assert.equal(s[0].value,96);assert.equal(s[0].level,'low');assert.equal(s[2].level,'low');
});

test('D371 B4c levels: one status colour by percentage, amber from 80 %, red from 90 %, 3 % hysteresis; memory also follows pressure',()=>{
 assert.deepEqual(resourceLevels({cpu:79.9,pressure:'normal',disk:79}),{cpu:null,memory:null,disk:null});
 assert.deepEqual(resourceLevels({cpu:80,pressure:'normal',disk:89.9},undefined),{cpu:'mid',memory:null,disk:'mid'});
 assert.deepEqual(resourceLevels({cpu:90,pressure:'warn',disk:99}),{cpu:'low',memory:'mid',disk:'low'});
 assert.equal(resourceLevels({cpu:10,pressure:'critical',disk:10}).memory,'low');
 // Hysteresis: a level is left only 3 points below its threshold.
 const at=(cpu,prev)=>resourceLevels({cpu,pressure:'normal',disk:0},{cpu:prev,memory:null,disk:null}).cpu;
 assert.equal(at(78,'mid'),'mid');assert.equal(at(76.9,'mid'),null);
 assert.equal(at(88,'low'),'low');assert.equal(at(86.9,'low'),'mid');assert.equal(at(70,'low'),null);
 assert.equal(at(85,null),'mid','entering needs the plain threshold');
});

test('D371 B4c the column carries the level through its sample history, so a flicker at the border keeps the colour',()=>{
 const cpu=(...v)=>{let st;v.forEach((x,i)=>{st=resourcePlugin.accept({samples:[sample(T0+i*5000,{cpuUser:x,cpuSystem:0})]},st);});return resourcePlugin.column(st,context('en')).cells[0];};
 assert.equal(cpu(60,81,78).level,'mid');assert.equal(cpu(60,81,76).level,null);assert.equal(cpu(60,78).level,null);
 assert.equal(cpu(10,20).tone,true,'bars take the status tone');
});

test('D371 the Resources key icon has no small square frame',()=>{
 assert.doesNotMatch(resourcePlugin.icon,/<rect/);
});

test('screen lines (the draw fallback): CPU, memory with the four kinds, disk, sampling interval',()=>{
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

test('D323 big screen draws charts through the draw hook and keeps its lines as the fallback',()=>{
 const state=resourcePlugin.accept({samples:[sample(T0)]},undefined);
 const screen=resourcePlugin.screen(state,context('en'));
 assert.equal(typeof screen.draw,'function');assert.ok(screen.lines.length>=10,'lines stay for a failed draw');
 assert.equal(typeof resourcePlugin.column(state,context('en')).draw,'undefined','the column keeps its cells');
});

test('chartData: memory 10-minute used/cached fractions, pressure strip, CPU 10-second bars, disk bar',()=>{
 const samples=Array.from({length:120},(_,i)=>sample(T0+i*5000,{cpuUser:10+(i%3),cpuSystem:5,pressure:i>=100?'warn':'normal',memApp:(8+i/40)*GB}));
 const state=resourcePlugin.accept({samples},undefined);
 const d=chartData(state.samples);
 assert.equal(d.memory.length,state.samples.length);
 const last=d.memory[d.memory.length-1],s=state.samples[state.samples.length-1];
 assert.ok(Math.abs(last.used-(s.memApp+s.memWired+s.memCompressed)/s.memTotal)<1e-9);
 assert.ok(Math.abs(last.cached-s.memCached/s.memTotal)<1e-9);
 assert.ok(d.memory.every(p=>p.used+p.cached<=1.0001),'stack never exceeds the whole');
 // Pressure strip: 60 ten-second cells, worst pressure in each cell, oldest first.
 assert.equal(d.strip.length,60);assert.equal(d.strip[0],'normal');assert.equal(d.strip[59],'warn');
 // CPU: one bar per 10 s (mean of the samples inside it), user and system stacked, at most 60 bars.
 assert.equal(d.cpu.length,60);
 for(const b of d.cpu){assert.ok(b.user>=0&&b.system>=0&&b.user+b.system<=100.0001);}
 assert.equal(d.cpuLine,80);assert.equal('diskNotch' in d,false);
 assert.ok(Math.abs(d.disk-(494-120)/494*100)<1e-6);
 assert.deepEqual(chartData([]),{memory:[],strip:[],cpu:[],disk:0,cpuLine:80});
});
