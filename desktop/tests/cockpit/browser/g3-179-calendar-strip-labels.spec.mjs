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
