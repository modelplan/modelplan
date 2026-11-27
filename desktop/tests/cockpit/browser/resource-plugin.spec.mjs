// SPDX-License-Identifier: MIT
// Resource plugin (owner D324, D327) on the real cockpit through the normal bridge: the column (CPU · 内存 · 磁盘 cells,
// orchid dashed key underline), the lifecycle report the host samples by, and, once readings arrive, the D407 R1
// half-circle radar on the D323 draw hook in the column and the big screen. The host side (sampling cadence, ring buffer,
// network rates) is ModelPlanResources.
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
/** The radar inside `root`: arc values and strokes, row numbers and their colours, labels, network text. */
const radar=(page,root='.pl-col[data-plugin="resources"]')=>page.evaluate(root=>{const r=document.querySelector(root)?.querySelector('.pl-radar');if(!r)return null;
 const q=s=>[...r.querySelectorAll(s)];
 return {arcs:q('[data-arc]').map(a=>a.dataset.arc),values:q('[data-arc]').map(a=>a.dataset.value),strokes:q('[data-arc]').map(a=>getComputedStyle(a).stroke),
  nums:q('[data-row] [data-num]').map(n=>n.firstChild.textContent),numColours:q('[data-row] [data-num]').map(n=>getComputedStyle(n).fill),
  labels:q('[data-label]').map(l=>l.textContent),sides:q('[data-side]').map(l=>l.textContent),aria:r.getAttribute('aria-label'),
  network:r.querySelector('[data-row="network"]').textContent,sparks:q('[data-spark]').length};},root);

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
 expect(await push([reading(T0+10000,{netIn:1_200_000,netOut:86_000})])).toBe(true);
 // D407 R1: the readings turn the column into the radar; every arc has its row, network is a text row only.
 await expect(column(page)).toHaveAttribute('data-draw','custom');
 const r=await radar(page);
 expect(r.arcs).toEqual(['cpu','memory','disk']);expect(r.values).toEqual(['22','47','76']);expect(r.nums).toEqual(['22','47','76']);
 expect(r.labels[0]).toBe('CPU');expect(['Memory','Mem']).toContain(r.labels[1]);expect(r.labels[2]).toBe('Disk');
 expect(r.aria).toMatch(/CPU 22% · Memory 47% · Disk 76% · Network ↓1\.2M ↑86K/);
 expect(r.network).toMatch(/Network.*↓1\.2M ↑86K/);expect(r.sparks).toBeGreaterThanOrEqual(2);
 await expect(column(page).locator('[data-spark="cpu"]')).toHaveCount(1);await expect(column(page).locator('[data-spark="memory"]')).toHaveCount(1);
 await expect(column(page).locator('.pl-radar [data-arc="network"]')).toHaveCount(0);
 await expect(column(page).locator('.pl-foot')).toContainText('Normal');
 const ink=await page.evaluate(()=>document.querySelector('.pl-col[data-plugin="resources"]').style.getPropertyValue('--pl-ink'));
 expect(ink).toBe('#da66c2');
});

test('D371 B4c / D407 status colour: arcs and numbers are normal / amber / red by resource state, never the plugin orchid',async({page})=>{
 const {push}=await open(page,{locale:'zh-CN'});
 expect(await push([reading(T0),reading(T0+5000)])).toBe(true);
 const normal=await radar(page);
 expect(new Set(normal.strokes).size).toBe(1);expect(normal.strokes[0]).not.toBe('rgb(218, 102, 194)');
 expect(normal.numColours).toEqual(normal.strokes);
 // CPU 96 % red, memory warn pressure amber, disk 92 % red.
 expect(await push([reading(T0+10000,{cpuUser:71,cpuSystem:25,pressure:'warn',swapUsed:2.1*GB,diskFree:40*GB})])).toBe(true);
 await expect(column(page).locator('.pl-foot')).toContainText('偏高');
 const hot=await radar(page);
 expect(hot.numColours).toEqual(hot.strokes);
 expect(hot.strokes[0]).toBe(hot.strokes[2]);expect(hot.strokes[1]).not.toBe(hot.strokes[0]);expect(hot.strokes).not.toContain(normal.strokes[0]);
 // Back to normal pressure, a 94 % memory reading is red by percentage.
 expect(await push([reading(T0+15000,{memApp:20.4*GB,memWired:5.2*GB,memCompressed:4.6*GB,memCached:1.2*GB,memFree:.6*GB})])).toBe(true);
 const full=await radar(page);expect(full.nums[1]).toBe('94');expect(full.strokes[1]).toBe(hot.strokes[0]);
 // A refused reading changes nothing.
 expect(await push([{...reading(T0+20000),cpuUser:200}])).toBe(false);
 expect((await radar(page)).nums[1]).toBe('94');
});

