// SPDX-License-Identifier: MIT
// G3-179 (owner 11-22, shot screenshot-20261122-142331.png): in a six-column cockpit the calendar strip's peak label
// ("GLM 09:00–…") clipped to "GLM 09:…", losing the time — the block's one fact. The label now sheds its abbreviation,
// then its end, before any of it clips (the tooltip keeps the whole sentence); the week view's zoomed time line drops
// its end the same way. The fitted surfaces the same shot asked about (the 全天 label, the all-day line, the week view's
// 全天 row against the 00 tick) are pinned as they are.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.use({timezoneId:'America/Los_Angeles'});
test.beforeEach(async({page})=>excludePortholeFlicker(page));
// Saturday 22:54 local: the 12-hour strip crosses midnight into Sunday; a peak starts Sunday 09:00, open-ended.
const NOW=Date.UTC(2026,10,21,22+8,54);
const L=(day,h,m=0)=>Date.UTC(2026,10,21+day,h+8,m);
const calendarOn={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:false,pinned:false}],settings:{}};
const week={version:1,peakRules:'yes',
 subs:[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}}],
 peaks:[{sub:2,from:L(1,9),to:null,tentative:false},{sub:0,from:L(0,5),to:L(1,4),tentative:false}],
 resets:[{sub:0,at:L(1,9),kind:'week'},{sub:1,at:L(2,6),kind:'week'}],
 spans:[{sub:0,kind:'cards',from:NOW,to:L(3,18),count:2},{sub:2,kind:'announced',from:L(-1,10),to:L(5,0),count:null}]};
