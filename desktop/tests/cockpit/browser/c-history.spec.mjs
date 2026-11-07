// SPDX-License-Identifier: MIT
// History consumer (owner D36, D-D) on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=new Date(2026,10,4,12).getTime(),localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,data,locale='en') {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
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
  projects:{recent7d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}],recent30d:[{ref:'p1',label:null,model:null,effort:'high',observedOutputTokens:1200,share:1}]},...extra};
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
