// SPDX-License-Identifier: MIT
// Owner build 6 (2026-11-27): the Overview's alert lines are capped so the chart keeps at least 55% of the page body, and the rest
// collapse into one "+N ▸" line that opens the full list; a tooltip never covers the totals headline. Built page, synthetic data.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {alertBudget,CHART_MIN_SHARE} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime(),H=36e5;
const localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
// Priced usage (so the bars exist) and n confirmed resets, one alert line each.
function withAlerts(n){
 const data=visualFixture().data,row=data.projection.rows[0],ref=row.accounts[0].subscriptionRef;
 data.details.resetEvents=Array.from({length:n},(_,i)=>({version:1,id:'synthetic-reset-'+i,provider:'openai',rowId:row.id,status:'confirmed',publishedAt:new Date(NOW-H).toISOString(),expiresAt:new Date(NOW+48*H).toISOString(),
  source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}));
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(60),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:[{at:localDay(1),source:'codex',origin:'live',observedOutputTokens:1000},{at:localDay(0),source:'codex',origin:'live',observedOutputTokens:200}],hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[],
  cost:{basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-01',models:{today:[],recent7d:[],recent30d:[]},hourly:[],
   daily:[{at:localDay(1),source:'codex',estimatedUsd:6,pricedTokens:900,unpricedTokens:100},{at:localDay(0),source:'codex',estimatedUsd:3,pricedTokens:180,unpricedTokens:20}]}};
 return data;
}
async function open(page,data,locale){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const box=(page,sel)=>page.locator(sel).first().evaluate(e=>{const r=e.getBoundingClientRect();return {top:r.top,bottom:r.bottom,left:r.left,right:r.right,height:r.height};});

test('the alert budget is two lines on the build-6 screen, three at most however tall, and never below two',()=>{
 expect(alertBudget(209)).toBe(2);expect(alertBudget(120)).toBe(2);expect(alertBudget(600)).toBe(3);expect(CHART_MIN_SHARE).toBe(.55);
});

for(const locale of ['en','zh-CN'])
 for(const [n,lines,more] of [[0,0,null],[2,2,null],[5,2,'+4'],[8,2,'+7']])
  test(`b6: ${n} alerts keep the chart at 55% of the page, ${more?`one alert and "${more} ▸"`:`${n} line(s), no "+N"`} (${locale})`,async({page})=>{
   await open(page,withAlerts(n),locale);
   const li=page.locator('.pg-overview .mfd-alerts li');await expect(li).toHaveCount(lines);
   if(more){await expect(li.last()).toHaveClass(/\bal-more\b/);await expect(li.last()).toHaveText(more+' ▸');}
   else await expect(page.locator('.pg-overview .al-more')).toHaveCount(0);
   const chart=await box(page,'.pg-overview .mfd-fill'),body=await box(page,'.pg-overview');
   expect(chart.height).toBeGreaterThanOrEqual(body.height*CHART_MIN_SHARE-1);
   if(more){ // the "+N" line opens the full list, which holds every alert
    await li.last().locator('button').click();
    await expect(page.locator('.mfd-alerts.all li')).toHaveCount(n);
   }
  });

for(const locale of ['en','zh-CN'])
 test(`b6: the "On this Mac" tooltip sits below the totals row, never over its headline (${locale})`,async({page})=>{
  await open(page,withAlerts(2),locale);
  const top=page.locator('.pg-overview .ov-top');
  await top.hover({position:{x:6,y:6}});
  const tip=page.locator('.dk-mfd .mfd-tip');await expect(tip).toBeVisible();
  const t=await box(page,'.dk-mfd .mfd-tip'),r=await box(page,'.pg-overview .ov-top');
  expect(t.top).toBeGreaterThanOrEqual(r.bottom-.5);
 });

for(const locale of ['en','zh-CN'])
 for(const n of [1,2])
  test(`b6: an alert line's tooltip never covers the totals headline, with ${n} alert(s) (${locale})`,async({page})=>{
   await open(page,withAlerts(n),locale);
   const rows=page.locator('.pg-overview .mfd-alerts li[data-tip]');await expect(rows).toHaveCount(n);
   const first=await box(page,'.pg-overview .mfd-alerts li[data-tip]');
   await page.mouse.move(first.left+6,(first.top+first.bottom)/2);
   await expect(page.locator('.dk-mfd .mfd-tip')).toBeVisible();
   const t=await box(page,'.dk-mfd .mfd-tip'),head=await box(page,'.pg-overview .ov-top');
   expect(t.bottom<=head.top+.5||t.top>=head.bottom-.5).toBe(true);
   await expect(page.locator('.dk-mfd .mfd-tip')).not.toBeEmpty();
   // the totals row's own tip still sits below it when space permits
   await page.mouse.move(head.left+6,head.top+6);
   const own=await box(page,'.dk-mfd .mfd-tip');
   expect(own.top).toBeGreaterThanOrEqual(head.bottom-.5);
  });
