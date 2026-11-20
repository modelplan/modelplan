// SPDX-License-Identifier: MIT
// D63: a total over a period longer than the local record names where the record starts. Built page, normal bridge,
// synthetic data only.
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


// CKP-SHELL-50 (WP-09): the totals follow the app's range, which starts at 7d; the overview cases are about the 30-day total.
const to30=page=>page.locator('[data-opt="range"] b').nth(2).click();
const label=page=>page.locator('.ov-top .lbl').first().textContent();
test('D63 a record shorter than 30 days labels the 30-day total with its start',async({page})=>{
 await open(page,fixture().data);
 await to30(page);
 expect(await label(page)).toBe('since 10-26');await expect(page.locator('.ov-top .ov-total')).toHaveText('1k');
});
test('D63 imported history that starts earlier moves the start to the earliest day of either source',async({page})=>{
 const {data}=fixture({dailyFrom:localDay(14)});data.history.daily.push({at:localDay(14),source:'codex',origin:'import',observedOutputTokens:500});
 await open(page,data);
 await to30(page);
 expect(await label(page)).toBe('since 10-21');
});
test('D63 the Chinese label says where the record starts',async({page})=>{
 await open(page,fixture().data,'zh-CN');
 await to30(page);
 expect(await label(page)).toBe('自 10-26 起');
});
for(const back of [29,40])test(`D63 a record of ${back+1} days keeps the plain 30-day label`,async({page})=>{
 await open(page,fixture({dailyFrom:localDay(back)}).data);
 await to30(page);
 expect(await label(page)).toBe('30d');
});
test('D63 the Subscription usage block names a record shorter than its window',async({page})=>{
 await open(page,fixture({dailyFrom:localDay(2)}).data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await expect(page.locator('.sp-stats .stat-h')).toHaveText('7-day usage · Linked tools · Recorded since Nov 2');
});
test('D63 a full week of record keeps the plain 7-day heading',async({page})=>{
 await open(page,fixture({dailyFrom:localDay(6)}).data);
 await page.keyboard.press('1');await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await expect(page.locator('.sp-stats .stat-h')).toHaveText('7-day usage · Linked tools');
});
test('D63 a calendar-invalid first day is not shown as a shifted date',async({page})=>{
 await open(page,fixture({dailyFrom:'2026-02-30'}).data);
 await to30(page);
 expect(await label(page)).toBe('30d');
});
