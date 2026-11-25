// SPDX-License-Identifier: MIT
// C-47 / D390: the Overview's day-by-hour heatmap, blue lower-effort advice and blue official-reset lines on the built page through its
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

// D390 (CKP-MFD-62): the Grid key draws the current range as days (columns) by four-hour bands (rows). The wire keeps
// hourly rows for today and yesterday only, so older days have no cell.
const hours=[[0,9,500],[0,10,300],[1,22,1000],[1,23,400],[1,14,0]];
function hourly(){
 const data=history();
 data.history.hourly=hours.map(([back,h,n])=>({at:new Date(2026,10,4-back,h).toISOString(),source:'codex',origin:'live',observedOutputTokens:n}));
 return data;
}
test('CKP-MFD-62 the Grid key draws days by four-hour bands for the 7-day range, with tips',async({page})=>{
 await open(page,hourly());await grid(page);
 const heat=page.locator('.pg-overview svg.ov-heat');await expect(heat).toBeVisible();
 await expect(heat).toHaveAttribute('aria-label','Output tokens by day and hour, last 7 days');await expect(heat).not.toHaveClass(/\bvendor\b/);
 const cells=await heat.locator('rect.hm').evaluateAll(list=>list.map(e=>({x:Number(e.getAttribute('x')),y:Number(e.getAttribute('y')),step:[...e.classList].find(c=>/^s\d$/.test(c)),today:e.classList.contains('today'),tip:e.dataset.tip})));
 // Today 08-12h (800) and 20-24h yesterday (1400), plus yesterday's recorded zero 12-16h.
 expect(cells.length).toBe(3);expect(new Set(cells.map(c=>c.x)).size).toBe(2);
 expect(cells.find(c=>c.tip.startsWith('Nov 4')).tip).toBe('Nov 4 08:00-12:00\nCodex 800');
 expect(cells.find(c=>c.step==='s0')).toBeTruthy();
 await expect(page.locator('[data-opt="range"]')).toHaveCount(1);await expect(page.locator('[data-opt="stack"]')).toHaveCount(0);
});

test('CKP-MFD-62 hovering a heatmap cell shows its day, hours and the tokens per subscription',async({page})=>{
 await open(page,hourly());await grid(page);
 const tip=page.locator('.dk-mfd .mfd-tip');await expect(tip).toBeHidden();
 await page.locator('.ov-heat rect.hm[data-tip^="Nov 4"]').hover();
 await expect(tip).toBeVisible();await expect(tip.locator('span')).toHaveText(['Nov 4 08:00-12:00','Codex 800']);
 await page.mouse.move(2,2);await expect(tip).toBeHidden();
});

test('CKP-MFD-62 a subscription scope draws the heatmap in its vendor colour',async({page})=>{
 await open(page,hourly());await page.keyboard.press('1');await grid(page);
 const heat=page.locator('.pg-overview svg.ov-heat');await expect(heat).toHaveClass(/\bvendor\b/);
 const hv=await heat.evaluate(e=>e.style.getPropertyValue('--hv'));expect(hv).toMatch(/^#[0-9a-f]{6}$/i);
 const rgb=`rgb(${[1,3,5].map(i=>parseInt(hv.slice(i,i+2),16)).join(', ')})`;
 expect(await heat.locator('rect.hm.s4').first().evaluate(e=>getComputedStyle(e).fill)).toBe(rgb);
 await page.keyboard.press('0');
 expect(await page.locator('.pg-overview svg.ov-heat rect.hm.s4').first().evaluate(e=>getComputedStyle(e).fill)).not.toBe(rgb);
});

test('CKP-MFD-62 without hourly rows the grid says there is no hourly record, and Chinese reads 点阵',async({page})=>{
 await open(page,history(),'zh-CN');
 await page.locator('[data-opt="chart"] b',{hasText:/^点阵$/}).click();
 await expect(page.locator('.pg-overview svg.ov-heat')).toHaveCount(0);
 await expect(page.locator('.pg-overview .ov-heat-empty')).toContainText('小时');
});

// macrevb-1212-1: a 25-hour fall-back day. America/Los_Angeles falls back on 2026-11-01 01:00 PDT -> 01:00 PST; at 23:30 on
// Nov 2 the producer still sends yesterday's 00:00 PDT bucket and both 01:00 readings. All of them land in yesterday's 00:00-04:00
// cell, in the 7-day and the 30-day range, and no earlier cell exists.
test.describe('D390 fall-back day',()=>{
 test.use({timezoneId:'America/Los_Angeles'});
 for(const range of ['7d','30d'])
 test(`CKP-MFD-62 the Grid keeps yesterday's 00:00 and both 01:00 readings of a 25-hour day (${range})`,async({page})=>{
  const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
  data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:'2026-10-01',
   subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
   models:ranking,tools:ranking,daily:[{at:'2026-11-01',source:'codex',origin:'live',observedOutputTokens:1000},{at:'2026-11-02',source:'codex',origin:'live',observedOutputTokens:50}],
   hourly:[['2026-11-01T07:00:00Z',500],['2026-11-01T08:00:00Z',300],['2026-11-01T09:00:00Z',200],['2026-11-03T06:00:00Z',50]].map(([at,n])=>({at,source:'codex',origin:'live',observedOutputTokens:n})),
   projects:{recent7d:[],recent30d:[]},cycles:[]};
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.clock.setFixedTime(new Date('2026-11-03T07:30:00Z'));
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell:{...shell,range},redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data}))).toBe(true);
  await grid(page);
  const tips=await page.locator('.pg-overview svg.ov-heat rect.hm').evaluateAll(list=>list.map(e=>e.dataset.tip));
  expect(tips).toEqual(['Nov 1 00:00-04:00\nCodex 1k','Nov 2 20:00-24:00\nCodex 50']);
 });
});

