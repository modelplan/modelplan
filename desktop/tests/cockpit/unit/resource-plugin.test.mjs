// SPDX-License-Identifier: MIT
// Resource plugin (owner D324, D327): the page side. The host samples (ModelPlanResources ResourceSampler, system calls
// only) and pushes `pluginData` readings; the plugin folds them into a 10-minute in-memory history and describes the
// column (CPU · 内存 · 磁盘 cells) and the big screen. Order CPU · memory · disk everywhere a list is drawn (board 11-20).
import test from 'node:test';
import assert from 'node:assert/strict';
import {PluginRegistry,PLUGIN_INKS,screenShortText,placeholderPlugin} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {calendarPlugin} from '../../../cockpit/.tmp/compiled/src/calendar-plugin.js';
import {builtinPlugins} from '../../../cockpit/.tmp/compiled/src/plugin-builtins.js';
import {resourcePlugin,RESOURCE_INK,RESOURCE_WINDOW_MS,resourceLevels,radarLayout,formatRate,resourceSeries} from '../../../cockpit/.tmp/compiled/src/resource-plugin.js';
import {tables} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/plugins.js';
import {readFileSync} from 'node:fs';

const GB=1024**3;
const fill=(text,vars)=>text.replace(/\{(\w+)\}/g,(m,n)=>String(vars?.[n]??m));
const context=(locale,intervalSeconds=5,memo={})=>({locale,settings:{intervalSeconds},memo,words:(key,vars)=>{
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
 assert.deepEqual(lines.map(l=>l.label),['CPU','用户 · 系统','负载','10 分钟最高','内存','内存压力','联动 · App · 压缩','已缓存 · 空闲','磁盘','网络','采样']);
 assert.equal(lines[0].value,'22%');assert.equal(lines[1].value,'19% · 3%');assert.equal(lines[2].value,'2.4');
 assert.equal(lines[4].value,'47% · 15.1 / 32 GB');assert.equal(lines[5].value,'正常');
 assert.equal(lines[6].value,'4.5 · 9.2 · 1.4 GB');assert.equal(lines[7].value,'12.8 · 4.1 GB');
 assert.equal(lines[8].value,'76% · 剩 120 GB');assert.equal(lines[9].value,'');assert.equal(lines[10].value,'每 10 秒');
 assert.ok(lines.length<=12);
});

/** A tiny SVG DOM (createElementNS, attributes, children, text) so the draw hook runs in node. */
function fakeArea(){
 const make=tag=>({tag,attrs:{},children:[],textContent:'',setAttribute(k,v){this.attrs[k]=String(v);},getAttribute(k){return this.attrs[k]??null;},
  append(...c){this.children.push(...c);},replaceChildren(...c){this.children=c;}});
 const doc={createElementNS:(_ns,tag)=>make(tag)};const area=make('div');area.ownerDocument=doc;return area;
}
const all=(node,pick)=>[...(pick(node)?[node]:[]),...node.children.flatMap(c=>all(c,pick))];
const text=node=>[node.textContent,...node.children.map(text)].join('');
const TOKENS={ink:'var(--lcd-ink)',muted:'var(--lcd-muted)',ghost:'var(--lcd-ghost)',rule:'var(--lcd-rule)',ok:'var(--st-ok)',mid:'var(--st-mid)',low:'var(--st-low)',silk:'var(--silk-hi)',lcdFont:'var(--f-lcd)',silkFont:'var(--f-silk)'};
function drawInto(draw,locale='en',width=190,height=240){
 const area=fakeArea();draw({...context(locale),area,width,height,tokens:TOKENS,memo:{},opening:false,redraw(){}});return area;
}
const history=(n,o=()=>({}))=>{let st;for(let i=0;i<n;i++)st=resourcePlugin.accept({samples:[sample(T0+i*5000,o(i))]},st);return st;};

test('D407 R1 column: every arc (CPU, memory, disk) has a leader line, a label and its own row; network is a text row with no arc',()=>{
 const state=history(6,i=>({netIn:1_200_000+i,netOut:86_000}));
 const col=resourcePlugin.column(state,context('zh-CN'));
 assert.equal(typeof col.draw,'function','the column draws the half-circle radar');
 assert.deepEqual(col.cells.map(c=>c.tag.full),['CPU','内存','磁盘'],'the cells stay as the fallback');
 const area=drawInto(col.draw,'zh-CN');
 const arcs=all(area,n=>n.attrs['data-arc']).map(n=>n.attrs['data-arc']);
 assert.deepEqual(arcs,['cpu','memory','disk'],'outer to inner, CPU · memory · disk');
 for(const id of arcs){
  const leader=all(area,n=>n.attrs['data-leader']===id);assert.equal(leader.length,1,`${id} leader`);
  const row=all(area,n=>n.attrs['data-row']===id);assert.equal(row.length,1,`${id} row`);
  const label=all(row[0],n=>n.attrs['data-label']!==undefined);assert.equal(label.length,1,`${id} label`);
  assert.ok(label[0].textContent.length>0);
  assert.equal(Number(leader[0].attrs.x1),Number(leader[0].attrs.x2),'the leader drops straight down');
  assert.equal(Number(label[0].attrs.x),Number(leader[0].attrs.x1),'the label sits under its leader foot');
  assert.ok(Number(leader[0].attrs.y2)<Number(label[0].attrs.y),'the leader ends above its label');
 }
 assert.deepEqual(all(area,n=>n.attrs['data-label']!==undefined).map(n=>n.textContent),['CPU','内存','磁盘']);
 // Network: one text row, never an arc or a bar.
 const net=all(area,n=>n.attrs['data-row']==='network');assert.equal(net.length,1);
 assert.match(text(net[0]),/网络/);assert.match(text(net[0]),/↓1\.2M/);assert.match(text(net[0]),/↑86K/);
 assert.equal(all(net[0],n=>n.tag==='path'||n.tag==='rect').length,0,'network is text only');
 assert.equal(all(area,n=>n.attrs['data-arc']==='network').length,0);
 // History sparklines for the rows whose data has history; no duplicated bars.
 assert.equal(all(area,n=>n.attrs['data-spark']).length,3);
 assert.equal(all(area,n=>n.tag==='rect'&&n.attrs['data-bar']!==undefined).length,0,'no bars beside the arcs');
 // Radar details: range rings, ticks, bearing marks and one static sweep.
 assert.ok(all(area,n=>n.attrs['data-ring']!==undefined).length>=2);
 assert.ok(all(area,n=>n.attrs['data-tick']!==undefined).length>=10);
 assert.ok(all(area,n=>n.attrs['data-bearing']!==undefined).length>=3);
 assert.equal(all(area,n=>n.attrs['data-sweep']!==undefined).length,1);
});

test('D407 R1 one sample: no sparklines (no history yet); no network field: the network row shows its name only',()=>{
 const state=resourcePlugin.accept({samples:[sample(T0)]},undefined);
 const area=drawInto(resourcePlugin.column(state,context('en')).draw);
 assert.equal(all(area,n=>n.attrs['data-spark']).length,0);
 const net=all(area,n=>n.attrs['data-row']==='network');assert.equal(net.length,1);
 assert.equal(text(net[0]).trim(),'Network');assert.doesNotMatch(text(net[0]),/--/);
});

test('D407 R1 arcs take the status colour by level (normal / amber / red), tracks stay ghost',()=>{
 const state=resourcePlugin.accept({samples:[sample(T0,{cpuUser:71,cpuSystem:25,pressure:'warn',diskFree:200*GB})]},undefined);
 const area=drawInto(resourcePlugin.column(state,context('en')).draw);
 const stroke=id=>all(area,n=>n.attrs['data-arc']===id)[0].attrs.stroke;
 assert.equal(stroke('cpu'),TOKENS.low);assert.equal(stroke('memory'),TOKENS.mid);assert.equal(stroke('disk'),TOKENS.ok);
});

test('D407 R1 the radar fills the whole area: the network row sits at the bottom whatever the height',()=>{
 const state=history(10);
 for(const [w,h] of [[150,160],[190,240],[190,420],[420,300]]){
  const L=radarLayout(w,h,true);
  assert.ok(L.cy<h&&L.cy-L.scale-5>=0,`radar inside ${w}×${h}`);
  assert.ok(L.cx+L.scale<=w&&L.cx-L.scale>=0,`radar inside width ${w}`);
  assert.ok(h-L.netY<=12,`network row at the bottom of ${h}`);
  assert.ok(L.rows.every((r,i)=>i===0||r>L.rows[i-1]));
  assert.ok(L.rows[0]>L.cy,'rows below the radar');
  const area=drawInto(resourcePlugin.column(state,context('en')).draw,'en',w,h);
  assert.ok(all(area,n=>n.attrs['data-row']).length===4);
 }
});

test('D397 R1 draws once per reading: no animation frame, interval or timer, no SVG animation',()=>{
 const src=readFileSync(new URL('../../../cockpit/src/resource-plugin.ts',import.meta.url),'utf8');
 assert.doesNotMatch(src,/requestAnimationFrame|setInterval|setTimeout|\.animate\(|<animate|'animate|@keyframes|transition/);
 const saved={raf:globalThis.requestAnimationFrame,si:globalThis.setInterval,st:globalThis.setTimeout};
 const calls=[];globalThis.requestAnimationFrame=()=>calls.push('raf');globalThis.setInterval=()=>calls.push('interval');globalThis.setTimeout=()=>calls.push('timeout');
 try{
  const state=history(5);
  const area=drawInto(resourcePlugin.column(state,context('en')).draw);drawInto(resourcePlugin.screen(state,context('en')).draw,'en',362,213);
  assert.deepEqual(calls,[]);
  assert.equal(all(area,n=>/^animate/.test(n.tag)).length,0);
 }finally{globalThis.requestAnimationFrame=saved.raf;globalThis.setInterval=saved.si;globalThis.setTimeout=saved.st;}
});

test('D413 big screen B: four cards (CPU, memory, disk, network), each with lamp, name, value, 峰/均, detail and a thin-line history; no radar',()=>{
 const state=history(30,i=>({cpuUser:i===12?80:15,cpuSystem:5,netIn:5_400+i*100,netOut:120}));
 const screen=resourcePlugin.screen(state,context('zh-CN'));
 assert.equal(typeof screen.draw,'function');assert.ok(screen.lines.length>=10,'lines stay for a failed draw');
 assert.ok(screen.lines.some(l=>l.label==='网络'));
 const area=drawInto(screen.draw,'zh-CN',362,213);
 assert.equal(all(area,n=>n.attrs['data-arc']).length,0,'no second radar on the big screen');
 const cards=all(area,n=>n.attrs['data-card']);
 assert.deepEqual(cards.map(c=>c.attrs['data-card']),['cpu','memory','disk','network']);
 for(const card of cards){
  for(const part of ['data-lamp','data-name','data-value','data-pv','data-line','data-now','data-peak','data-avg'])
   assert.equal(all(card,n=>n.attrs[part]!==undefined).length,1,`${card.attrs['data-card']} ${part}`);
  assert.ok(all(card,n=>n.attrs['data-ring']!==undefined).length>=2&&all(card,n=>n.attrs['data-bearing']!==undefined).length>=4,'grid rings and bearings');
  assert.equal(all(card,n=>n.attrs['data-sweep']!==undefined).length,1,'one still sweep');
 }
 const net=cards[3];assert.equal(all(net,n=>n.attrs['data-threshold']).length,0,'network has no 80/90 marks');
 assert.equal(all(net,n=>n.attrs['data-line-up']!==undefined).length,1,'upload is the dotted line');
 for(const card of cards.slice(0,3))assert.deepEqual(all(card,n=>n.attrs['data-threshold']).map(n=>n.attrs['data-threshold']),['80','90']);
 // The line is white below 80 %, amber 80–90 %, red above 90 % (three clipped strokes); the big number white until 80 %.
 const cpu=cards[0];assert.equal(all(cpu,n=>n.attrs['data-line-mid']!==undefined).length,1);assert.equal(all(cpu,n=>n.attrs['data-line-low']!==undefined).length,1);
 assert.equal(all(cpu,n=>n.attrs['data-value']!==undefined)[0].attrs.fill,'#e9edf0');
 assert.match(text(all(area,n=>n.attrs['data-head']!==undefined)[0]),/资源 · 最近 10 分钟/);
 // Times under the bottom row only.
 assert.equal(all(cards[0],n=>n.attrs['data-tick']!==undefined).length,0);assert.equal(all(cards[2],n=>n.attrs['data-tick']!==undefined).length,11);
});

test('D413 the 10 min | 1 h toggle switches the series: raw readings, or one point a minute with the raw peak kept',()=>{
 const minute=60_000,t0=Math.ceil(T0/minute)*minute;
 // The host's hour: 50 folded minutes, one with a 96 % spike that its mean (30 %) hides.
 const minutes=Array.from({length:50},(_,i)=>({t:t0+i*minute,cpu:i===20?30:20,cpuPeak:i===20?96:25,memory:47,memoryPeak:48,disk:76,diskPeak:76}));
 const samples=Array.from({length:120},(_,i)=>sample(t0+50*minute+i*5000,{netIn:1000,netOut:10}));
 const state=resourcePlugin.accept({samples,minutes},undefined);
 assert.equal(state.minutes.length,50);
 const ten=resourceSeries(state,'10m'),hour=resourceSeries(state,'1h');
 assert.equal(ten.points.cpu.length,120,'10 min: every raw reading');
 assert.equal(hour.points.cpu.length,60,'1 h: 50 host minutes + 10 of the page\'s own');
 assert.equal(hour.peak.cpu,96,'the peak keeps the raw reading');
 assert.ok(Math.max(...hour.points.cpu.map(p=>p.v))<40,'the line draws the minute means');
 assert.equal(ten.end-ten.start,10*minute);assert.equal(hour.end-hour.start,60*minute);
 // The screen follows the view memory; the toggle offers the two ranges, the current one picked.
 const memo={};
 const s10=resourcePlugin.screen(state,context('zh-CN',5,memo));
 assert.deepEqual(s10.toggle.options.map(o=>o.label.full),['10分钟','1小时']);assert.equal(s10.toggle.value,'10m');assert.equal(s10.toggle.key,'range');
 memo.range='1h';
 const s60=resourcePlugin.screen(state,context('zh-CN',5,memo));assert.equal(s60.toggle.value,'1h');
 const area=drawInto(s60.draw,'zh-CN',362,213);
 assert.equal(all(area,n=>n.attrs['data-range']==='1h').length,1);
 assert.match(text(all(area,n=>n.attrs['data-head']!==undefined)[0]),/最近 1 小时/);
 const line=all(area,n=>n.attrs['data-card']==='cpu')[0];
 assert.equal((all(line,n=>n.attrs['data-line']!==undefined)[0].attrs.d.match(/L/g)??[]).length,59,'60 points');
 assert.equal(all(area,n=>n.attrs['data-card']==='disk')[0].children.filter(n=>n.tag==='text').map(n=>n.textContent).slice(-3).join(' '),'−60 分 −30 现在');
 // Bad minutes refuse the whole reading.
 for(const bad of [{...minutes[0],t:t0+1},{...minutes[0],cpu:101},{...minutes[0],extra:1},{...minutes[0],netIn:5}])
  assert.equal(resourcePlugin.accept({samples,minutes:[bad]},undefined),undefined,JSON.stringify(bad));
 assert.equal(resourcePlugin.accept({samples,minutes:Array.from({length:61},(_,i)=>({...minutes[0],t:t0+i*minute}))},undefined),undefined);
 // D413 fix: a full hour from the host (60 closed minutes) plus the open minute's raw readings: 61 points, and the
 // oldest one's minute holds the window's start, so the view covers the whole hour.
 const full=Array.from({length:60},(_,i)=>({t:t0+i*minute,cpu:20,cpuPeak:i===0?88:25,memory:47,memoryPeak:48,disk:76,diskPeak:76}));
 const open=Array.from({length:6},(_,i)=>sample(t0+60*minute+20_000+i*5000));
 const fullState=resourcePlugin.accept({samples:open,minutes:full},undefined),fullHour=resourceSeries(fullState,'1h');
 assert.equal(fullHour.points.cpu.length,61,'60 closed minutes + the open one');
 assert.ok(fullHour.points.cpu[0].t-minute/2<=fullHour.start,'the oldest minute starts at or before the window');
 assert.equal(fullHour.peak.cpu,88,'the oldest minute\'s raw peak is still in the hour');
 // Minutes persist across later readings that carry none.
 assert.equal(resourcePlugin.accept({samples:[sample(t0+61*minute)]},state).minutes.length,50);
});

test('D413 switch short names: two characters in Chinese, at most four letters in English, else the icon alone',()=>{
 assert.equal(screenShortText('资源','zh-CN'),'资源');assert.equal(screenShortText('资源占用','zh-CN'),null);assert.equal(screenShortText('日','zh-CN'),null);
 assert.equal(screenShortText('Sys','en'),'Sys');assert.equal(screenShortText('Cal','en'),'Cal');assert.equal(screenShortText('HUD','en'),'HUD');
 assert.equal(screenShortText('Resources','en'),null);assert.equal(screenShortText('Holder','en'),null);assert.equal(screenShortText(undefined,'en'),null);
 const word=(locale,key)=>tables[locale][key];
 assert.equal(screenShortText(word('zh-CN',resourcePlugin.screenShort),'zh-CN'),'资源');assert.equal(screenShortText(word('en',resourcePlugin.screenShort),'en'),'Sys');
 assert.equal(screenShortText(word('zh-CN',calendarPlugin.screenShort),'zh-CN'),'日历');assert.equal(screenShortText(word('en',calendarPlugin.screenShort),'en'),'Cal');
 assert.equal(placeholderPlugin.screenShort,undefined,'no short name: icon only');
});

test('accept: the optional network rates (bytes per second) come as a pair',()=>{
 assert.ok(resourcePlugin.accept({samples:[sample(T0,{netIn:10,netOut:20})]},undefined));
 for(const bad of [{netIn:10},{netOut:20},{netIn:-1,netOut:0},{netIn:1.5,netOut:0},{netIn:'1',netOut:0}])
  assert.equal(resourcePlugin.accept({samples:[sample(T0,bad)]},undefined),undefined,JSON.stringify(bad));
 assert.equal(formatRate(0),'0B');assert.equal(formatRate(999),'999B');assert.equal(formatRate(86_000),'86K');assert.equal(formatRate(1_234_567),'1.2M');assert.equal(formatRate(2_500_000_000),'2.5G');
});

// ---- PR #1225 round 2: the big screen's header never overlaps, and the network card never shows a blank graph.
// PATHS (header + panels that can overflow or show blank), each pinned below:
//  H1 head left vs pressure/load right: EN, zh, at 362 and 300 wide, with swap text in the pressure words
//  C1 card name vs detail (CPU, memory, disk, network), both locales        C2 card big value vs 峰/均 pair
//  N1 network card with no net readings -> explicit empty state, no line     N2 network card with readings -> no empty state
const est=(t,size)=>[...t].reduce((n,ch)=>n+(/[⺀-￯]/.test(ch)?1:0.62),0)*size;
const span=n=>{const size=Number(n.attrs['font-size']),w=est(text(n),size),x=Number(n.attrs.x),a=n.attrs['text-anchor'];return a==='end'?[x-w,x]:a==='middle'?[x-w/2,x+w/2]:[x,x+w];};
const head=area=>all(area,n=>n.attrs['data-head']!==undefined)[0];
const topRight=area=>all(area,n=>n.tag==='text'&&n.attrs['text-anchor']==='end'&&Number(n.attrs.y)===17)[0];
for(const [locale,width,o] of [['en',362,{}],['en',362,{pressure:'warn',swapUsed:3*GB}],['en',300,{pressure:'critical',swapUsed:3*GB}],['zh-CN',362,{pressure:'warn',swapUsed:3*GB}],['zh-CN',300,{}]])
 test(`H1 the big screen's header never overlaps its pressure and load (${locale}, ${width} px, ${JSON.stringify(o)})`,()=>{
  const state=history(30,()=>({netIn:5000,netOut:100,...o}));
  const area=drawInto(resourcePlugin.screen(state,context(locale)).draw,locale,width,213);
  const [,hr]=span(head(area)),[rl,rr]=span(topRight(area));
  assert.ok(hr+6<=rl,`head ends ${hr.toFixed(1)}, right text starts ${rl.toFixed(1)}`);
  assert.ok(rr<=width-4,'the right text stays inside the draw area');
  assert.match(text(topRight(area)),locale==='en'?/Normal|Elevated|High|Critical|Pressure/:/正常|偏高|严重|压力/,'the pressure value is still said');
 });
for(const locale of ['en','zh-CN'])
 test(`C1/C2 no card text overlaps another in a card (${locale})`,()=>{
  const state=history(30,i=>({cpuUser:i===12?80:15,netIn:5_400_000,netOut:1_200_000}));
  const area=drawInto(resourcePlugin.screen(state,context(locale)).draw,locale,362,213);
  for(const card of all(area,n=>n.attrs['data-card'])){
   const pick=a=>all(card,n=>n.attrs[a]!==undefined)[0],name=pick('data-name'),det=pick('data-detail'),val=pick('data-value'),pv=pick('data-pv');
   if(det)assert.ok(span(name)[1]+4<=span(det)[0],`${card.attrs['data-card']} name vs detail`);
   if(val&&pv){const vr=Number(val.attrs.x)+est(val.textContent,16)+val.children.reduce((n,k)=>n+est(text(k),Number(k.attrs['font-size'])),0);assert.ok(vr+4<=span(pv)[0],`${card.attrs['data-card']} value vs peak/avg`);}
  }
 });
test('N1 the network card with no readings says so, explicitly, instead of drawing a blank graph',()=>{
 for(const [locale,words] of [['en','No network data yet'],['zh-CN','暂无网络数据']]){
  const state=history(30);// the host sends no rates (first read primes the counters)
  const area=drawInto(resourcePlugin.screen(state,context(locale)).draw,locale,362,213);
  const net=all(area,n=>n.attrs['data-card']==='network')[0];
  const empty=all(net,n=>n.attrs['data-empty']!==undefined);
  assert.equal(empty.length,1,'one explicit empty state');assert.equal(text(empty[0]),words);assert.equal(empty[0].attrs['text-anchor'],'middle');
  assert.equal(all(net,n=>n.attrs['data-line']!==undefined).length,0);
  assert.equal(all(net,n=>n.attrs['data-sweep']!==undefined).length,0,'no still sweep over nothing');
  const cpu=all(area,n=>n.attrs['data-card']==='cpu')[0];assert.equal(all(cpu,n=>n.attrs['data-empty']!==undefined).length,0,'the other cards have data');
 }
});
test('N2 with network readings there is no empty state (the page accepts the rates only as a pair, so one direction cannot reach the card)',()=>{
 const has=state=>all(drawInto(resourcePlugin.screen(state,context('en')).draw,'en',362,213),n=>n.attrs['data-empty']!==undefined).length;
 assert.equal(has(history(30,()=>({netIn:5000,netOut:100}))),0);
});

// macrevb-1225-5. Invariant: the Network card shows the empty state ONLY when the selected range has no network
// samples; one sample without the rate pair (a counter reset on the Mac) never blanks a graph that has data.
// PATHS (a missing rate reaching the card): native reader (counter decrease / first read / unreadable -> no pair, series kept;
//  SystemResourceReaderTests), bridge (payload sends the pair or nothing; ResourcePageFeed passes it on), page accept (14 or 16 keys),
//  P1 latest sample without rates, P2 gap in the middle, P3 the 1 h range (host minutes with and without net), P4 the column text row.
for(const [name,gap] of [['P1 the latest sample has no rates',i=>i===29],['P2 a sample in the middle has no rates',i=>i===15]])
 test(`N4 ${name}: the graph, the value and peak/avg stay`,()=>{
  const state=history(30,i=>gap(i)?{}:{netIn:5_400_000,netOut:120_000});
  const area=drawInto(resourcePlugin.screen(state,context('en')).draw,'en',362,213);
  const net=all(area,n=>n.attrs['data-card']==='network')[0];
  assert.equal(all(net,n=>n.attrs['data-empty']!==undefined).length,0,'no empty state while the range has data');
  assert.equal(all(net,n=>n.attrs['data-line']!==undefined).length,1);assert.equal(all(net,n=>n.attrs['data-value']!==undefined).length,1);
  assert.match(text(all(net,n=>n.attrs['data-value']!==undefined)[0]),/5\.4MB\/s|5\.4/,'the last known rate');
 });
test('N5 1 h range: host minutes with a rate keep the graph although the page has no rate now; none at all gives the empty state',()=>{
 const minute=60_000,t0=Math.ceil(T0/minute)*minute;
 const mins=net=>Array.from({length:50},(_,i)=>({t:t0+i*minute,cpu:20,cpuPeak:25,memory:47,memoryPeak:48,disk:76,diskPeak:76,...(net?{netIn:1000,netInPeak:2000,netOut:10,netOutPeak:20}:{})}));
 const samples=Array.from({length:12},(_,i)=>sample(t0+50*minute+i*5000));
 for(const [net,expected] of [[true,0],[false,1]]){
  const state=resourcePlugin.accept({samples,minutes:mins(net)},undefined);
  const area=drawInto(resourcePlugin.screen(state,context('en',5,{range:'1h'})).draw,'en',362,213);
  assert.equal(all(area,n=>n.attrs['data-card']==='network')[0].children.filter(n=>n.attrs['data-empty']!==undefined).length,expected);
 }
});
test('N6 the column text row keeps the last known rate when the latest tick had none',()=>{
 const state=history(6,i=>i===5?{}:{netIn:1_200_000,netOut:86_000});
 const area=drawInto(resourcePlugin.column(state,context('en')).draw);
 assert.match(text(all(area,n=>n.attrs['data-row']==='network')[0]),/1\.2M/);
});
