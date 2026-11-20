// SPDX-License-Identifier: MIT
// WP-13 (V1-FINAL 8.2-8.4, 14): the page keys, the Subscription page and the Models and Where pages, on the built page
// through its normal bridge. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,currentSample,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
// n subscriptions: the first n of the sample's four tool rows (each one a column of the quota table).
function dataFor(n){
 const data=currentSample();
 while(data.projection.rows.length<n){const row=structuredClone(data.projection.rows[0]);row.id='extra'+data.projection.rows.length;data.projection.rows.push(row);}
 data.projection.rows=data.projection.rows.slice(0,n);
 return data;
}
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}

test('CKP-MFD-63 the page keys read Overview, Plans, Models, Breakdown in that order; the effort page has no key',async({page})=>{
 await open(page,dataFor(2));
 expect(await page.locator('.mfd-pk .pk').evaluateAll(k=>k.map(b=>b.dataset.mfd))).toEqual(['page:overview','page:sub','page:tune','page:where']);
 expect(await page.locator('.mfd-pk .pk').allTextContents()).toEqual(['Overview','Plans','Models','Breakdown']);
 expect(await page.locator('.mfd-pk .pk').evaluateAll(k=>k.map(b=>b.getAttribute('aria-label')))).toEqual(['Overview','Plans','Models','Breakdown']);
});

test('CKP-MFD-63 the Chinese page keys read 总览 订阅 模型 去向',async({page})=>{
 await open(page,dataFor(2),'zh-CN');
 expect(await page.locator('.mfd-pk .pk').allTextContents()).toEqual(['总览','订阅','模型','去向']);
});

for(const n of [1,2])test(`CKP-MFD-64 with ${n} subscription(s) the Subscription page opens the first one expanded`,async({page})=>{
 await open(page,dataFor(n));await page.locator('[data-mfd="page:sub"]').click();
 await expect(page.locator('.mfd-page .sp-now .sp-h')).toBeVisible();
 await expect(page.locator('.mfd-page .sa-list')).toHaveCount(0);
});

for(const n of [3,4])test(`CKP-MFD-64 with ${n} subscriptions it lists one row each, and a row expands that subscription`,async({page})=>{
 await open(page,dataFor(n));await page.locator('[data-mfd="page:sub"]').click();
 await expect(page.locator('.mfd-page .sa-list .sa')).toHaveCount(n);
 await expect(page.locator('.mfd-page .sp-now')).toHaveCount(0);
 await page.locator('.mfd-page .sa-list .sa').nth(1).click();
 await expect(page.locator('.mfd-page .sp-now .sp-h')).toBeVisible();
});

// A published-model profile with a local history: Sol used 900 output tokens, Terra 100, the others none.
const ranking=top=>({entities:top.length,totalObservedOutputTokens:top.reduce((n,e)=>n+e.observedOutputTokens,0),top});
const entity=(name,tokens)=>({name,observedOutputTokens:tokens,observedRequests:1,share:0});
function withHistory(used=true){
 const data=build13Profile(),at=n=>{const d=new Date(Date.now()-n*864e5);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
 const top=used?[entity('gpt-6.1-sol',900),entity('gpt-6.1-terra',100)]:[],none={measure:'observed-output-tokens',attribution:'unattributed'};
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:at(3),subscriptions:[],daily:[],hourly:[],cycles:[],
  models:{...none,recent7d:ranking(top),recent30d:ranking(top)},tools:{...none,recent7d:ranking([]),recent30d:ranking([])},
  projects:{recent7d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[],recent30d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[]}};
 return data;
}

test('CKP-MFD-65 the Models page follows the header range: its title, rows and shares change with it',async({page})=>{
 const data=withHistory();data.history.models.recent30d=ranking([entity('gpt-6.1-terra',800),entity('gpt-6.1-sol',200)]);
 const {send,receive}=await open(page,data);await page.locator('[data-mfd="page:tune"]').click();
 const rows=page.locator('.mfd-page .md-list .md-row');
 await expect(page.locator('.mfd-page .md-h')).toHaveText('7d · 2 models');
 expect(await rows.evaluateAll(r=>r.slice(0,2).map(x=>x.dataset.model))).toEqual(['gpt-6.1-sol','gpt-6.1-terra']);
 expect(await receive(send('shell',{...shell,range:'30d'}))).toBe(true);
 await expect(page.locator('.mfd-page .md-h')).toHaveText('30d · 2 models');
 expect(await rows.evaluateAll(r=>r.slice(0,2).map(x=>x.dataset.model))).toEqual(['gpt-6.1-terra','gpt-6.1-sol']);
 await expect(rows.nth(0).locator('.md-s')).toHaveText('80%');
 // Today has no model ranking yet: the list keeps the published order with no shares, and the title says Today.
 expect(await receive(send('shell',{...shell,range:'today'}))).toBe(true);
 await expect(page.locator('.mfd-page .md-h')).toContainText('Today');
 await expect(rows.nth(0).locator('.md-s')).toHaveText('');
});

