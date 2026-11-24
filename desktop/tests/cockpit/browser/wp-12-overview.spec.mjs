// SPDX-License-Identifier: MIT
// WP-12 (overview, option A): the alert rows, the totals row and the empty / loading / no-price states on the built
// page through its normal bridge (CKP-MFD-58…62). The bars themselves need ≈cost from the wire (WP-06) and are
// covered by unit/wp-12-overview-bars.test.mjs. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime(),H=36e5;
const localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,data,locale='en',tier='tall'){
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function recorded(sinceBack){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(sinceBack),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:[{at:localDay(1),source:'codex',origin:'live',observedOutputTokens:1000},{at:localDay(0),source:'codex',origin:'live',observedOutputTokens:200}],hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}
function resets(n){
 const data=visualFixture().data,row=data.projection.rows[0];
 data.details.resetEvents=Array.from({length:n},(_,i)=>({version:1,id:'synthetic-reset-'+i,provider:'openai',rowId:row.id,status:'confirmed',publishedAt:new Date(NOW-H).toISOString(),expiresAt:new Date(NOW+48*H).toISOString(),
  source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}));
 return data;
}
const rows=page=>page.locator('.pg-overview .mfd-alerts li');

test('sampling 11-22: Overview refresh is disabled until the native read completes',async({page})=>{
 const {send,receive}=await open(page,recorded(2));
 const refresh=page.locator('.pg-overview button[data-refresh]');
 await refresh.click();
 expect(await receive(send('shell',{...shell,refreshing:true}))).toBe(true);
 await expect(refresh).toBeDisabled();
 expect(await refresh.evaluate(e=>getComputedStyle(e).opacity)).toBe('0.5');
 await refresh.evaluate(e=>e.click());
 expect(await page.evaluate(()=>window.__events.filter(e=>e.action==='refreshMember').length)).toBe(1);
 expect(await receive(send('shell',{...shell,refreshing:false}))).toBe(true);
 await expect(refresh).toBeEnabled();
});

test('WP-12 CKP-MFD-58 five alerts show at most four lines, the last one "+N ▸"',async({page})=>{
 await open(page,resets(5));
 await expect(rows(page)).toHaveCount(4);
 await expect(rows(page).last()).toHaveClass(/\bal-more\b/);await expect(rows(page).last()).toHaveText('+2 ▸');
});
test('WP-12 CKP-MFD-58 four alerts fit without "+N"',async({page})=>{
 await open(page,resets(4));await expect(rows(page)).toHaveCount(4);await expect(page.locator('.pg-overview .al-more')).toHaveCount(0);
});

test('WP-12 CKP-MFD-59 a record shorter than the range says "since" on the totals row',async({page})=>{
 await open(page,recorded(2));
 await expect(page.locator('.pg-overview .ov-top .lbl').first()).toHaveText('since 11-02');
});
test('WP-12 CKP-MFD-59 a record longer than the range names the range',async({page})=>{
 await open(page,recorded(60));
 await expect(page.locator('.pg-overview .ov-top .lbl').first()).toHaveText('7d');
 await page.locator('[data-opt="range"] b',{hasText:/^30d$/}).click();
 await expect(page.locator('.pg-overview .ov-top .lbl').first()).toHaveText('30d');
});

test('WP-12 CKP-MFD-60 no price data draws no bars, only the token total',async({page})=>{
 await open(page,recorded(60));
 await expect(page.locator('.pg-overview svg.ov-chart')).toHaveCount(0);
 await expect(page.locator('.pg-overview .ov-top .ov-total')).toHaveText('1k');
});

test('WP-12 CKP-MFD-61 no usage record shows the three explanation lines',async({page})=>{
 const data=visualFixture().data;data.details.subscriptions.forEach(s=>{s.today=[];});
 await open(page,data);
 await expect(page.locator('.pg-overview .ov-empty b')).toHaveText('No usage record yet');
 await expect(page.locator('.pg-overview .ov-empty span')).toHaveText(['ModelPlan starts recording after install','Once you have used a tool, ≈cost and the daily bars show here']);
 await expect(page.locator('.pg-overview .ov-top')).toHaveCount(0);
});

test('WP-12 CKP-MFD-61 the first read shows a placeholder block, no totals',async({page})=>{
 const data=visualFixture().data;
 for(const row of data.projection.rows)for(const a of row.accounts){a.valueState='none';a.windows=[];}
 data.subscriptions=[];data.details.subscriptions=[];
 await open(page,data);
 await expect(page.locator('.pg-overview .ov-skel')).toHaveCount(1);await expect(page.locator('.pg-overview .ov-total')).toHaveCount(0);
});

test('WP-12 CKP-MFD-62 the Grid key switches to the day-by-hour heatmap and back to the bars, and the hint follows',async({page})=>{
 const data=recorded(60);data.history.hourly=[{at:new Date(2026,10,4,9).toISOString(),source:'codex',origin:'live',observedOutputTokens:500}];
 await open(page,data);
 const chart=page.locator('[data-opt="chart"]');
 await expect(chart.locator('b.on')).toHaveText('Bars');
 await page.locator('[data-opt="chart"] b',{hasText:/^Grid$/}).click();
 await expect(chart.locator('b.on')).toHaveText('Grid');
 await expect(page.locator('.pg-overview svg.ov-heat')).toHaveCount(1);await expect(page.locator('.pg-overview svg.ov-chart')).toHaveCount(0);
 await expect(chart).toHaveAttribute('data-tip',/hour/i);
 // The range key applies; the stack key belongs to the bars only.
 await expect(page.locator('[data-opt="range"]')).toHaveCount(1);await expect(page.locator('[data-opt="stack"]')).toHaveCount(0);
 await page.locator('[data-opt="chart"] b',{hasText:/^Bars$/}).click();
 await expect(chart.locator('b.on')).toHaveText('Bars');await expect(page.locator('.pg-overview svg.ov-heat')).toHaveCount(0);
 await expect(chart).toHaveAttribute('data-tip',/bar/i);await expect(page.locator('[data-opt="stack"]')).toHaveCount(1);
});

// CKP-MFD-60 through the wire's real cost section (WP-06, history.cost): bars, the ≈cost total and the unpriced note.
function priced(){
 const data=recorded(60);
 data.history.cost={basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-01',models:{today:[],recent7d:[],recent30d:[]},hourly:[],
  daily:[{at:localDay(1),source:'codex',estimatedUsd:6,pricedTokens:900,unpricedTokens:100},{at:localDay(0),source:'codex',estimatedUsd:3,pricedTokens:180,unpricedTokens:20}]};
 return data;
}
test('WP-12 CKP-MFD-60 wire cost draws one bar per day, the ≈cost total and the unpriced note',async({page})=>{
 await open(page,priced());
 await expect(page.locator('.pg-overview svg.ov-chart')).toHaveCount(1);
 await expect(page.locator('.pg-overview .ov-bucket')).toHaveCount(7);
 await expect(page.locator('.pg-overview .ov-top .ov-total')).toContainText('9');
 await expect(page.locator('.pg-overview .ov-note')).toContainText('has no public price');
});

test('sampling 11-22: compact overview keeps both chart axis labels above its footer',async({page})=>{
 const data=priced();data.details.resetEvents=resets(1).details.resetEvents;
 await open(page,data,'en','compact');
 const fill=page.locator('.pg-overview .mfd-fill'),labels=page.locator('.pg-overview .ov-chart .ov-ax');
 await expect(labels).toHaveCount(2);
 const bounds=await fill.boundingBox(),footer=await page.locator('.pg-overview .ov-foot').boundingBox();
 const boxes=await labels.evaluateAll(list=>list.map(e=>e.getBoundingClientRect().toJSON()));
 for(const box of boxes){
  expect(box.top,'axis top').toBeGreaterThanOrEqual(bounds.y-0.5);
  expect(box.bottom,'axis bottom').toBeLessThanOrEqual(Math.min(bounds.y+bounds.height,footer.y)+0.5);
 }
});

test('sampling 11-22: a full-height overview keeps the chart at its original height',async({page})=>{
 await open(page,priced(),'en','tall');
 const chart=page.locator('.pg-overview .ov-chart');
 await expect(chart).toHaveAttribute('height','110');
 const h=await chart.evaluate(e=>e.getBoundingClientRect().height);
 expect(h).toBeCloseTo(110,0);
});

// macrevc-1057-2: the alert budget follows the measured screen, tall and compact, and a change of size.
test('macrevc-1057-2 the compact screen shows one alert plus "+N ▸"; the tall one four lines; a size change redraws',async({page})=>{
 const {send,receive}=await open(page,resets(5),'en','compact');
 await expect(rows(page)).toHaveCount(2);await expect(rows(page).last()).toHaveClass(/\bal-more\b/);await expect(rows(page).last()).toHaveText('+4 ▸');
 await expect(rows(page)).toHaveCount(2);
});
test('macrevc-1057-2 a change of the screen size redraws the alert budget',async({page})=>{
 await open(page,resets(5));
 await expect(rows(page)).toHaveCount(4);
 const full=await page.locator('.pg-overview').evaluate(e=>e.clientHeight);
 await page.evaluate(h=>{const e=document.querySelector('.mfd-screen');e.style.setProperty('max-height',h+'px','important');e.style.setProperty('height',h+'px','important');},Math.round(full/2));
 await expect(rows(page)).toHaveCount(2);
});

// macrevc-1057-3: retained readings are not "cannot be read"; three truly unreadable ones merge.
function quiet(kind){
 const data=visualFixture().data;data.details.resetEvents=[];data.details.forecasts=[];
 for(const row of data.projection.rows)for(const w of row.accounts[0].windows){w.remainingPercent=90;w.resetsAt=new Date(NOW+6e5*60).toISOString();}
 for(const row of data.projection.rows.slice(0,3)){const c=row.accounts[0];
  if(kind==='retained'){c.valueState='retained';c.observedAt=new Date(NOW-125*6e4).toISOString();}
  else{c.valueState='none';c.windows=[];c.lastFailure={at:new Date(NOW-6e4).toISOString(),code:'not_signed_in'};}}
 return data;
}
test('macrevc-1057-3 three retained readings keep their own lines; three unreadable ones merge',async({page})=>{
 await open(page,quiet('retained'));
 await expect(rows(page)).toHaveCount(3);await expect(page.locator('.pg-overview .mfd-alerts')).not.toContainText('not read');
 await open(page,quiet('unreadable'));
 await expect(rows(page)).toHaveCount(1);await expect(rows(page).first()).toContainText('3 subscriptions not read');
});
