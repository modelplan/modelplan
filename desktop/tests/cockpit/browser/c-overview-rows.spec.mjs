// SPDX-License-Identifier: MIT
// C-47: the Overview's heatmap, blue lower-effort advice and blue official-reset lines on the built page through its
// normal bridge (CKP-MFD-08, CKP-MFD-27, CKP-MFD-28). Synthetic data only.
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
// Days with observed output (days back, tokens). A listed zero is a known zero; an unlisted day has no record.
const DAYS=[[0,200],[1,1000],[2,0],[3,4000],[5,9000],[8,20000],[12,600],[20,3000],[39,1500]];
function history(dailyFrom=localDay(39)){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom,
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:DAYS.map(([back,n])=>({at:localDay(back),source:'codex',origin:'live',observedOutputTokens:n})),hourly:[],
  projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}
const grid=page=>page.locator('[data-opt="chart"] b',{hasText:/^Grid$/}).click();

test('CKP-MFD-08 the Grid key draws the 26-week heatmap with five neutral steps in All',async({page})=>{
 await open(page,history());await grid(page);
 const heat=page.locator('.pg-overview svg.ov-heat');await expect(heat).toBeVisible();
 await expect(heat).toHaveAttribute('aria-label','Daily output tokens, last 26 weeks');await expect(heat).not.toHaveClass(/\bvendor\b/);
 const cells=await heat.locator('rect.hm').evaluateAll(list=>list.map(e=>({x:Number(e.getAttribute('x')),y:Number(e.getAttribute('y')),w:Number(e.getAttribute('width')),step:[...e.classList].find(c=>/^s\d$/.test(c)),today:e.classList.contains('today'),tip:e.dataset.tip})));
 // One cell per recorded day; unrecorded days, before or after the record began, have no cell.
 expect(cells.length).toBe(DAYS.length);
 expect(new Set(cells.map(c=>c.step))).toEqual(new Set(['s0','s1','s2','s3','s4']));
 const pitch=cells[0].w+2,cols=cells.map(c=>Math.round(c.x/pitch)),rows=new Set(cells.map(c=>c.y));
 expect(Math.max(...cols)).toBe(25);expect(rows.size).toBeLessThanOrEqual(7);
 expect(cells[0].w).toBeGreaterThanOrEqual(5);expect(cells[0].w).toBeLessThanOrEqual(14);
 const today=cells.filter(c=>c.today);expect(today.length).toBe(1);expect(today[0].tip).toBe('Nov 4\nCodex 200');
 // The record began inside the 26 weeks: the started-on line says so.
 await expect(page.locator('.pg-overview .hm-since')).toHaveText('Recorded since Sep 26');
 // The 7/30 and split/stacked keys belong to the bars only.
 await expect(page.locator('[data-opt="days"]')).toHaveCount(0);await expect(page.locator('[data-opt="stack"]')).toHaveCount(0);
});

test('CKP-MFD-08 hovering a heatmap cell shows its date and the tokens per subscription',async({page})=>{
 await open(page,history());await grid(page);
 const tip=page.locator('.dk-mfd .mfd-tip');await expect(tip).toBeHidden();
 await page.locator('.ov-heat rect.hm.today').hover();
 await expect(tip).toBeVisible();await expect(tip.locator('span')).toHaveText(['Nov 4','Codex 200']);await expect(tip.locator('span').first()).toHaveClass('h');
 const box=await tip.boundingBox(),screen=await page.locator('.dk-mfd .mfd-screen').boundingBox();
 expect(box.x).toBeGreaterThanOrEqual(screen.x);expect(box.x+box.width).toBeLessThanOrEqual(screen.x+screen.width+0.5);
 await page.mouse.move(2,2);await expect(tip).toBeHidden();
 // The bars' buckets use the same tooltip.
 await page.locator('[data-opt="chart"] b',{hasText:/^Bars$/}).click();
 await page.locator('.ov-bucket').last().hover();await expect(tip).toBeVisible();await expect(tip).toContainText('Codex');
});