test('CKP-MFD-65 the Models page lists models by usage with a share each, and a row selects the model',async({page})=>{
 await open(page,withHistory());await page.locator('[data-mfd="page:tune"]').click();
 const rows=page.locator('.mfd-page .md-list .md-row');
 expect(await rows.evaluateAll(r=>r.slice(0,2).map(x=>x.dataset.model))).toEqual(['gpt-6.1-sol','gpt-6.1-terra']);
 await expect(rows.nth(0).locator('.md-s')).toHaveText('90%');await expect(rows.nth(1).locator('.md-s')).toHaveText('10%');
 await expect(page.locator('.mfd-page .md-h')).toHaveText('7d · 2 models');
 const last=rows.last();await expect(last).toHaveClass(/\bidle\b/);await expect(last.locator('.md-s')).toHaveText('');
 await rows.nth(1).click();await expect(page.locator('.mfd-page .md-row.sel')).toHaveAttribute('data-model','gpt-6.1-terra');
});

test('CKP-MFD-65 without a usage record the Models list keeps the published order and leaves share empty',async({page})=>{
 await open(page,withHistory(false));await page.locator('[data-mfd="page:tune"]').click();
 await expect(page.locator('.mfd-page .md-row').first()).toBeVisible();
 expect(await page.locator('.mfd-page .md-s').allTextContents()).toEqual(Array(await page.locator('.mfd-page .md-row').count()).fill(''));
 await expect(page.locator('.mfd-page .md-row.idle')).toHaveCount(0);
});

test('CKP-MFD-66 the Models chart key shows the frontier and names only the selected and the first-ranked model',async({page})=>{
 await open(page,withHistory());await page.locator('[data-mfd="page:tune"]').click();
 expect(await page.locator('.ok[data-opt="models"] b').allTextContents()).toEqual(['List','Chart']);
 await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
 await expect(page.locator('.mfd-page svg.fc')).toBeVisible();
 expect(await page.locator('.mfd-page svg.fc .fc-l').count()).toBeLessThanOrEqual(2);
});

test('CKP-MFD-67 the Breakdown page has one key, Projects | Sessions; project rows carry their share as a bar',async({page})=>{
 await open(page,withHistory());await page.locator('[data-mfd="page:where"]').click();
 expect(await page.locator('.ok[data-opt="where"] b').allTextContents()).toEqual(['Projects','Sessions']);
 await expect(page.locator('.mfd-page .wd-h')).toHaveText('7d · 2 projects');
 expect(await page.locator('.mfd-page .wd').evaluateAll(r=>r.map(x=>x.dataset.p+'%'))).toEqual(['90%','10%']);
 await expect(page.locator('.mfd-page .wd .wd-s').first()).toHaveText('90%');
});

test('CKP-MFD-67 the Sessions view titles its count; an empty period says so',async({page})=>{
 await open(page,withHistory(false));await page.locator('[data-mfd="page:where"]').click();
 await expect(page.locator('.mfd-page .mp-empty')).toHaveText('No sessions in this period');
 await page.locator('.ok[data-opt="where"] b[data-choice="time"]').click();
 await expect(page.locator('.mfd-page .wd-h')).toHaveText('7d · 1 session');
});

test('unreadable: with no publication and no history the Models and Breakdown pages say the data is unavailable',async({page})=>{
 await open(page,dataFor(2));
 await page.locator('[data-mfd="page:tune"]').click();await expect(page.locator('.mfd-page .mp-empty')).toHaveText('Data unavailable');
 await page.locator('[data-mfd="page:where"]').click();await expect(page.locator('.mfd-page .mp-empty')).toHaveText('Data unavailable');
});

test('CKP-MFD-68 the Models and Breakdown lists scroll inside the page, so a short cockpit shows fewer rows',async({page})=>{
 await open(page,withHistory());
 await page.locator('[data-mfd="page:tune"]').click();
 expect(await page.locator('.mfd-page .md-list').evaluate(e=>getComputedStyle(e).overflowY)).toBe('auto');
 await page.locator('[data-mfd="page:where"]').click();
 expect(await page.locator('.mfd-page .wd-list').evaluate(e=>getComputedStyle(e).overflowY)).toBe('auto');
});