// Five subscriptions + the calendar = six engine columns, the owner's layout (on main: 62 px of label in a 45 px block).
function sixColumns(){
 const data=sample(),seed=data.projection.rows[0];
 seed.surfaces=['dock','menu','settings'];
 data.projection.rows=[seed,...Array.from({length:4},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+1}`;row.name={en:`Tool ${i+1}`,zh:`工具 ${i+1}`};row.order=i+1;row.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});return row;})];
 return data;
}
async function open(page,{locale='zh-CN'}={}){
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:calendarOn}))).toBe(true);
 expect(await receive(send('display',{data:sixColumns()}))).toBe(true);
 expect(await receive(send('pluginData',{id:'calendar',data:week}))).toBe(true);
 return {send,receive};
}

test('G3-179 six columns: the strip peak label keeps its time, the all-day line and 全天 stay whole',async({page})=>{
 await open(page);
 const s=page.locator('.eng-cols .pl-col[data-plugin="calendar"] .pl-draw .cal');
 await expect(s).toBeVisible();
 // No peak label clips; the 09:00 peak still reads its start time after shortening.
 const peaks=await s.locator('.cal-pk b').evaluateAll(list=>list.map(e=>({text:e.textContent,clipped:e.scrollWidth>e.clientWidth})));
 expect(peaks.length).toBeGreaterThan(0);
 for(const p of peaks)expect(p.clipped,{text:p.text}).toBe(false);
 expect(peaks.some(p=>p.text.includes('09:00'))).toBe(true);
 // The same shot's other labels fit as they are: 全天 and the all-day line.
 for(const e of ['.cal-adl','.cal-adr'])expect(await s.locator(e).evaluate(x=>x.scrollWidth<=x.clientWidth),e).toBe(true);
});

test('G3-179 week view: the zoomed time line keeps the start time; the 全天 row clears the 00 tick',async({page})=>{
 await open(page);
 await page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click();
 const w=page.locator('.dk-mfd .mfd-screen .pl-screen[data-plugin="calendar"] .cal-wk');
 await expect(w).toBeVisible();
 // The fitted view: the 全天 label and row, and the 00 tick sits clear below the 全天 row.
 expect(await w.locator('.wk-adl').evaluate(x=>x.scrollWidth<=x.clientWidth)).toBe(true);
 const gap=await w.evaluate(w=>{const ad=w.querySelector('.wk-ad').getBoundingClientRect(),tick=w.querySelector('.wk-g.top i')?.getBoundingClientRect();return tick?tick.top-ad.bottom:null;});
 expect(gap).not.toBeNull();expect(gap).toBeGreaterThanOrEqual(0);
 // Zoomed: every peak time line fits (its end drops first, the start time stays).
 await w.locator('.wk-dh').first().focus();
 for(let i=0;i<3;i++)await page.keyboard.press('Meta+=');
 await expect(w).toHaveClass(/zoom/);
 const times=await w.locator('.wk-pk i').evaluateAll(list=>list.map(e=>({text:e.textContent,clipped:e.scrollWidth>e.clientWidth})));
 expect(times.length).toBeGreaterThan(0);
 for(const t of times)expect(t.clipped,{text:t.text}).toBe(false);
 expect(times.some(t=>t.text.includes('09:00'))).toBe(true);
});

// Sampling 11-22 (PR 1172): an overlapping pair splits the strip into two ~18 px lanes — narrower than a 27 px HH:MM
// even after the abbreviation and the end drop — and a peak with one minute of strip left is a ~2 px block that clips
// its 11 px line. The time then leaves the lane as a tag on the axis, settled so tags never cover each other.
async function openPeaks(page,peaks,{locale='zh-CN'}={}){
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:calendarOn}))).toBe(true);
 expect(await receive(send('display',{data:sixColumns()}))).toBe(true);
 expect(await receive(send('pluginData',{id:'calendar',data:{...week,peaks}}))).toBe(true);
}
// Sunday 09:00–11:00 and 09:30–12:00: the pair shares the strip as two lanes.
const OVERLAP=[{sub:2,from:L(1,9),to:L(1,11),tentative:false},{sub:0,from:L(1,9,30),to:L(1,12),tentative:false}];
test('G3-179 sampling: an overlapping pair keeps both start times readable in the strip and the zoomed week',async({page})=>{
 await openPeaks(page,OVERLAP);
 const s=page.locator('.eng-cols .pl-col[data-plugin="calendar"] .pl-draw .cal');
 await expect(s).toBeVisible();
 const axis=await s.locator('.cal-ax').boundingBox();
 const times=await s.locator('.cal-pk b, .cal-pkt').evaluateAll(list=>list.filter(e=>/09:(00|30)/.test(e.textContent)).map(e=>({text:e.textContent,box:e.getBoundingClientRect()})));
 expect(times.length,'both start times drawn').toBe(2);
 for(const t of times){
  expect(t.box.width,'the drawn time is not horizontally clipped').toBeGreaterThanOrEqual(t.text.length*4.6);
  expect(t.box.bottom,'fully inside the strip axis').toBeLessThanOrEqual(axis.y+axis.height+0.5);
  expect(t.box.top,'fully inside the strip axis').toBeGreaterThanOrEqual(axis.y-0.5);
 }
 // The zoomed week view splits the day column the same way; the time stays whole there too.
 await page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click();
 const w=page.locator('.dk-mfd .mfd-screen .pl-screen[data-plugin="calendar"] .cal-wk');
 await expect(w).toBeVisible();
 await w.locator('.wk-dh').first().focus();
 for(let i=0;i<3;i++)await page.keyboard.press('Meta+=');
 await expect(w).toHaveClass(/zoom/);
 await w.locator('.wk-pk i, .wk-pkt').filter({hasText:'09:00'}).first().scrollIntoViewIfNeeded();
 const wk=await w.locator('.wk-pk i, .wk-pkt').evaluateAll(list=>list.map(e=>({text:e.textContent,clipped:e.scrollWidth>e.clientWidth,box:e.getBoundingClientRect().toJSON()})));
 expect(wk.filter(t=>t.text.includes('09:00')).length,'the 09:00 start is drawn').toBeGreaterThan(0);
 expect(wk.filter(t=>t.text.includes('09:30')).length,'the 09:30 start is drawn').toBeGreaterThan(0);
 for(const t of wk)expect(t.clipped,{text:t.text}).toBe(false);
 const [a,b]=['09:00','09:30'].map(start=>wk.find(t=>t.text.includes(start)).box);
 expect(a.right<=b.left || b.right<=a.left || a.bottom<=b.top || b.bottom<=a.top,'week labels do not overlap').toBe(true);
 const visible=await w.locator('.wk-sc').boundingBox();
 for(const box of [a,b]){expect(box.top).toBeGreaterThanOrEqual(visible.y-0.5);expect(box.bottom).toBeLessThanOrEqual(visible.y+visible.height+0.5);}
});
test('G3-179 sampling: a peak beginning one minute before the strip ends keeps its time readable',async({page})=>{
 // NOW is Saturday 22:54; the strip runs to Sunday 10:54. A peak from 10:53 has one minute of block.
 await openPeaks(page,[{sub:2,from:L(1,10,53),to:null,tentative:false}]);
 const s=page.locator('.eng-cols .pl-col[data-plugin="calendar"] .pl-draw .cal');
 await expect(s).toBeVisible();
 const axis=await s.locator('.cal-ax').boundingBox();
 const visible=await s.locator('.cal-pk b, .cal-pkt').evaluateAll(list=>list.filter(e=>e.textContent.includes('10:53')).map(e=>({text:e.textContent,box:e.getBoundingClientRect()})));
 expect(visible.length,'exactly one 10:53 label').toBe(1);
 expect(visible[0].box.height,'a full line tall').toBeGreaterThanOrEqual(10);
 expect(visible[0].box.bottom,'fully inside the strip axis').toBeLessThanOrEqual(axis.y+axis.height+0.5);
 expect(visible[0].box.top,'fully inside the strip axis').toBeGreaterThanOrEqual(axis.y-0.5);
});