test('D371 the Resources tab icon has no small square frame (the Calendar icon is unchanged)',async({page})=>{
 await open(page);
 const frames=await page.evaluate(()=>{const k=document.querySelector('.eng-keys .pl-key[data-plugin="resources"]');return [k.querySelectorAll('.lamp svg rect').length,k.querySelectorAll('.lamp svg').length];});
 expect(frames).toEqual([0,1]);
});

test('D413 the big screen: the four-card grid on the draw hook, redrawn by readings, closed by Escape',async({page})=>{
 const {push}=await open(page,{plugins:{version:1,entries:[],settings:{resources:{intervalSeconds:10}}}});
 expect(await push(Array.from({length:60},(_,i)=>reading(T0+i*10000,{cpuUser:10+i%40,pressure:i>50?'warn':'normal',netIn:5000,netOut:120})))).toBe(true);
 await key(page).click();
 const screen=page.locator('.mfd-screen .pl-screen[data-plugin="resources"]');
 await expect(screen).toBeVisible();
 await expect(screen).toHaveAttribute('data-draw','custom');
 const grid=screen.locator('.pl-grid');
 await expect(grid.locator('[data-card]')).toHaveCount(4);
 await expect(grid.locator('[data-arc]')).toHaveCount(0);
 await expect(grid).toContainText('Elevated');
 await expect(grid.locator('[data-card="network"] [data-detail]')).toHaveText('↑ 120 B/s');
 // D347: CPU, Memory, Disk in reading order (left to right, then down), and the grid sits inside the big-screen well.
 const boxes=await page.evaluate(()=>{const b=s=>document.querySelector(s).getBoundingClientRect(),w=b('.dk-mfd .mfd-screen'),svg=b('.pl-screen .pl-grid');
  const at=id=>b(`.pl-screen [data-card="${id}"] rect`);
  return {cpu:at('cpu'),mem:at('memory'),disk:at('disk'),inside:svg.left>=w.left-.5&&svg.right<=w.right+.5&&svg.top>=w.top-.5&&svg.bottom<=w.bottom+.5};});
 expect(boxes.cpu.left).toBeLessThan(boxes.mem.left);expect(boxes.mem.top).toBeLessThan(boxes.disk.top);expect(boxes.inside).toBe(true);
 expect(await push([reading(T0+600000,{cpuUser:71,cpuSystem:25})])).toBe(true);
 await expect(grid.locator('[data-card="cpu"] [data-value]')).toHaveText('96%');
 await page.keyboard.press('Escape');
 await expect(screen).toHaveCount(0);
});

test('macrevb-1096-2 turning the plugin off and on (Settings or page Remove/Add) clears readings until a fresh sample',async({page})=>{
 const {push,receive,send}=await open(page);
 expect(await push([reading(T0,{cpuUser:71,cpuSystem:25}),reading(T0+5000,{cpuUser:71,cpuSystem:25})])).toBe(true);
 await expect(column(page).locator('[data-arc="cpu"]')).toHaveAttribute('data-value','96');
 const off={version:1,entries:[{id:'resources',enabled:false,pinned:false}],settings:{}},on={version:1,entries:[],settings:{}};
 expect(await receive(send('plugins',{plugins:off}))).toBe(true);
 await expect(column(page)).toHaveCount(0);
 expect(await receive(send('plugins',{plugins:on}))).toBe(true);
 expect(await receive(send('display',{data:data2()}))).toBe(true);
 await expect(column(page)).toHaveCount(1);
 await expect(column(page).locator('.qvalue')).toHaveCount(0);
 await expect(column(page).locator('.pl-radar')).toHaveCount(0);
 expect(await push([reading(T0+600000,{cpuUser:8,cpuSystem:2})])).toBe(true);
 await expect(column(page).locator('[data-arc="cpu"]')).toHaveAttribute('data-value','10');
 await expect(column(page).locator('[data-row="cpu"] [data-side]')).toHaveText(/10%/);
});

