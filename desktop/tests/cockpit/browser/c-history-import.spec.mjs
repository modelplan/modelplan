// SPDX-License-Identifier: MIT
// HIST-IMP-05 (D117): the 7- and 30-day views draw imported history exactly like live data (no lighter styling, no
// origin-based marker); only the hover note says which part was imported. Synthetic data only.
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
const bars=page=>page.locator('.ov-bucket').evaluateAll(list=>list.map(e=>({total:Number(e.dataset.total),imported:Number(e.dataset.imported||0),classes:e.getAttribute('class'),bars:[...e.querySelectorAll('.ov-bar')].map(b=>b.getAttribute('class'))})));

test('HIST-IMP-05 the 30-day bars of imported and live days look identical, with a hover note on imported ones',async({page})=>{
 await open(page,fixture());
 const b=await bars(page);expect(b.length).toBe(30);
 // Index 29 is today: 12 days back is index 17, 6 back is 23, 3 back is 26.
 expect([b[17].total,b[23].total,b[26].total,b[25].total,b[29].total]).toEqual([300,800,750,1000,100]);
 expect([b[17].imported,b[23].imported,b[26].imported,b[25].imported,b[29].imported]).toEqual([300,800,250,0,0]);
 for(const x of b){expect(x.classes).toBe('ov-bucket');for(const c of x.bars)expect(c).toBe('ov-bar');}
 expect(await page.locator('.ov-bucket').nth(26).getAttribute('data-tip')).toContain('incl. imported 250');
 expect(await page.locator('.ov-bucket').nth(23).getAttribute('data-tip')).toContain('Imported');
 expect(await page.locator('.ov-bucket').nth(25).getAttribute('data-tip')).not.toMatch(/mported/);
});

test('HIST-IMP-05 imported bars have the same fill and opacity as live bars',async({page})=>{
 await open(page,fixture());
 const style=await page.evaluate(()=>{const bar=i=>document.querySelectorAll('.ov-bucket')[i].querySelector('.ov-bar'),r=bar(23),l=bar(25);
  return {impFill:r.getAttribute('fill'),liveFill:l.getAttribute('fill'),impOpacity:getComputedStyle(r).opacity,liveOpacity:getComputedStyle(l).opacity};});
 expect(style.impFill).toBe(style.liveFill);expect(style.impOpacity).toBe(style.liveOpacity);
});

test('HIST-IMP-05 no import-boundary marker, label or origin wording on the chart, in English and Chinese',async({page})=>{
 await open(page,fixture());
 await expect(page.locator('.ov-chart .ov-from')).toHaveCount(0);
 await expect(page.locator('.ov-legend .ov-from-l')).toHaveCount(0);
 await expect(page.locator('.ov-chart')).not.toHaveAttribute('aria-label',/mported/);
 await open(page,fixture(),'zh-CN');
 await expect(page.locator('.ov-chart .ov-from')).toHaveCount(0);
 expect(await page.locator('.ov-bucket').nth(23).getAttribute('data-tip')).toContain('已导入');
});

test('HIST-IMP-05 the 7-day view draws imported days like live ones',async({page})=>{
 await open(page,fixture());
 await page.locator('[data-opt="days"] b',{hasText:/^7$/}).click();
 const b=await bars(page);expect(b.length).toBe(7);
 // 6 days back is the first bar and imported only.
 expect([b[0].total,b[0].imported]).toEqual([800,800]);
 for(const x of b){expect(x.classes).toBe('ov-bucket');for(const c of x.bars)expect(c).toBe('ov-bar');}
});

test('HIST-IMP-05 the grid view draws imported days like live ones',async({page})=>{
 await open(page,fixture());
 await page.locator('[data-opt="chart"] b',{hasText:/Grid/}).click();
 await expect(page.locator('.ov-heat .hm.imp')).toHaveCount(0);
 await expect(page.locator('.ov-heat')).not.toHaveAttribute('aria-label',/mported/);
 await expect(page.locator('.hm-since')).toHaveText('Recorded since Oct 23');
});

test('HIST-IMP-05 without imported data the views are as before',async({page})=>{
 await open(page,fixture(false));
 const b=await bars(page);expect(b.every(x=>x.imported===0&&x.classes==='ov-bucket')).toBe(true);
 await page.locator('[data-opt="chart"] b',{hasText:/Grid/}).click();
 await expect(page.locator('.ov-heat .hm.imp')).toHaveCount(0);
 await expect(page.locator('.hm-since')).toHaveText('Recorded since Oct 31');
});
