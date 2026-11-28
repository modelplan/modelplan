// SPDX-License-Identifier: MIT
// WP-21 lane B, spec 2: the Calendar and Resources plugin columns on the built page through its normal bridge, synthetic data only.
// G3-142 (Resources column on first render), G3-148 (Calendar column wording, big time, two different rows), G3-149 (a nozzle
// under each plugin column), CKP-PLG-55 (Calendar rows: now, next peak, next reset), CKP-PLG-62 (next 12 hours only) and
// CKP-PLG-64 (Resources big-screen order CPU, memory, disk). CKP-PLG-63 (short fader labels) needs a fader fixture and stays with ckp-fad specs.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.use({timezoneId:'America/Los_Angeles'});
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// Pacific standard time in November 2026: local = UTC-8. Day 0 = Wednesday 11/11; now = 11:20.
const L=(day,h,m=0)=>Date.UTC(2026,10,11+day,h+8,m);
const NOW=L(0,11,20);
const both={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
const subs=[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}}];
const calendar=(over={})=>({version:1,peakRules:'yes',subs,
 peaks:[{sub:2,from:L(0,22),to:L(1,2),tentative:false}],
 resets:[{sub:0,at:L(0,12,30),kind:'5h'},{sub:1,at:L(0,14,10),kind:'5h'}],spans:[],...over});
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
async function open(page,{count=3,locale='en',plugins=both,push=null}={}) {
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(count)}))).toBe(true);
 if(push)expect(await receive(send('pluginData',{id:'calendar',data:push}))).toBe(true);
 return {send,receive};
}
const col=(page,id)=>page.locator(`.eng-cols .pl-col[data-plugin="${id}"]`);

// A box is clipped when its text is wider than the box, or the box leaves its column.
const clipped=(page,id)=>page.evaluate(id=>{
 const c=document.querySelector(`.eng-cols .pl-col[data-plugin="${id}"]`),cb=c.getBoundingClientRect(),bad=[];
 for(const e of c.querySelectorAll('.pl-tag,.qtxt,.pl-foot-l,.pl-foot-v,.cal-ch,.cal-pk,.cal-nt')){
  const r=e.getBoundingClientRect();if(!r.width||!r.height)continue;
  const ov=getComputedStyle(e).textOverflow==='ellipsis';
  if(!ov&&e.scrollWidth>e.clientWidth+1)bad.push(`${e.className}: ${e.textContent} scroll ${e.scrollWidth} > ${e.clientWidth}`);
  if(r.left<cb.left-1||r.right>cb.right+1)bad.push(`${e.className}: ${e.textContent} leaves the column`);
 }
 return bad;},id);

for(const [locale,tags] of [['en',['CPU','Memory','Disk']],['zh-CN',null]])for(const count of [2,4])
test(`G3-142 CKP-PLG-64 the Resources column on first render shows CPU, memory and disk tags in order, none clipped (${locale}, ${count} subscriptions)`,async({page})=>{
 await open(page,{locale,count,push:null,plugins:{version:1,entries:[{id:'calendar',enabled:false,pinned:false}],settings:{}}});
 const c=col(page,'resources');await expect(c).toHaveCount(1);
 const shown=await c.locator('.pl-tag').allTextContents();
 expect(shown).toHaveLength(3);
 if(tags)expect(shown).toEqual(tags);else{expect(shown[0]).toBe('CPU');expect(shown[1]).toBe('内存');expect(shown[2]).toBe('磁盘');}
 // Each tag is drawn at full size: a real box, a legible font, and rows in reading order.
 const boxes=await c.locator('.pl-tag').evaluateAll(es=>es.map(e=>{const r=e.getBoundingClientRect();return {top:r.top,w:r.width,h:r.height,font:parseFloat(getComputedStyle(e).fontSize)};}));
 for(const b of boxes){expect(b.w).toBeGreaterThan(8);expect(b.h).toBeGreaterThan(6);expect(b.font).toBeGreaterThanOrEqual(9);}
 expect(boxes[0].top).toBeLessThan(boxes[1].top);expect(boxes[1].top).toBeLessThan(boxes[2].top);
 expect(await clipped(page,'resources')).toEqual([]);
 await expect(c).not.toContainText('--');
});

// D466: the Calendar column is gone (the calendar is the 5th page, covered by d466-band-calendar.spec.mjs), so the
// column wording, now/peak/reset rows and 12-hour window specs that lived here moved with it.

for(const locale of ['en','zh-CN'])test(`G3-149 every plugin column hangs a nozzle under the hull, centred on its column (${locale})`,async({page})=>{
 await open(page,{locale});
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0);
 const v=await page.evaluate(()=>{
  const cols=[...document.querySelectorAll('.eng-cols > .ec')].map(c=>{const r=c.getBoundingClientRect();return {x:r.left+r.width/2,plugin:c.dataset.plugin??null};});
  const bells=[...document.querySelectorAll('.ck-base .bz')].map(b=>{const r=b.querySelector('.bz-line').getBoundingClientRect();return {x:r.left+r.width/2,w:r.width,plugin:/\bplugin\b/.test(b.className)};});
  return {cols,bells};});
 expect(v.bells).toHaveLength(v.cols.length);
 expect(v.cols.filter(c=>c.plugin).length).toBeGreaterThanOrEqual(1);
 for(const [i,b] of v.bells.entries()){expect(Math.abs(b.x-v.cols[i].x)).toBeLessThan(1);expect(b.w).toBeGreaterThan(40);expect(b.plugin).toBe(!!v.cols[i].plugin);}
});

test('CKP-PLG-64 the Resources big screen lists CPU, memory and disk, in that order',async({page})=>{
 const {send,receive}=await open(page,{push:null});
 const GB=1024**3,T0=Date.UTC(2026,10,19,12);
 const s=(t)=>({t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:9*GB,memWired:4*GB,memCompressed:GB,memCached:12*GB,memFree:4*GB,swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB});
 expect(await receive(send('pluginData',{id:'resources',data:{samples:[s(T0),s(T0+5000)]}}))).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 const cards=page.locator('.mfd-screen .pl-screen[data-plugin="resources"] [data-card]');
 await expect(cards).toHaveCount(4);
 expect((await cards.evaluateAll(es=>es.map(e=>e.dataset.card))).slice(0,3)).toEqual(['cpu','memory','disk']);
});