// D407 R1: the radar takes the whole column above the bottom line (no empty band below), and nothing in it clips or
// collides, in a wide and a narrow table.
for(const [name,rows] of [['3 columns',2],['6 columns',4]])
test(`D407 R1 ${name}: the radar fills the column rows, the network row sits at the bottom, no text clips or overlaps`,async({page})=>{
 const {push}=await open(page,{rows,plugins:{version:1,entries:[CAL_OFF],settings:{}}});
 const samples=[0,1,2,3,4].map(i=>reading(T0+i*5000,{cpuUser:30+i*8,cpuSystem:5,memApp:(6+i)*GB,diskFree:(60-i)*GB,netIn:1_200_000,netOut:86_000}));
 expect(await push(samples)).toBe(true);
 await expect(column(page).locator('.pl-radar')).toHaveCount(1);
 const m=await page.evaluate(()=>{
  const col=document.querySelector('.pl-col[data-plugin="resources"]'),box=e=>e.getBoundingClientRect(),area=box(col.querySelector('.pl-draw')),svg=box(col.querySelector('.pl-radar')),foot=box(col.querySelector('.pl-foot'));
  const quota=[...document.querySelectorAll('.eng-cols > .ec[data-col]:not(.pl-col) .qcell')].map(box).filter(r=>r.height>0);
  const texts=[...col.querySelectorAll('.pl-radar text')].map(t=>({t:t.textContent,r:box(t),row:t.closest('[data-row]')?.dataset.row}));
  const overlaps=[];for(let i=0;i<texts.length;i++)for(let j=i+1;j<texts.length;j++){const a=texts[i].r,b=texts[j].r;
   if(a.left<b.right-.5&&b.left<a.right-.5&&a.top<b.bottom-.5&&b.top<a.bottom-.5)overlaps.push(texts[i].t+' / '+texts[j].t);}
  const net=box(col.querySelector('[data-row="network"]'));
  return {area:[area.top,area.bottom,area.height],svg:[svg.width,svg.height],areaW:area.width,foot:foot.top,quotaTop:Math.min(...quota.map(r=>r.top)),
   outside:texts.filter(x=>x.r.left<area.left-.5||x.r.right>area.right+.5||x.r.top<area.top-.5||x.r.bottom>area.bottom+.5).map(x=>x.t),overlaps,netGap:area.bottom-net.bottom};
 });
 expect(Math.abs(m.area[0]-m.quotaTop)).toBeLessThanOrEqual(1);
 expect(Math.abs(m.area[1]-m.foot)).toBeLessThanOrEqual(1);
 expect(Math.abs(m.svg[1]-m.area[2])).toBeLessThanOrEqual(1);
 expect(m.outside,'every text inside the area').toEqual([]);
 expect(m.overlaps,'no two texts overlap').toEqual([]);
 expect(m.netGap,'the network row sits at the bottom').toBeLessThanOrEqual(10);
});

/** `count` connected subscriptions: with six, every slot is a subscription column and an unpinned resource plugin has none (CKP-PLG-52). */
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
test('sample S4 (#1104 PLG-A2): the host-opened screen runs and draws its grid with six subscriptions and Resources unpinned',async({page})=>{
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
 const chart=screen.locator('.pl-grid');
 // The readings reach the grid: the newest sample is 15 % user + 3 % system.
 await expect(chart.locator('[data-card="cpu"] [data-value]')).toHaveText('18%');
 await expect(chart.locator('[data-card]')).toHaveCount(4);
 // Closing the screen stops it again (nothing samples for a plugin that is neither placed nor on screen).
 await page.keyboard.press('Escape');
 await expect(screen).toHaveCount(0);
 expect((await running(page)).at(-1)).toEqual([]);
 expect(await push([reading(T0+60000)])).toBe(false);
});
