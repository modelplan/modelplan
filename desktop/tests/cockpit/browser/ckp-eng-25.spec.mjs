// SPDX-License-Identifier: MIT
// CKP-ENG-25 (owner D37): with one to three subscriptions the engine columns are wide and add a 7-day history and a
// reset timeline. Built page through its normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=new Date(2026,10,4,12).getTime(),localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,data,query='?few=b') {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/'+query+(query?'&':'?')+'pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale:'en'},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:40,observedRequests:3,eligibleRequests:3});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function fixture(days,count=3) {
 const data=visualFixture().data;
 data.projection.rows=data.projection.rows.slice(0,count);data.subscriptions=data.subscriptions.slice(0,count);data.details.subscriptions=data.details.subscriptions.slice(0,count);
 const ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(9),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1200),recent30d:sums(4800)}]}],
  models:ranking,tools:ranking,daily:days.map(back=>({at:localDay(back),source:'codex',observedOutputTokens:100+back*50})),hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}

test('CKP-ENG-25 up to three subscriptions get wide columns with a history and a reset timeline',async({page})=>{
 await open(page,fixture([0,1,2,3,4,5,6]));
 const lcd=page.locator('.eng-lcd.few-rich');await expect(lcd).toHaveCount(1);
 const columns=page.locator('.eng-cols > .ec[data-col]'),n=await columns.count();expect(n).toBeGreaterThan(0);expect(n).toBeLessThanOrEqual(3);
 await expect(page.locator('.eng-detail')).toHaveCount(n);await expect(page.locator('.eng-reset')).toHaveCount(n);
 // The detail sits in the right part of its column, beside the table.
 const column=await columns.first().boundingBox(),detail=await columns.first().locator('.eng-detail').boundingBox();
 expect(detail.x).toBeGreaterThan(column.x+column.width*0.5);expect(detail.x+detail.width).toBeLessThanOrEqual(column.x+column.width+1);
});

test('CKP-ENG-25 seven recorded days draw the history, today last',async({page})=>{
 await open(page,fixture([0,1,2,3,4,5,6]));
 const points=await page.locator('.eng-history polyline').first().getAttribute('points');
 const ys=points.trim().split(/\s+/).map(p=>Number(p.split(',')[1]));
 expect(ys).toHaveLength(7);expect(ys[6]).toBeGreaterThan(ys[0]); // the oldest day is the largest, so it sits highest (smallest y)
});

test('CKP-ENG-25 a missing day leaves the history unplotted, never a zero',async({page})=>{
 await open(page,fixture([0,1,2,4,5,6]));
 await expect(page.locator('.eng-history').first()).toBeVisible();
 await expect(page.locator('.eng-history polyline')).toHaveCount(0);
});

test('CKP-ENG-25 a day recorded with zero tokens counts as zero; the history is still drawn',async({page})=>{
 const data=fixture([0,1,2,3,4,5,6]);data.history.daily.find(d=>d.at===localDay(3)).observedOutputTokens=0;
 await open(page,data);
 const points=await page.locator('.eng-history polyline').first().getAttribute('points');
 expect(points.trim().split(/\s+/)).toHaveLength(7);
});

test('CKP-ENG-25 the default keeps three bays until the owner decides',async({page})=>{
 await open(page,fixture([0,1,2,3,4,5,6]),'');
 await expect(page.locator('.eng-lcd.few-rich')).toHaveCount(0);await expect(page.locator('.eng-detail')).toHaveCount(0);
});
