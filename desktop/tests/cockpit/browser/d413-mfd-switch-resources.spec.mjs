// SPDX-License-Identifier: MIT
// D413 (owner 11-24): the Overview | screen switch keeps the four page keys equal (86 px in the app) in every screen
// state; a screen without a usable short name shows its icon alone; Escape and the left half return to the overview;
// the Resources screen is the four-card grid whose centre bottom key switches 10 min | 1 h; nothing runs on a timer or
// an animation frame while the cockpit is hidden (D397). Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const GB=1024**3,MIN=60_000,T0=Math.ceil(Date.UTC(2026,10,19,12)/MIN)*MIN;
const reading=(t,o={})=>{const s={t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:9.2*GB,memWired:4.5*GB,memCompressed:1.4*GB,memCached:12.8*GB,memFree:4.1*GB,swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB,netIn:1_200_000,netOut:86_000,...o};
 for(const k of Object.keys(s))if(k.startsWith('mem')||k.startsWith('disk')||k==='swapUsed')s[k]=Math.round(s[k]);return s;};
const ALL_ON={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false},{id:'placeholder',enabled:true,pinned:false}],settings:{}};
async function open(page,{locale='zh-CN',counters=false}={}){
 await page.clock.setFixedTime(new Date('2026-11-19T12:00:00Z'));
 await page.addInitScript(counters=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};
  if(!counters)return;window.__calls={raf:0,interval:0,timeout:0};
  const raf=window.requestAnimationFrame.bind(window),si=window.setInterval.bind(window),st=window.setTimeout.bind(window);
  window.requestAnimationFrame=f=>{window.__calls.raf++;return raf(f);};window.setInterval=(f,ms,...a)=>{window.__calls.interval++;return si(f,ms,...a);};window.setTimeout=(f,ms,...a)=>{window.__calls.timeout++;return st(f,ms,...a);};},counters);
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=sample();data.projection.rows=data.projection.rows.slice(0,2);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:ALL_ON}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 const push=(samples,minutes)=>receive(send('pluginData',{id:'resources',data:minutes?{samples,minutes}:{samples}}));
 // A placed plugin opens from its key; one without a column (no free slot) from the host, as the widget card does.
 const show=async id=>{const key=page.locator(`.eng-keys .pl-key[data-plugin="${id}"]`);if(await key.count())await key.click();else expect(await receive(send('pluginScreen',{id}))).toBe(true);};
 return {send,receive,push,show};
}
const keyWidths=page=>page.evaluate(()=>[...document.querySelectorAll('.dk-mfd .mfd-pk > .pk, .dk-mfd .mfd-pk > .pk-seg')].filter(e=>!e.hidden&&e.getClientRects().length).map(e=>Math.round(e.getBoundingClientRect().width*100)/100));
const seg=page=>page.locator('.dk-mfd .mfd-pk .pk-seg');

for(const locale of ['zh-CN','en'])
test(`D413 the four page keys keep one width in every screen state (${locale})`,async({page})=>{
 const {push,show}=await open(page,{locale});
 expect(await push([reading(T0),reading(T0+5000)])).toBe(true);
 const none=await keyWidths(page);expect(none.length).toBe(4);expect(new Set(none).size).toBe(1);
 for(const id of ['resources','calendar','placeholder']){
  await show(id);
  await expect(page.locator(`.mfd-screen .pl-screen[data-plugin="${id}"]`)).toBeVisible();
  const widths=await keyWidths(page);
  expect(widths,`${id}: four keys`).toHaveLength(4);
  expect(new Set(widths).size,`${id}: ${widths}`).toBe(1);expect(widths[0]).toBe(none[0]);
  // The switch's halves fit inside its own slot (never spills into the next key) and no text in them is cut.
  const fit=await page.evaluate(()=>{const s=document.querySelector('.mfd-pk .pk-seg').getBoundingClientRect();return [...document.querySelectorAll('.mfd-pk .pk-seg [role=tab]')].every(h=>{const r=h.getBoundingClientRect();return r.left>=s.left-.5&&r.right<=s.right+.5&&h.scrollWidth<=h.clientWidth+.5;});});
  expect(fit,id).toBe(true);
  await page.keyboard.press('Escape');await expect(seg(page)).toBeHidden();
 }
});

test('D413 switch names: short name beside the icon, icon only without one, lit right half, full name in tooltip',async({page})=>{
 const {push,show}=await open(page,{locale:'zh-CN'});
 expect(await push([reading(T0)])).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const cur=seg(page).locator('.cur');
 await expect(cur).toHaveText('资源');await expect(cur.locator('svg')).toHaveCount(1);await expect(cur.locator('.led')).toHaveCount(1);
 await expect(cur).toHaveAttribute('title','资源占用');await expect(cur).toHaveAttribute('aria-selected','true');
 await expect(seg(page).locator('.back')).toHaveText('总览');await expect(seg(page).locator('.back .led')).toHaveCount(0);
 // The placeholder plugin has no short name: the icon alone, no text, no ellipsis.
 await show('placeholder');
 await expect(page.locator('.mfd-screen .pl-screen[data-plugin="placeholder"]')).toBeVisible();
 await expect(cur.locator('svg')).toHaveCount(1);await expect(cur).toHaveText('');await expect(cur).toHaveAttribute('data-short','false');
 await expect(cur).toHaveAttribute('aria-label','占位插件');
 // No title row and no Close key on a screen.
 await expect(page.locator('.pl-screen .pl-screen-h, .pl-screen .pl-screen-x')).toHaveCount(0);
});

