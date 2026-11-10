// SPDX-License-Identifier: MIT
// HIST-IMP-05 (D108): the 7- and 30-day views draw imported history lighter than live data and say where the data
// starts, through the page's normal bridge. Synthetic data only.
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
const bars=page=>page.locator('.ov-bucket').evaluateAll(list=>list.map(e=>({total:Number(e.dataset.total),imported:Number(e.dataset.imported||0),lighter:e.querySelectorAll('.ov-bar.imp').length})));

test('HIST-IMP-05 the 30-day bars draw an imported-only day lighter and a mixed day solid with a note',async({page})=>{
 await open(page,fixture());
 const b=await bars(page);expect(b.length).toBe(30);
 // Index 29 is today: 12 days back is index 17, 6 back is 23, 3 back is 26.
 expect(b[17]).toEqual({total:300,imported:300,lighter:1});
 expect(b[23]).toEqual({total:800,imported:800,lighter:1});
 expect(b[26]).toEqual({total:750,imported:250,lighter:0});
 expect(b[25]).toEqual({total:1000,imported:0,lighter:0});
 expect(b[29]).toEqual({total:100,imported:0,lighter:0});
 const tip=await page.locator('.ov-bucket').nth(26).getAttribute('data-tip');expect(tip).toContain('incl. imported 250');
 expect(await page.locator('.ov-bucket').nth(23).getAttribute('data-tip')).toContain('Imported');
});

test('HIST-IMP-05 the imported bars take the same hue at reduced opacity, with no new colour',async({page})=>{
 await open(page,fixture());
 const style=await page.evaluate(()=>{const r=document.querySelector('.ov-bar.imp'),l=document.querySelector('.ov-bar:not(.imp)');
  return {impFill:r.getAttribute('fill'),liveFill:l.getAttribute('fill'),impOpacity:getComputedStyle(r).opacity,liveOpacity:getComputedStyle(l).opacity};});
 expect(style.impFill).toBe(style.liveFill);expect(Number(style.impOpacity)).toBeLessThan(Number(style.liveOpacity));
});

test('HIST-IMP-05 a quiet marker says where the data starts, in English and Chinese',async({page})=>{
 await open(page,fixture());
 await expect(page.locator('.ov-chart .ov-from')).toHaveCount(1);
 await expect(page.locator('.ov-legend .ov-from-l')).toHaveText('Data from Oct 23');
 await expect(page.locator('.ov-chart')).toHaveAttribute('aria-label',/Lighter parts are earlier history imported/);
 await open(page,fixture(),'zh-CN');
 await expect(page.locator('.ov-legend .ov-from-l')).toContainText('数据始于');
});

test('HIST-IMP-05 no bucket tooltip covers the data-start label',async({page})=>{
 await open(page,fixture());
 const label=page.locator('.ov-legend .ov-from-l');await expect(label).toBeVisible();
 const buckets=page.locator('.ov-bucket');
 for(const i of [0,5,17,23,26,29]){
  await buckets.nth(i).hover();
  const tip=page.locator('.mfd-tip');await expect(tip).toBeVisible();
  const [a,b]=await Promise.all([tip.boundingBox(),label.boundingBox()]);
  const apart=a.x+a.width<=b.x||b.x+b.width<=a.x||a.y+a.height<=b.y||b.y+b.height<=a.y;
  expect(apart,`bucket ${i}: tooltip ${JSON.stringify(a)} label ${JSON.stringify(b)}`).toBe(true);
 }
});

test('HIST-IMP-05 the 7-day view shows imported days that fall inside it and no marker when data starts earlier',async({page})=>{
 await open(page,fixture());
 await page.locator('[data-opt="days"] b',{hasText:/^7$/}).click();
 const b=await bars(page);expect(b.length).toBe(7);
 // 6 days back is the first bar and imported only.
 expect(b[0]).toEqual({total:800,imported:800,lighter:1});
 await expect(page.locator('.ov-chart .ov-from')).toHaveCount(0);
});

test('HIST-IMP-05 the grid view lightens imported-only days and names where the data starts',async({page})=>{
 await open(page,fixture());
 await page.locator('[data-opt="chart"] b',{hasText:/Grid/}).click();
 expect(await page.locator('.ov-heat .hm.imp').count()).toBeGreaterThan(0);
 await expect(page.locator('.hm-since')).toHaveText('Data from Oct 23');
});

test('HIST-IMP-05 without imported data the views are as before',async({page})=>{
 await open(page,fixture(false));
 const b=await bars(page);expect(b.every(x=>x.imported===0&&x.lighter===0)).toBe(true);
 await expect(page.locator('.ov-chart .ov-from')).toHaveCount(0);
 await expect(page.locator('.ov-chart')).not.toHaveAttribute('aria-label',/imported/);
 await page.locator('[data-opt="chart"] b',{hasText:/Grid/}).click();
 await expect(page.locator('.ov-heat .hm.imp')).toHaveCount(0);
 await expect(page.locator('.hm-since')).toHaveText('Recorded since Oct 31');
});