test('CKP-MFD-08 a subscription scope draws the heatmap in its vendor colour',async({page})=>{
 await open(page,history());await page.keyboard.press('1');await grid(page);
 const heat=page.locator('.pg-overview svg.ov-heat');await expect(heat).toHaveClass(/\bvendor\b/);
 const hv=await heat.evaluate(e=>e.style.getPropertyValue('--hv'));expect(hv).toMatch(/^#[0-9a-f]{6}$/i);
 const rgb=`rgb(${[1,3,5].map(i=>parseInt(hv.slice(i,i+2),16)).join(', ')})`;
 expect(await heat.locator('rect.hm.s4').first().evaluate(e=>getComputedStyle(e).fill)).toBe(rgb);
 // Placed by the measured area, not left at the corner: the CSP-dropped inline position is applied again.
 expect(await heat.evaluate(e=>e.style.left)).toMatch(/^\d+px$/);
 await page.keyboard.press('0');
 const ink=await page.locator('.pg-overview svg.ov-heat').evaluate(e=>({fill:getComputedStyle(e.querySelector('rect.hm.s4')).fill,ink:getComputedStyle(e).getPropertyValue('--lcd-ink').trim()}));
 expect(ink.fill).not.toBe(rgb);
});

test('CKP-MFD-08 a record that began before the 26 weeks has no started-on line, and Chinese reads 点阵',async({page})=>{
 await open(page,history(localDay(181)),'zh-CN');
 await page.locator('[data-opt="chart"] b',{hasText:/^点阵$/}).click();
 await expect(page.locator('.pg-overview svg.ov-heat')).toHaveAttribute('aria-label','近 26 周每日输出 token');
 await expect(page.locator('.pg-overview .hm-since')).toHaveCount(0);
});

// CKP-MFD-27: a running session on a red quota above its model's recommended effort.
function advice({remaining=20,state='running',effort='high',bound=true}={}){
 const data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0];
 account.windows[0].remainingPercent=remaining;account.windows[0].resetsAt=new Date(NOW+3.5*H).toISOString();
 data.details.sessions=[{sessionRef:'00000000000000aa',source:'codex',subscriptionRef:bound?account.subscriptionRef:data.projection.rows[1].accounts[0].subscriptionRef,model:'model-a',effort,projectLabel:null,lastObservedAt:new Date(NOW-6e4).toISOString(),state,rate:null}];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[
  {id:'model-a',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null},{effort:'high',label:'High',star:false,ability:42,cost:4,time:null}]}]};
 return data;
}
const blue=page=>page.locator('.pg-overview .mfd-alerts li.al-blue');
test('CKP-MFD-27 a running session on a red quota gets one blue lower-effort line that does not light the lamp more',async({page})=>{
 await open(page,advice());
 await expect(page.locator('.pg-overview .mfd-alerts li').first()).toHaveClass(/\bal-red\b/);
 await expect(blue(page)).toHaveCount(1);await expect(blue(page)).toHaveText('●Synthetic A High→★Med ×0.50 cost, −2.0');
 await expect(page.locator('.pg-overview .mfd-alerts li.al-red')).toHaveCount(1);await expect(page.locator('.pg-overview .mfd-alerts li.al-amber')).toHaveCount(0);
 await expect(page.locator('[data-caution]')).toHaveClass(/\bred\b/);
 // The full list from the lamp carries it too.
 await page.locator('[data-caution]').click();await expect(page.locator('.mfd-alerts.all li.al-blue')).toHaveText('●Synthetic A High→★Med ×0.50 cost, −2.0');
});
test('CKP-MFD-27 Chinese advice line',async({page})=>{
 await open(page,advice(),'zh-CN');
 await expect(blue(page)).toHaveText('●Synthetic A High→★Med 成本×0.50 能力−2.0');
});
for(const [name,options] of [['an idle session',{state:'idle'}],['the recommended effort',{effort:'medium'}],['a lower effort',{effort:'low'}],['a quota above the red line',{remaining:40}],['another subscription',{bound:false}]])
 test(`CKP-MFD-27 no advice for ${name}`,async({page})=>{
  await open(page,advice(options));
  await expect(page.locator('.pg-overview')).toBeVisible();await expect(blue(page)).toHaveCount(0);
 });
test('CKP-MFD-27 no advice when the model is not published',async({page})=>{
 const data=advice();data.details.sessions[0].model='model-z';
 await open(page,data);await expect(page.locator('.pg-overview .mfd-alerts li.al-red')).toHaveCount(1);await expect(blue(page)).toHaveCount(0);
});

// CKP-MFD-28: a public reset with its expected time, from the announcement's schedule.
function reset(status,schedule){
 const data=visualFixture().data,row=data.projection.rows[0];
 data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:row.id,status,publishedAt:new Date(NOW-H).toISOString(),expiresAt:new Date(NOW+48*H).toISOString(),...(schedule?{schedule}:{}),source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 return data;
}
const window_=(a,b,precision='window')=>({from:new Date(NOW+a*H).toISOString(),through:new Date(NOW+b*H).toISOString(),precision});
for(const [name,status,schedule,en,zh] of [
 ['an announced window reads its middle, to the half hour','announced',window_(2,4.2),'●Codex official extra reset · ~in 3h00','●Codex 官方额外重置 · 约 3h00后'],
 ['an approximate time reads that time','announced',window_(5,5,'approximate'),'●Codex official extra reset · ~in 5h00','●Codex 官方额外重置 · 约 5h00后'],
 ['a date-only announcement has no time to show','announced',window_(12,35.9,'date'),'●Codex official extra reset · time TBA','●Codex 官方额外重置 · 待定'],
 ['an announcement without a schedule','announced',null,'●Codex official extra reset · time TBA','●Codex 官方额外重置 · 待定'],
 ['a confirmed reset','confirmed',window_(-2,-1),'●Codex official extra reset confirmed','●Codex 官方额外重置已确认'],
])test(`CKP-MFD-28 ${name}, blue and list-only`,async({page})=>{
 const {send,receive}=await open(page,reset(status,schedule));
 await expect(blue(page)).toHaveText(en);
 await expect(page.locator('[data-caution]')).not.toHaveClass(/\b(lit|red|amber)\b/);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(blue(page)).toHaveText(zh);
});
