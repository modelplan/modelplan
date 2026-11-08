// SPDX-License-Identifier: MIT
// D59: the Subscription page's "7 | 30" usage key and its cycle key work on the built page through the normal bridge
// (CKP-MFD-14, CKP-MFD-15). The 30-day usage comes from cockpitHistoryV1; a daily credits history does not exist
// yet, so that total stays unknown. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime();
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const sums=(out,input,tps)=>({inputTokens:input,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:tps,observedRequests:3,eligibleRequests:3});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function fixture(){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef,at=d=>new Date(NOW-d*864e5).toISOString();
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1200,300,40),recent30d:sums(48000,9000,35)}]}],
  models:ranking,tools:ranking,daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},
  cycles:[{subscriptionRef:ref,kind:'five_hour',attribution:'unattributed',cycles:[{startedAt:at(3),resetsAt:at(2.8),points:40,hadDrop:false,spent:[]}]},
   {subscriptionRef:ref,kind:'weekly',attribution:'unattributed',cycles:[{startedAt:at(9),resetsAt:at(2),points:70,hadDrop:false,spent:[]},{startedAt:at(16),resetsAt:at(9),points:55,hadDrop:false,spent:[]}]}]};
 return data;
}
const subscription=async page=>{await page.keyboard.press('1');await page.getByRole('button',{name:'Subscription',exact:true}).click();};

test('D59 the 7 | 30 key switches the usage block between the 7- and 30-day records',async({page})=>{
 await open(page,fixture());await subscription(page);
 const stats=page.locator('.sp-stats'),key=page.locator('[data-opt="usage"]');
 await expect(stats).toHaveAttribute('data-days','7');await expect(stats).toContainText('1k');await expect(stats).toContainText('40 t/s');
 await expect(key.locator('b.on')).toHaveText('7');
 await key.locator('b',{hasText:/^30$/}).click();
 await expect(stats).toHaveAttribute('data-days','30');await expect(stats).toContainText('48k');await expect(stats).toContainText('35 t/s');
 await expect(key.locator('b.on')).toHaveText('30');
 // A press on the key itself flips it back.
 await key.click({position:{x:2,y:2}});await expect(stats).toHaveAttribute('data-days','7');
});

test('D59 the cycle key switches the history between the 5h and weekly windows',async({page})=>{
 await open(page,fixture());await subscription(page);
 await page.locator('[data-opt="tab"] b').nth(1).click();
 const key=page.locator('[data-opt="cycle"]');await expect(key).toBeVisible();
 await expect(page.locator('.sec em').first()).toHaveText('5h');await expect(page.locator('.cy')).toHaveCount(1);
 // The bars carry the subscription's colour (the inline --cv the page policy drops is applied again).
 expect(await page.locator('svg.cy-chart').evaluate(e=>e.style.getPropertyValue('--cv'))).toMatch(/^#[0-9a-f]{6}$/i);
 await key.locator('b').nth(1).click();
 await expect(page.locator('.sec em').first()).toHaveText('Weekly');await expect(page.locator('.cy')).toHaveCount(2);
 await expect(key.locator('b.on')).toHaveText('Weekly');
 await key.locator('b').nth(0).click();await expect(page.locator('.cy')).toHaveCount(1);
});

test('D59 the 30-day credits total stays unknown without a daily credits history',async({page})=>{
 const data=fixture();data.details.subscriptions[0].credits={balance:1200,observedAt:new Date(NOW-6e4).toISOString()};
 await open(page,data);await subscription(page);
 await expect(page.locator('.mfd-page .cr-bal')).toHaveText('1,200');
 await expect(page.locator('.mfd-page .cr-30-unknown')).toHaveText('30 d --');
 await expect(page.locator('.mfd-page svg.cr-30')).toHaveCount(0);
 // Credits belong to Now; the History tab shows resets and cycles only.
 await page.locator('[data-opt="tab"] b').nth(1).click();
 await expect(page.locator('.mfd-page .cr-bal')).toHaveCount(0);await expect(page.locator('.mfd-page .cr-30-unknown')).toHaveCount(0);
});
