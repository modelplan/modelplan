// SPDX-License-Identifier: MIT
// HIST-IMP-05 (D117): imported history counts like live data and carries no origin marker. WP-12: the overview bars are
// ≈cost, whose buckets carry no origin, so the bars have no imported part to mark; the totals row names where the record
// starts, imported days included. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime(),localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
// Imported days 12..5 days back, live days 4..0 back; one day (3 back) holds both.
function fixture(imported=true){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 const daily=[[4,'live',1000],[3,'live',500],[1,'live',200],[0,'live',100]];
 if(imported)daily.unshift([12,'import',300],[10,'import',400],[6,'import',800],[3,'import',250]);
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(imported?12:4),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:daily.map(([back,origin,n])=>({at:localDay(back),source:'codex',origin,observedOutputTokens:n})),hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}
test('HIST-IMP-05 imported days move the start of the totals row and leave no origin marker on the overview',async({page})=>{
 await open(page,fixture());
 await expect(page.locator('.ov-top .lbl').first()).toHaveText('since 10-23');
 await expect(page.locator('.ov-top .ov-total')).toHaveText('4k');
 await expect(page.locator('.pg-overview [data-imported], .pg-overview .ov-from, .pg-overview .hm.imp')).toHaveCount(0);
 await open(page,fixture(),'zh-CN');
 await expect(page.locator('.ov-top .lbl').first()).toHaveText('自 10-23 起');
});

test('HIST-IMP-05 without imported data the totals row starts at the first live day',async({page})=>{
 await open(page,fixture(false));
 await expect(page.locator('.ov-top .lbl').first()).toHaveText('since 10-31');
 await expect(page.locator('.ov-top .ov-total')).toHaveText('2k');
});
