// SPDX-License-Identifier: MIT
// G3-109 (build 14e): a balance-only subscription with an "other" window (Grok Build) in a six-column engine table.
// No raw copy key reaches the column text, the text never runs past its column, and the Overview scoped to that
// subscription shows its balance and why there is no usage percentage instead of an empty page. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date('2026-10-29T12:30:00Z');
function fixture(history=false){
 const data=visualFixture().data,rows=data.projection.rows,base=rows[0];
 const clone=(id,name)=>{const row=structuredClone(base);row.id=id;row.name={en:name,zh:name};row.vendorKey=null;for(const a of row.accounts){a.subscriptionRef=null;a.accountLocator=null;}return row;};
 const grok=clone('grok','Grok Build'),account=grok.accounts[0];
 delete account.resetCards;delete account.today;delete account.activity;
 account.plan={id:'grok',name:{en:'X Subscription',zh:'X 订阅'}};
 account.credits={balance:12.34,unit:'money',currency:'USD'};
 account.windows=[{source:'saved_login',id:'other:unknown:other:other',role:'other',durationSeconds:null,label:{en:'Other limit',zh:'其他限额'},limitKey:'other',poolKey:'other',resetMode:'unknown',remainingPercent:null,resetsAt:null,observedAt:'2026-10-29T12:00:00Z',current:true,validUntil:'2030-01-01T00:00:00Z'}];
 // macrev2-925-1: a verified Grok subscription whose local history has a recorded day, so the Overview draws its chart.
 if(history){
  const ref='000000000000000f';account.subscriptionRef=ref;account.accountLocator=ref;
  data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:'grok',account:structuredClone(account)}]});
  const sums={inputTokens:null,outputTokens:200,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1};
  const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
  data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:'2026-10-28',subscriptions:[{subscriptionRef:ref,sources:[{source:'grok',bindingBasis:'source-wide-current-binding',recent7d:sums,recent30d:sums}]}],models:ranking,tools:ranking,daily:[{at:'2026-10-29',source:'grok',origin:'live',observedOutputTokens:200}],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};
 }
 rows.push(grok,clone('spare','Spare'));
 return data;
}
async function open(page,locale,history=false){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(NOW);
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fixture(history)}))).toBe(true);
}

for(const locale of ['zh-CN','en'])test(`G3-109 six columns: no raw key, no overflow (${locale})`,async({page})=>{
 await open(page,locale);
 await expect(page.locator('.u11-engine-table .eng-cols > .ec[data-col]')).toHaveCount(6);
 const texts=await page.locator('.u11-engine-table .qtxt').evaluateAll(list=>list.map(e=>{const col=e.closest('.ec').getBoundingClientRect(),r=e.getBoundingClientRect();
  return {text:e.textContent,sw:e.scrollWidth,cw:e.clientWidth,short:e.dataset.short,small:e.dataset.small,fits:e.scrollWidth<=e.clientWidth+1,inside:r.left>=col.left-1&&r.right<=col.right+1};}));
 expect(texts.length).toBeGreaterThan(0);
 for(const x of texts){expect(x.text).not.toMatch(/\b(?:extra|eng)\.[a-z.]+/);expect(x,JSON.stringify(x)).toMatchObject({fits:true,inside:true});}
});

for(const [locale,balance,note] of [['en','$12.34',/balance, no usage/],['zh-CN','US$12.34',/只报告余额/]])
 test(`G3-109 Overview for a balance-only subscription shows its balance (${locale})`,async({page})=>{
  await open(page,locale);
  await page.keyboard.press('5');
  const overview=page.locator('.mfd-page.pg-overview');
  await expect(overview.locator('.ov-bal b')).toHaveText(balance);
  await expect(overview.locator('.ov-bal-note')).toHaveText(note);
  await expect(overview.locator('.mp-empty')).toHaveCount(0);
 });

// macrev2-925-1: recorded token history removes the empty state; the balance and its note still show, and the history stays.
for(const [locale,balance,note] of [['en','$12.34',/balance, no usage/],['zh-CN','US$12.34',/只报告余额/]])
 test(`G3-109 Overview for a balance-only subscription with token history shows its balance and the history (${locale})`,async({page})=>{
  await open(page,locale,true);
  await page.keyboard.press('5');
  const overview=page.locator('.mfd-page.pg-overview');
  await expect(overview.locator('.ov-top .ov-local')).toHaveCount(1);
  await expect(overview.locator('.ov-top .ov-sum')).toHaveText('200');
  await expect(overview.locator('.ov-bal b')).toHaveText(balance);
  await expect(overview.locator('.ov-bal-note')).toHaveText(note);
 });

for(const [locale,full,value] of [['en','Balance $12.34','$12.34'],['zh-CN','余额 US$12.34','US$12.34']])
 test(`G3-109 the engine column's reserve row shows a money balance in its currency (${locale})`,async({page})=>{
  await open(page,locale);
  const grok=page.locator('.u11-engine-table .ec[data-col]').nth(4).locator('.qrv-p');
  await expect(grok).toHaveAttribute('data-full',full);
  const shown=await grok.evaluate(e=>({text:e.textContent,fits:e.scrollWidth<=e.clientWidth+1}));
  expect([full,value]).toContain(shown.text);expect(shown.fits).toBe(true);
 });
