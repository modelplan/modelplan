// SPDX-License-Identifier: MIT
// Resource plugin (owner D324, D327) on the real cockpit through the normal bridge: the column (CPU · 内存 · 磁盘 cells,
// orchid dashed key underline, numbers amber/red only), the lifecycle report the host samples by, and the big screen
// (charts on the D323 draw hook). The host side (sampling cadence, ring buffer) is ModelPlanResources.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const GB=1024**3;
const reading=(t,o={})=>{const s={t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:9.2*GB,memWired:4.5*GB,memCompressed:1.4*GB,memCached:12.8*GB,memFree:4.1*GB,swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB,...o};
 for(const k of Object.keys(s))if(k.startsWith('mem')||k.startsWith('disk')||k==='swapUsed')s[k]=Math.round(s[k]);return s;};
const T0=Date.UTC(2026,10,19,12);
/** Two connected subscriptions: the resource column takes the third slot (CKP-PLG-52). */
function data2(rows=2) {const data=sample();data.projection.rows=data.projection.rows.slice(0,rows);return data;}
async function open(page,{plugins={version:1,entries:[],settings:{}},locale='en',rows=2}={}) {
 await page.clock.setFixedTime(new Date('2026-11-19T12:00:00Z'));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(plugins)expect(await receive(send('plugins',{plugins}))).toBe(true);
 expect(await receive(send('display',{data:data2(rows)}))).toBe(true);
 return {send,receive,push:samples=>receive(send('pluginData',{id:'resources',data:{samples}}))};
}
const CAL_OFF={id:'calendar',enabled:false,pinned:false};
const column=page=>page.locator('.eng-cols .pl-col[data-plugin="resources"]');
const key=page=>page.locator('.eng-keys .pl-key[data-plugin="resources"]');
const running=page=>page.evaluate(()=>window.__events.filter(e=>e.type==='action'&&e.action==='pluginsRunning').map(e=>e.ids));