// macrevb-1212-3: Australia/Lord_Howe falls back 30 minutes on 2026-04-05. At 23:30 on Apr 6 the producer sends yesterday's
// 04:00 LHST bucket (17:30Z); it must land in the 04:00-08:00 cell, with no 00:00-04:00 cell.
test.describe('D390 half-hour fall-back',()=>{
 test.use({timezoneId:'Australia/Lord_Howe'});
 for(const range of ['7d','30d'])
 test(`CKP-MFD-62 the Grid labels a 04:00 LHST record 04:00-08:00 (${range})`,async({page})=>{
  const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
  data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:'2026-04-01',
   subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
   models:ranking,tools:ranking,daily:[{at:'2026-04-05',source:'codex',origin:'live',observedOutputTokens:500}],
   hourly:[{at:'2026-04-04T17:30:00Z',source:'codex',origin:'live',observedOutputTokens:500}],
   projects:{recent7d:[],recent30d:[]},cycles:[]};
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.clock.setFixedTime(new Date('2026-04-06T13:00:00Z'));
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell:{...shell,range},redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data}))).toBe(true);
  await grid(page);
  const tips=await page.locator('.pg-overview svg.ov-heat rect.hm').evaluateAll(list=>list.map(e=>e.dataset.tip));
  expect(tips).toEqual(['Apr 5 04:00-08:00\nCodex 500']);
 });
});

// macrevb-1212-2: on a fresh record the lit Grid key says its own hourly empty state; Bars keeps its existing one.
test('CKP-MFD-62 a fresh Overview: Grid shows the hourly empty line with no cells, Bars its own empty state',async({page})=>{
 const data=visualFixture().data;delete data.history;
 for(const s of data.details.subscriptions)s.today=[];
 await open(page,data);
 await expect(page.locator('.pg-overview .ov-empty')).toHaveCount(1);
 await grid(page);
 await expect(page.locator('[data-opt="chart"] b.on')).toHaveText('Grid');
 await expect(page.locator('.pg-overview .ov-heat-empty')).toBeVisible();await expect(page.locator('.pg-overview .ov-heat-empty')).toContainText('hourly');
 await expect(page.locator('.pg-overview rect.hm')).toHaveCount(0);await expect(page.locator('.pg-overview .ov-empty')).toHaveCount(0);
 await page.locator('[data-opt="chart"] b',{hasText:/^Bars$/}).click();
 await expect(page.locator('[data-opt="chart"] b.on')).toHaveText('Bars');
 await expect(page.locator('.pg-overview .ov-empty')).toHaveCount(1);await expect(page.locator('.pg-overview .ov-heat-empty')).toHaveCount(0);
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
 ['an announced window reads its middle, to the half hour','announced',window_(2,4.2),'●Codex official reset card · ~in 3h00','●Codex 官方重置卡 · 约 3h00后'],
 ['an approximate time reads that time','announced',window_(5,5,'approximate'),'●Codex official reset card · ~in 5h00','●Codex 官方重置卡 · 约 5h00后'],
 ['a date-only announcement has no time to show','announced',window_(12,35.9,'date'),'●Codex official reset card · time TBA','●Codex 官方重置卡 · 待定'],
 ['an announcement without a schedule','announced',null,'●Codex official reset card · time TBA','●Codex 官方重置卡 · 待定'],
 ['a confirmed reset','confirmed',window_(-2,-1),'●Codex official reset card confirmed','●Codex 官方重置卡已确认'],
])test(`CKP-MFD-28 ${name}, blue and list-only`,async({page})=>{
 const {send,receive}=await open(page,reset(status,schedule));
 await expect(blue(page)).toHaveText(en);
 await expect(page.locator('[data-caution]')).not.toHaveClass(/\b(lit|red|amber)\b/);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(blue(page)).toHaveText(zh);
});
