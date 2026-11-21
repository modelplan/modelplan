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
  daily:[{at:localDay(1),source:'codex',origin:'live',observedOutputTokens:1000},{at:localDay(0),source:'codex',origin:'live',observedOutputTokens:200},{at:localDay(1),source:'other',origin:'live',observedOutputTokens:9999}],hourly:[],
  projects:{recent7d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}],recent30d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}]},cycles:[],...extra};
 return {data,ref};
}

test('D36 the Overview shows 30-day totals from local records, labelled, and counts only the linked tool',async({page})=>{
 await open(page,fixture().data);
 await expect(page.locator('.ov-top .ov-total')).toHaveText('1k');
 // WP-12: the totals row has no extra label; the records' origin is the row's hover note.
 await expect(page.locator('.ov-top')).toHaveAttribute('data-tip','On this Mac');
 await expect(page.locator('.ov-top')).toHaveCount(1);
});

test('D-D the Chinese label names the records as local',async({page})=>{
 await open(page,fixture().data,'zh-CN');
 await expect(page.locator('.ov-top')).toHaveAttribute('data-tip','本机记录');
});

test('D36 the Subscription usage block reads the linked tools, and unknown kinds stay --',async({page})=>{
 await open(page,fixture().data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Plans',exact:true}).click();
 const stats=page.locator('.sp-stats');await expect(stats).toContainText('1k');await expect(stats).toContainText('40 t/s');await expect(stats).toContainText('--');
});

test('D36 an unlabelled project is named by its rank',async({page})=>{
 await open(page,fixture().data);
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await expect(page.locator('.wd-n').first()).toHaveText('Project 1');
});

for(const [name,extra] of [['recording off',{coverage:'recording-off',subscriptions:[],daily:[]}],['no history',null]])
 test(`D36 ${name} shows no totals and no local label`,async({page})=>{
  const {data}=fixture(extra??{});if(extra===null)delete data.history;
  await open(page,data);
  await expect(page.locator('.ov-local')).toHaveCount(0);await expect(page.locator('.ov-sum')).toHaveCount(0);
 });

// macrevb-635-1 (a short record ends at today) is covered on the ≈cost series by unit/wp-12-overview-bars.test.mjs (WP-12).
// macrevb-635-2: Today is known only when every selected subscription has a reading.
const today=(data,index,value)=>{data.details.subscriptions[index].today=value===null?[]:[{source:'codex',observedOutputTokens:value,generationTps:null,bindingBasis:'source-wide-current-binding'}];};
const day24=page=>page.locator('[data-opt="range"] b',{hasText:/^Today$/}).click();
test('D36 an unknown Today stays unknown beside the history',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,null));
 await open(page,data);
 await expect(page.locator('.ov-total')).toHaveText('1k');
 await day24(page);await expect(page.locator('.ov-total')).toHaveCount(0);
});
test('D36 one unknown Today among known ones is not undercounted',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,500));today(data,0,null);
 await open(page,data);await day24(page);
 await expect(page.locator('.ov-total')).toHaveCount(0);
});
test('D36 an observed zero Today stays zero',async({page})=>{
 const {data}=fixture();data.details.subscriptions.forEach((_,i)=>today(data,i,0));
 await open(page,data);await day24(page);
 await expect(page.locator('.ov-total')).toHaveText('0');
});

test('SET-9-19 project names off: a labelled project in the ranking is named by its rank',async({page})=>{
 const {data}=fixture();data.history.projects.recent30d[0].label='desktop-secret';data.history.projects.recent7d[0].label='desktop-secret';
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,showProjectNames:false},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await expect(page.locator('.wd-n').first()).toHaveText('Project 1');
 expect(await receive(send('appearance',{...appearance,showProjectNames:true}))).toBe(true);
 await expect(page.locator('.wd-n').first()).toHaveText('desktop-secret');
});

// H6/H7: closed cycles and their resets under the subscription, never a reset card claimed from a drop.
test('D36 the Subscription history shows closed cycles and reset rows',async({page})=>{
 const {data,ref}=fixture();const at=d=>new Date(NOW-d*864e5).toISOString();
 data.history.cycles=[{subscriptionRef:ref,kind:'five_hour',attribution:'unattributed',cycles:[
  {startedAt:at(3),resetsAt:at(2.8),points:40,hadDrop:false,spent:[{model:null,effort:'high',fast:false,points:40}]},
  {startedAt:at(2),resetsAt:at(1.8),points:60,hadDrop:true,spent:[]}]}];
 await open(page,data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Plans',exact:true}).click();
 await page.locator('[data-opt="tab"] b').nth(1).click();
 await expect(page.locator('.cy')).toHaveCount(2);await expect(page.locator('.cy .drop')).toHaveCount(1);
 // The wire is oldest first and the chart runs left to right, so the later cycle (with the drop) is on the right.
 await expect(page.locator('.cy').nth(1).locator('.drop')).toHaveCount(1);await expect(page.locator('.cy').nth(0).locator('.drop')).toHaveCount(0);
 await expect(page.locator('.rs')).toHaveCount(2);await expect(page.locator('.rs.src-correction')).toHaveCount(1);await expect(page.locator('.rs.src-card')).toHaveCount(0);
});
