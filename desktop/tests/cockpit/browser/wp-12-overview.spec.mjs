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
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
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

test('WP-12 CKP-MFD-62 the Grid key is not lit and pressing it changes nothing',async({page})=>{
 await open(page,recorded(60));
 const grid=page.locator('[data-opt="chart"] b',{hasText:/^Grid$/});
 await expect(grid).not.toHaveClass(/\bon\b/);await grid.click();
 await expect(page.locator('[data-opt="chart"] b.on')).toHaveText('Bars');
 await expect(page.locator('.pg-overview svg.ov-heat')).toHaveCount(0);
});