test('D324 default on, drawn only for a host that sent plugin state; the column runs while shown',async({page})=>{
 // A host that never negotiated plugins cannot sample: no resource column, the v1 table with its "+" slot.
 const first=await open(page,{plugins:null});
 await expect(column(page)).toHaveCount(0);
 await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(1);
 // The host sends its plugin state without a resources entry: the default-on resource plugin takes the free slot and
 // starts running (the calendar, also default on, is kept off here so the running set is the resource plugin's alone).
 expect(await first.receive(first.send('plugins',{plugins:{version:1,entries:[CAL_OFF],settings:{}}}))).toBe(true);
 expect(await first.receive(first.send('display',{data:data2()}))).toBe(true);
 await expect(column(page)).toHaveCount(1);
 await expect(column(page)).toHaveAttribute('data-running','true');
 expect((await running(page)).at(-1)).toEqual(['resources']);
 // Hidden cockpit: it stops (the host then falls back to the widget / hidden cadence).
 expect(await first.receive(first.send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','false');
 expect((await running(page)).at(-1)).toEqual([]);
 // Turned off: nothing runs and nothing is drawn.
 expect(await first.receive(first.send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await first.receive(first.send('plugins',{plugins:{version:1,entries:[CAL_OFF,{id:'resources',enabled:false,pinned:false}],settings:{}}}))).toBe(true);
 await expect(column(page)).toHaveCount(0);
 expect((await running(page)).at(-1)).toEqual([]);
});

test('D327 the key: white line icon, orchid dashed underline; the cells read CPU · Memory · Disk',async({page})=>{
 const {push}=await open(page);
 const look=await page.evaluate(()=>{const k=document.querySelector('.eng-keys .pl-key[data-plugin="resources"]');const bl=k.querySelector('.bl');
  return {underline:bl.style.getPropertyValue('--v'),image:getComputedStyle(bl).backgroundImage,icon:!!k.querySelector('.lamp svg path'),name:k.querySelector('.ek-name').textContent};});
 expect(look.underline).toBe('#da66c2');expect(look.image).toContain('repeating-linear-gradient');expect(look.icon).toBe(true);expect(look.name).toBe('Resources');
 // Before the first reading: tags only, never "--".
 await expect(column(page).locator('.pl-tag')).toHaveText(['CPU','Memory','Disk']);
 await expect(column(page).locator('.qvalue')).toHaveCount(0);
 await expect(column(page)).not.toContainText('--');
 expect(await push([reading(T0),reading(T0+5000,{cpuUser:58})])).toBe(true);
 expect(await push([reading(T0+10000)])).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveText(['22','47','76']);
 // D371 Q5: a side value gives way in a narrow column (short, then hidden), so the full words are read from the cell's label.
 await expect(column(page).locator('.pl-cell[data-row="0"]')).toHaveAttribute('aria-label',/peak 61%/);
 await expect(column(page).locator('.pl-cell[data-row="1"]')).toHaveAttribute('aria-label',/15\.1 \/ 32 GB/);
 await expect(column(page).locator('.pl-cell[data-row="2"]')).toHaveAttribute('aria-label',/120 GB free/);
 await expect(column(page).locator('.pl-foot')).toContainText('Normal');
 // The plugin ink is the key underline and the --pl-ink token; the bars take the status colour (D371). The disk has no trend line.
 const ink=await page.evaluate(()=>{const col=document.querySelector('.pl-col[data-plugin="resources"]');return {ink:col.style.getPropertyValue('--pl-ink'),trends:col.querySelectorAll('.pl-trend').length,fills:[...col.querySelectorAll('.pl-bar i')].map(i=>i.style.width)};});
 expect(ink.ink).toBe('#da66c2');expect(ink.trends).toBe(2);expect(ink.fills).toEqual(['22%','47.2%','75.7%']);
 await expect(column(page).locator('.pl-cell.pl-mid, .pl-cell.pl-low')).toHaveCount(0);
});

test('D371 B4c status colour: bars and numbers are normal / amber / red by resource state, never the plugin orchid',async({page})=>{
 const {push}=await open(page,{locale:'zh-CN'});
 const paint=()=>page.evaluate(()=>{const col=document.querySelector('.pl-col[data-plugin="resources"]');
  return {numbers:[...col.querySelectorAll('.qnum')].map(n=>getComputedStyle(n).color),bars:[...col.querySelectorAll('.pl-bar i')].map(i=>getComputedStyle(i).backgroundColor),
   trends:[...col.querySelectorAll('.pl-trend path')].map(p=>getComputedStyle(p).stroke)};});
 // Normal: CPU 22 %, memory 47 %, disk 76 %: one normal colour on all three bars, not the orchid.
 expect(await push([reading(T0),reading(T0+5000)])).toBe(true);
 await expect(column(page).locator('.pl-cell.pl-mid, .pl-cell.pl-low')).toHaveCount(0);
 const normal=await paint();
 expect(new Set(normal.bars).size).toBe(1);expect(normal.bars[0]).not.toBe('rgb(218, 102, 194)');
 // CPU 96 % red, memory warn pressure amber, disk 92 % red.
 expect(await push([reading(T0+10000,{cpuUser:71,cpuSystem:25,pressure:'warn',swapUsed:2.1*GB,diskFree:40*GB})])).toBe(true);
 await expect(column(page).locator('.pl-cell[data-row="0"]')).toHaveClass(/pl-low/);
 await expect(column(page).locator('.pl-cell[data-row="1"]')).toHaveClass(/pl-mid/);
 await expect(column(page).locator('.pl-cell[data-row="2"]')).toHaveClass(/pl-low/);
 await expect(column(page).locator('.pl-foot')).toContainText('偏高');
 const hot=await paint();
 expect(new Set(hot.bars).size).toBe(2);expect(hot.bars).not.toContain(normal.bars[0]);
 expect(hot.bars[0]).toBe(hot.numbers[0]);expect(hot.bars[1]).toBe(hot.numbers[1]);expect(hot.bars[2]).toBe(hot.numbers[2]);
 expect(hot.bars[0]).toBe(hot.bars[2]);// red is red
 expect(new Set(hot.trends).size).toBe(1);expect(hot.trends[0]).not.toBe(hot.bars[0]);// the trend is one neutral 1 px line inside the track
 // Back to normal pressure, a 94 % memory reading is red by percentage (it was ink-only before D371).
 expect(await push([reading(T0+15000,{memApp:20.4*GB,memWired:5.2*GB,memCompressed:4.6*GB,memCached:1.2*GB,memFree:.6*GB})])).toBe(true);
 await expect(column(page).locator('.pl-cell[data-row="1"] .qvalue')).toHaveText('94');
 await expect(column(page).locator('.pl-cell[data-row="1"]')).toHaveClass(/pl-low/);
 // A refused reading changes nothing.
 expect(await push([{...reading(T0+20000),cpuUser:200}])).toBe(false);
 await expect(column(page).locator('.pl-cell[data-row="1"] .qvalue')).toHaveText('94');
});

test('D371 the Resources tab icon has no small square frame (the Calendar icon is unchanged)',async({page})=>{
 await open(page);
 const frames=await page.evaluate(()=>{const k=document.querySelector('.eng-keys .pl-key[data-plugin="resources"]');return [k.querySelectorAll('.lamp svg rect').length,k.querySelectorAll('.lamp svg').length];});
 expect(frames).toEqual([0,1]);
});

test('the big screen: charts on the draw hook, redrawn by readings, closed by Escape',async({page})=>{
 const {push}=await open(page,{plugins:{version:1,entries:[],settings:{resources:{intervalSeconds:10}}}});
 expect(await push(Array.from({length:60},(_,i)=>reading(T0+i*10000,{cpuUser:10+i%40,pressure:i>50?'warn':'normal'})))).toBe(true);
 await key(page).click();
 const screen=page.locator('.mfd-screen .pl-screen[data-plugin="resources"]');
 await expect(screen).toBeVisible();
 await expect(screen).toHaveAttribute('data-draw','custom');
 const chart=screen.locator('.pl-draw-chart');
 await expect(chart.locator('[data-chart="memory-used"]')).toHaveCount(1);
 await expect(chart.locator('[data-chart="memory-cached"]')).toHaveCount(1);
 await expect(chart.locator('[data-chart="pressure"] rect')).toHaveCount(60);
 await expect(chart.locator('[data-chart="cpu"] [data-bar]')).toHaveCount(60);
 await expect(chart.locator('[data-chart="cpu-line"]')).toHaveCount(1);
 await expect(chart.locator('[data-chart="disk-notch"]')).toHaveCount(1);
 // D347: the charts read CPU, Memory, Disk top to bottom (as the column), and all three sit inside the panel.
 const boxes=await page.evaluate(()=>{const r=s=>document.querySelector(s).getBoundingClientRect(),panel=r('.dk-mfd .mfd-screen');
  return {panel:{top:panel.top,bottom:panel.bottom},cpu:r('[data-chart="cpu"]').top,memory:r('[data-chart="memory-used"]').top,disk:r('[data-chart="disk"]'),
   labels:[...document.querySelectorAll('.pl-draw-chart text:not([data-readout])')].map(t=>t.textContent)};});
 expect(boxes.labels).toEqual(['CPU','Memory','Disk']);
 expect(boxes.cpu).toBeLessThan(boxes.memory);expect(boxes.memory).toBeLessThan(boxes.disk.top);
 expect(boxes.disk.bottom).toBeLessThanOrEqual(boxes.panel.bottom+.5);expect(boxes.disk.top).toBeGreaterThanOrEqual(boxes.panel.top-.5);
 // macrevb-1096-1: the load, the memory breakdown and the disk capacity are visible beside the charts.
 const readouts=await page.locator('.pl-draw-chart text[data-readout]').allTextContents();
 expect(readouts.length).toBe(4);
 expect(readouts[0]).toMatch(/Load 2\.4/);expect(readouts[0]).toMatch(/User · system/);
 expect(readouts[1]).toMatch(/GB/);expect(readouts[2]).toMatch(/Wired · app · compressed 4\.5 · 9\.2 · 1\.4/);expect(readouts[2]).toMatch(/Cached · free 12\.8 · 4\.1/);
 expect(readouts[3]).toMatch(/120 GB free · 494 GB/);
 // Orchid ink for the series; amber only for the pressure cells that read warn.
 const ink=await page.evaluate(()=>{const g=document.querySelector('[data-chart="memory-used"]');return g.getAttribute('fill');});
 expect(ink).toBe('#da66c2');
 // Inside the big-screen well only.
 const inside=await page.evaluate(()=>{const s=document.querySelector('.pl-screen').getBoundingClientRect(),w=document.querySelector('.dk-mfd .mfd-screen').getBoundingClientRect();
  return s.left>=w.left-.5&&s.right<=w.right+.5&&s.top>=w.top-.5&&s.bottom<=w.bottom+.5;});
 expect(inside).toBe(true);
 const before=await chart.locator('[data-chart="cpu"] [data-bar]').last().getAttribute('data-user');
 expect(await push([reading(T0+600000,{cpuUser:71,cpuSystem:25})])).toBe(true);
 await expect(chart.locator('[data-chart="cpu"] [data-bar]').last()).not.toHaveAttribute('data-user',before);
 await page.keyboard.press('Escape');
 await expect(screen).toHaveCount(0);
});

test('macrevb-1096-2 turning the plugin off and on (Settings or page Remove/Add) clears readings until a fresh sample',async({page})=>{
 const {push,receive,send}=await open(page);
 expect(await push([reading(T0,{cpuUser:71,cpuSystem:25}),reading(T0+5000,{cpuUser:71,cpuSystem:25})])).toBe(true);
 await expect(column(page).locator('.qvalue').first()).toHaveText('96');
 const off={version:1,entries:[{id:'resources',enabled:false,pinned:false}],settings:{}},on={version:1,entries:[],settings:{}};
 expect(await receive(send('plugins',{plugins:off}))).toBe(true);
 await expect(column(page)).toHaveCount(0);
 expect(await receive(send('plugins',{plugins:on}))).toBe(true);
 expect(await receive(send('display',{data:data2()}))).toBe(true);
 await expect(column(page)).toHaveCount(1);
 await expect(column(page).locator('.qvalue')).toHaveCount(0);
 expect(await push([reading(T0+600000,{cpuUser:8,cpuSystem:2})])).toBe(true);
 await expect(column(page).locator('.qvalue').first()).toHaveText('10');
 await expect(column(page).locator('.pl-cell[data-row="0"]')).toContainText('peak 10%');
});

// D371 Q5 (owner 11-21): the Resources cell is two layers, 31 pt, centred in the row the subscription table owns; the side value
// goes full, short, then hidden, never cut; the tag stays; tags are 10 px in the order CPU, memory, disk.
for(const [name,rows,columns] of [['3 columns',2,3],['6 columns',4,6]])
test(`D371 Q5 ${name}: the Resources cell has two fixed layers, lines up with the subscription rows and never clips`,async({page})=>{
 const {push}=await open(page,{rows,plugins:{version:1,entries:[CAL_OFF],settings:{}}});
 const cols=await page.locator('.eng-cols > .ec[data-col]').count();expect(cols).toBeGreaterThan(0);
 const samples=[0,1,2,3,4].map(i=>reading(T0+i*5000,{cpuUser:30+i*8,cpuSystem:5,memApp:(6+i)*GB,diskFree:(60-i)*GB}));
 expect(await push(samples)).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveCount(3);
 const m=await page.evaluate(()=>{
  const col=document.querySelector('.pl-col[data-plugin="resources"]'),box=e=>e.getBoundingClientRect(),cells=[...col.querySelectorAll('.pl-cell')];
  const quota=[...document.querySelectorAll('.eng-cols > .ec[data-col]:not(.pl-col) .qcell')].map(e=>box(e)).filter(r=>r.height>0);
  return {quotaHeights:quota.map(r=>Math.round(r.height)),quotaTops:[...new Set(quota.map(r=>Math.round(r.top)))].sort((a,b)=>a-b),
   cells:cells.map(c=>{const r=box(c),line=c.querySelector('.qline'),bar=c.querySelector('.pl-bar'),tag=c.querySelector('.pl-tag'),side=c.querySelector('.pl-side'),lead=c.querySelector('.pl-lead'),
    L=box(line),B=box(bar),T=box(tag),S=side?box(side):null;
    return {top:Math.round(r.top),height:Math.round(r.height),line:Math.round(L.height),bar:Math.round(B.height),gap:Math.round(B.top-L.bottom),span:Math.round(B.bottom-L.top),tag:tag.textContent,tagSize:getComputedStyle(tag).fontSize,tagVisible:T.width>0&&T.right<=box(line).right+.5,
     sideText:side?side.textContent:null,sideCut:side?side.scrollWidth>side.clientWidth+.5:false,sideRight:S?Math.round(r.right-S.right):null,sideForms:side?[side.dataset.full,side.dataset.short]:null,leadRight:box(lead).right<=r.right+.5,
     inside:L.left>=r.left-.5&&L.right<=r.right+.5&&B.right<=r.right+.5,trend:c.querySelectorAll('.pl-bar .pl-trend').length,num:getComputedStyle(c.querySelector('.qnum')).fontSize};})};
 });
 expect(m.cells.map(c=>c.tag)).toEqual(['CPU','Memory','Disk']);
 for(const c of m.cells){
  expect(c.tagSize).toBe('10px');expect(c.tagVisible).toBe(true);expect(c.leadRight).toBe(true);expect(c.inside).toBe(true);
  expect([c.line,c.bar,c.gap,c.span]).toEqual([22,6,3,31]);
  expect(c.sideCut,'the side value is never cut').toBe(false);
  expect([c.sideForms[0],c.sideForms[1],''],'full, short, then hidden').toContain(c.sideText);
  if(c.sideText)expect(c.sideRight).toBe(4);
  expect(['20px','16px']).toContain(c.num);
 }
 expect(m.cells.map(c=>c.trend)).toEqual([1,1,0]);
 // The rows line up with the subscription table's: same tops and heights as its quota cells, whatever the column count.
 expect(m.cells.map(c=>c.top)).toEqual(m.quotaTops.slice(0,3));
 for(const c of m.cells)expect(m.quotaHeights).toContain(c.height);
 if(columns===6)expect(m.cells.some(c=>c.sideText!==c.sideForms[0]),'the narrow table uses a short form or hides the side value').toBe(true);
});

/** `count` connected subscriptions: with six, every slot is a subscription column and an unpinned resource plugin has none (CKP-PLG-52). */
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
test('sample S4 (#1104 PLG-A2): the host-opened screen runs and draws its charts with six subscriptions and Resources unpinned',async({page})=>{
 const {send,receive,push}=await open(page,{plugins:{version:1,entries:[CAL_OFF],settings:{}}});
 expect(await receive(send('display',{data:dataWith(6)}))).toBe(true);
 await expect(column(page)).toHaveCount(0);
 await expect(key(page)).toHaveCount(0);
 expect((await running(page)).at(-1)).toEqual([]);
 // The widget card's "Cockpit screen ›" (pluginScreen from the host): the screen opens and the plugin runs, so the
 // host samples it and its readings reach the charts.
 expect(await receive(send('pluginScreen',{id:'resources'}))).toBe(true);
 const screen=page.locator('.mfd-screen .pl-screen[data-plugin="resources"]');
 await expect(screen).toBeVisible();
 expect((await running(page)).at(-1)).toEqual(['resources']);
 expect(await push(Array.from({length:6},(_,i)=>reading(T0+i*5000,{cpuUser:10+i})))).toBe(true);
 const chart=screen.locator('.pl-draw-chart');
 // No reading draws no chart; the readings fill the 60-bar CPU frame (one bar per 10 s: the last two 5 s samples, 14 % and 15 %).
 await expect(chart.locator('[data-chart="cpu"] [data-bar]')).toHaveCount(60);
 await expect(chart.locator('[data-chart="cpu"] [data-bar]').last()).toHaveAttribute('data-user','14.5');
 await expect(chart.locator('[data-chart="memory-used"]')).toHaveCount(1);
 await expect(chart.locator('[data-chart="disk"]')).toHaveCount(1);
 // Closing the screen stops it again (nothing samples for a plugin that is neither placed nor on screen).
 await page.keyboard.press('Escape');
 await expect(screen).toHaveCount(0);
 expect((await running(page)).at(-1)).toEqual([]);
 expect(await push([reading(T0+60000)])).toBe(false);
});
