// SPDX-License-Identifier: MIT
// History consumer (owner D36, D-D) on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=new Date(2026,10,4,12).getTime(),localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,data,locale='en',now=NOW) {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(now));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const sums=(out,input=null)=>({inputTokens:input,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:40,observedRequests:3,eligibleRequests:3});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function fixture(extra={}) {
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(9),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1200,300),recent30d:sums(4800,900)}]}],
  models:ranking,tools:ranking,
  daily:[{at:localDay(1),source:'codex',observedOutputTokens:1000},{at:localDay(0),source:'codex',observedOutputTokens:200},{at:localDay(1),source:'other',observedOutputTokens:9999}],hourly:[],
  projects:{recent7d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}],recent30d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}]},cycles:[],...extra};
 return {data,ref};
}

test('D36 the Overview shows 30-day totals from local records, labelled, and counts only the linked tool',async({page})=>{
 await open(page,fixture().data);
 await expect(page.locator('.ov-top .ov-sum')).toHaveText('1k');
 await expect(page.locator('.ov-top .ov-local')).toHaveText('On this Mac');
 await expect(page.locator('.ov-top')).toHaveCount(1);
});

test('D-D the Chinese label names the records as local',async({page})=>{
 await open(page,fixture().data,'zh-CN');
 await expect(page.locator('.ov-top .ov-local')).toHaveText('本机记录');
});

test('D36 the Subscription usage block reads the linked tools, and unknown kinds stay --',async({page})=>{
 await open(page,fixture().data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Subscription',exact:true}).click();
 const stats=page.locator('.sp-stats');await expect(stats).toContainText('1k');await expect(stats).toContainText('40 t/s');await expect(stats).toContainText('--');
});

test('D36 an unlabelled project is named by its rank',async({page})=>{
 await open(page,fixture().data);
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await expect(page.locator('.wh-n').first()).toHaveText('Project 1');
});

for(const [name,extra] of [['recording off',{coverage:'recording-off',subscriptions:[],daily:[]}],['no history',null]])
 test(`D36 ${name} shows no totals and no local label`,async({page})=>{
  const {data}=fixture(extra??{});if(extra===null)delete data.history;
  await open(page,data);
  await expect(page.locator('.ov-local')).toHaveCount(0);await expect(page.locator('.ov-sum')).toHaveCount(0);
 });

// macrevb-635-1: a short record ends at today, whatever the view's length.
const totals=page=>page.locator('.ov-bucket').evaluateAll(list=>list.map(e=>Number(e.dataset.total)));
test('D36 ten days of record put yesterday and today in the last buckets of the 30-day view',async({page})=>{
 await open(page,fixture().data);
 const values=await totals(page);expect(values.length).toBe(30);expect(values.slice(-2)).toEqual([1000,200]);expect(values.slice(0,-2).every(v=>v===0)).toBe(true);
 const tips=await page.locator('.ov-bucket').evaluateAll(list=>list.slice(-1).map(e=>e.dataset.tip));expect(tips[0]).not.toContain('No record');
});
test('D36 fewer than seven days of record sit at the end of the 7-day view',async({page})=>{
 await open(page,fixture({dailyFrom:localDay(2)}).data);
 await page.locator('[data-opt="days"] b',{hasText:/^7$/}).click();
 expect(await totals(page)).toEqual([0,0,0,0,0,1000,200]);
});

// macrevb-635-2: Today is known only when every selected subscription has a reading.
const today=(data,index,value)=>{data.details.subscriptions[index].today=value===null?[]:[{source:'codex',observedOutputTokens:value,generationTps:null,bindingBasis:'source-wide-current-binding'}];};
test('D36 an unknown Today stays unknown beside the history',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,null));
 await open(page,data);
 await expect(page.locator('.ov-total')).toHaveText('--');await expect(page.locator('.ov-sum')).toHaveText('1k');
});
test('D36 one unknown Today among known ones is not undercounted',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,500));today(data,0,null);
 await open(page,data);
 await expect(page.locator('.ov-total')).toHaveText('--');
});
test('D36 an observed zero Today stays zero',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,0));
 await open(page,data);
 await expect(page.locator('.ov-total')).toHaveText('0');
});

// macrevb-635-3: buckets are local hours, which need not be UTC hours.
for(const [zone,clock,buckets,last] of [
 ['Asia/Kolkata','2026-11-04T12:10:00+05:30',[['2026-11-04T12:00:00+05:30',777]],[777]],
 ['Asia/Kathmandu','2026-11-04T12:50:00+05:45',[['2026-11-04T12:00:00+05:45',777]],[777]],
 // The repeated 01:00 hour when daylight saving ends: two offsets, two buckets.
 ['America/New_York','2026-11-01T01:30:00-05:00',[['2026-11-01T01:00:00-04:00',111],['2026-11-01T01:00:00-05:00',222]],[111,222]],
])test.describe(zone,()=>{
 test.use({timezoneId:zone});
 test(`D36 local-hour buckets land in the right bar in ${zone}`,async({page})=>{
  const {data}=fixture({hourly:buckets.map(([at,n])=>({at,source:'codex',observedOutputTokens:n}))});
  await open(page,data,'en',Date.parse(clock));
  await page.locator('[data-opt="days"] b',{hasText:/^24h$/}).click();
  const values=await totals(page);expect(values.length).toBe(24);expect(values.slice(-last.length)).toEqual(last);
 });
});

test('SET-9-19 project names off: a labelled project in the ranking is named by its rank',async({page})=>{
 const {data}=fixture();data.history.projects.recent30d[0].label='desktop-secret';
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,showProjectNames:false},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await expect(page.locator('.wh-n').first()).toHaveText('Project 1');
 expect(await receive(send('appearance',{...appearance,showProjectNames:true}))).toBe(true);
 await expect(page.locator('.wh-n').first()).toHaveText('desktop-secret');
});

// H6/H7: closed cycles and their resets under the subscription, never a reset card claimed from a drop.
test('D36 the Subscription history shows closed cycles and reset rows',async({page})=>{
 const {data,ref}=fixture();const at=d=>new Date(NOW-d*864e5).toISOString();
 data.history.cycles=[{subscriptionRef:ref,kind:'five_hour',attribution:'unattributed',cycles:[
  {startedAt:at(3),resetsAt:at(2.8),points:40,hadDrop:false,spent:[{model:null,effort:'high',fast:false,points:40}]},
  {startedAt:at(2),resetsAt:at(1.8),points:60,hadDrop:true,spent:[]}]}];
 await open(page,data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await page.locator('[data-opt="tab"] b').nth(1).click();
 await expect(page.locator('.cy')).toHaveCount(2);await expect(page.locator('.cy .drop')).toHaveCount(1);
 await expect(page.locator('.rs')).toHaveCount(2);await expect(page.locator('.rs.src-correction')).toHaveCount(1);await expect(page.locator('.rs.src-card')).toHaveCount(0);
});