test('D413 Escape, the left half (pointer or keyboard) all return to the overview',async({page})=>{
 const {push}=await open(page,{locale:'en'});
 expect(await push([reading(T0)])).toBe(true);
 const overview=page.locator('.dk-mfd [data-mfd="page:overview"]'),screen=page.locator('.mfd-screen .pl-screen');
 for(const how of ['escape','click','keys']){
  await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
  await expect(screen).toBeVisible();await expect(overview).toBeHidden();
  await expect(seg(page).locator('.cur')).toHaveText('Sys');await expect(seg(page).locator('.back')).toHaveAttribute('title','Overview (Esc)');
  if(how==='escape')await page.keyboard.press('Escape');
  else if(how==='click')await seg(page).locator('.back').click();
  else{await seg(page).locator('.back').focus();await page.keyboard.press('ArrowRight');await expect(seg(page).locator('.cur')).toBeFocused();await page.keyboard.press('ArrowLeft');await expect(seg(page).locator('.back')).toBeFocused();await page.keyboard.press('Enter');}
  await expect(screen).toHaveCount(0);await expect(overview).toBeVisible();await expect(overview).toHaveAttribute('aria-pressed','true');
  await expect(page.locator('.dk-mfd .mfd-page.pg-overview')).toBeVisible();
 }
});

test('D413 Resources screen: four cards and the 10 min | 1 h key switch the series; blank side keys',async({page})=>{
 const {push}=await open(page);
 const minutes=Array.from({length:50},(_,i)=>({t:T0+i*MIN,cpu:20,cpuPeak:i===20?96:25,memory:47,memoryPeak:48,disk:76,diskPeak:76}));
 const samples=Array.from({length:120},(_,i)=>reading(T0+50*MIN+i*5000));
 expect(await push(samples,minutes)).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const grid=page.locator('.mfd-screen .pl-screen[data-plugin="resources"] .pl-grid');
 await expect(grid).toHaveAttribute('data-range','10m');
 await expect(grid.locator('[data-card]')).toHaveCount(4);
 const points=()=>grid.locator('[data-card="cpu"] [data-line]').evaluate(p=>(p.getAttribute('d').match(/L/g)??[]).length+1);
 expect(await points()).toBe(120);
 const keys=page.locator('.dk-mfd .mfd-ok > *');await expect(keys).toHaveCount(3);
 await expect(keys.nth(0)).toHaveClass(/dead/);await expect(keys.nth(2)).toHaveClass(/dead/);
 await expect(keys.nth(1).locator('b')).toHaveText(['10分钟','1小时']);await expect(keys.nth(1).locator('b.on')).toHaveText('10分钟');
 await keys.nth(1).locator('[data-choice="1h"]').click();
 await expect(grid).toHaveAttribute('data-range','1h');
 expect(await points()).toBe(60);
 await expect(grid.locator('[data-head]')).toHaveText('资源 · 最近 1 小时');
 await expect(keys.nth(1).locator('b.on')).toHaveText('1小时');
 await expect(grid.locator('[data-card="cpu"] [data-pv]')).toContainText('峰 96%');
 // The choice is remembered (view memory) when the screen opens again.
 await page.keyboard.press('Escape');await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await expect(page.locator('.mfd-screen .pl-grid')).toHaveAttribute('data-range','1h');
});

test('D397 no timer or animation frame runs while the cockpit is hidden, with the Resources screen open',async({page})=>{
 const {send,receive,push}=await open(page,{counters:true});
 expect(await push([reading(T0),reading(T0+5000)])).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await expect(page.locator('.mfd-screen .pl-grid')).toHaveCount(1);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 const before=await page.evaluate(()=>({...window.__calls}));
 await page.clock.runFor(10_000);
 expect(await push([reading(T0+10_000)])).toBe(false);
 const after=await page.evaluate(()=>({...window.__calls}));
 expect(after).toEqual(before);
});

// PR #1225 round 2. The header text never overlaps (real glyph boxes, EN with a swap-laden pressure), and a network
// card without readings says so instead of drawing a blank graph.
for(const locale of ['en','zh-CN'])
test(`D413 the Resources screen header does not overlap and a pressure with swap still fits (${locale})`,async({page})=>{
 const {push}=await open(page,{locale});
 expect(await push([reading(T0,{pressure:'warn',swapUsed:3*GB}),reading(T0+5000,{pressure:'warn',swapUsed:3*GB})])).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const grid=page.locator('.mfd-screen .pl-screen[data-plugin="resources"] .pl-grid');await expect(grid).toBeVisible();
 const boxes=await grid.evaluate(svg=>{const r=svg.getBoundingClientRect(),h=svg.querySelector('[data-head]').getBoundingClientRect(),t=[...svg.querySelectorAll('text[text-anchor="end"]')].find(e=>Math.abs(e.getBBox().y-6)<8)??svg.querySelectorAll('text[text-anchor="end"]')[0],b=t.getBoundingClientRect();return {head:[h.left,h.right],right:[b.left,b.right],area:[r.left,r.right]};});
 expect(boxes.head[1]).toBeLessThanOrEqual(boxes.right[0]);expect(boxes.right[1]).toBeLessThanOrEqual(boxes.area[1]);
});
for(const locale of ['en','zh-CN'])
test(`D413 the network card without readings shows an explicit empty state, not a blank graph (${locale})`,async({page})=>{
 const {push}=await open(page,{locale});
 const noNet=o=>{const s=reading(T0+o);delete s.netIn;delete s.netOut;return s;};
 expect(await push([noNet(0),noNet(5000)])).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const net=page.locator('.mfd-screen .pl-grid [data-card="network"]');
 await expect(net.locator('[data-empty]')).toHaveText(locale==='en'?'No network data yet':'暂无网络数据');
 await expect(net.locator('[data-line]')).toHaveCount(0);
 await expect(page.locator('.mfd-screen .pl-grid [data-card="cpu"] [data-empty]')).toHaveCount(0);
});
