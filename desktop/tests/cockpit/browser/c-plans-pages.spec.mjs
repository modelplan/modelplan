// SPDX-License-Identifier: MIT
// WP-13 (V1-FINAL 8.2-8.4, 14): the page keys, the Subscription page and the Models and Where pages, on the built page
// through its normal bridge. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,currentSample,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile,CODEX_REF} from '../build13-fixture.mjs';

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
function withHistory(used=true,priced=false){
 const data=build13Profile(),at=n=>{const d=new Date(Date.now()-n*864e5);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
 const top=used?[entity('gpt-6.1-sol',900),entity('gpt-6.1-terra',100)]:[],none={measure:'observed-output-tokens',attribution:'unattributed'};
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:at(3),subscriptions:[],daily:[],hourly:[],cycles:[],
  models:{...none,recent7d:ranking(top),recent30d:ranking(top)},tools:{...none,recent7d:ranking([]),recent30d:ranking([])},
  projects:{recent7d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[],recent30d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[]}};
 if(priced)data.history.cost={basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-04',daily:[{at:at(1),source:'codex',estimatedUsd:15,pricedTokens:1000,unpricedTokens:0}],hourly:[],
  models:{today:[],recent7d:[{model:'gpt-6.1-sol',source:'codex',estimatedUsd:12,pricedTokens:900,unpricedTokens:0},{model:'gpt-6.1-terra',source:'codex',estimatedUsd:3,pricedTokens:100,unpricedTokens:0}],recent30d:[]}};
 return data;
}

// WP-13 + WP-06 (#1050): the Models rows carry the producer's ≈cost; a model without a price keeps an empty cell.
test('CKP-MFD-65 the Models rows fill the ≈cost cell from the price data and the title carries the total',async({page})=>{
 await open(page,withHistory(true,true));await page.locator('[data-mfd="page:tune"]').click();
 const rows=page.locator('.mfd-page .md-list .md-row');
 await expect(rows.nth(0).locator('.md-c')).toHaveText('≈$12');await expect(rows.nth(1).locator('.md-c')).toHaveText('≈$3');
 await expect(rows.last().locator('.md-c')).toHaveText('');
 await expect(page.locator('.mfd-page .md-h')).toHaveText('7d · 2 models · ≈$15');
});

test('CKP-MFD-65 without price data the Models cost cells and title stay free of ≈$',async({page})=>{
 await open(page,withHistory(true,false));await page.locator('[data-mfd="page:tune"]').click();
 expect((await page.locator('.mfd-page .md-c').allTextContents()).join('')).toBe('');
 await expect(page.locator('.mfd-page .md-h')).toHaveText('7d · 2 models');
});

// macrevc-1058-10: ≈cost reads the price rows themselves, not only models the output-token ranking lists (input-only use).
test('CKP-MFD-65 a priced model with no output-token ranking shows its ≈cost, a known zero shows ≈$0, an unpriced model stays blank',async({page})=>{
 const data=withHistory(true,true);data.history.models.recent7d=ranking([entity('gpt-6.1-sol',900)]);
 data.history.cost.models.recent7d.push({model:'gpt-6-luna',source:'codex',estimatedUsd:0,pricedTokens:50,unpricedTokens:0});
 await open(page,data);await page.locator('[data-mfd="page:tune"]').click();
 const cell=id=>page.locator(`.mfd-page .md-row[data-model="${id}"] .md-c`);
 await expect(cell('gpt-6.1-terra')).toHaveText('≈$3');await expect(cell('gpt-6-luna')).toHaveText('≈$0');await expect(cell('gpt-6-astra')).toHaveText('');
});

// macrevc-1058-3: a subscription scope has no scoped attribution for the ranking or the prices, so they stay unknown.
test('CKP-MFD-65 under a selected subscription the Models shares and ≈cost stay unknown',async({page})=>{
 const {send,receive}=await open(page,withHistory(true,true));await page.locator('[data-mfd="page:tune"]').click();
 expect(await receive(send('shell',{...shell,scope:CODEX_REF}))).toBe(true);
 await expect(page.locator('.mfd-page .md-row').first()).toBeVisible();
 expect((await page.locator('.mfd-page .md-s').allTextContents()).join('')).toBe('');
 expect((await page.locator('.mfd-page .md-c').allTextContents()).join('')).toBe('');
 await expect(page.locator('.mfd-page .md-h')).not.toContainText('≈$');
});

// macrevc-1058-5: after opening a model from the HUD, a list pick selects the picked row.
test('CKP-MFD-65 a list pick after opening a model from the HUD selects the picked row',async({page})=>{
 await open(page,withHistory());await page.locator('.hud .hp').first().click();
 await page.locator('.ok[data-opt="models"] b[data-choice="list"]').click();
 const rows=page.locator('.mfd-page .md-row'),other=await rows.evaluateAll(r=>r.map(x=>x.dataset.model));
 const sel=await page.locator('.mfd-page .md-row.sel').getAttribute('data-model'),pick=other.find(id=>id!==sel);
 await page.locator(`.mfd-page .md-row[data-model="${pick}"]`).click();
 await expect(page.locator('.mfd-page .md-row.sel')).toHaveAttribute('data-model',pick);
});

// macrevc-1058-4: a model the history ranks as used stays listed even outside the ten-model field.
test('CKP-MFD-65 a used model outside the ten-model field is still listed and selectable',async({page})=>{
 const data=withHistory();
 for(let i=0;i<12;i++)data.details.publishedModels.push({...structuredClone(data.details.publishedModels[0]),id:'gpt-x'+i,name:'GPT X'+i});
 data.history.models.recent7d=ranking([entity('gpt-6.1-sol',900),entity('gpt-x11',50)]);
 await open(page,data);await page.locator('[data-mfd="page:tune"]').click();
 const row=page.locator('.mfd-page .md-row[data-model="gpt-x11"]');await expect(row).toBeVisible();await row.click();
 await expect(page.locator('.mfd-page .md-row.sel')).toHaveAttribute('data-model','gpt-x11');
 // macrevc-1058-11: the chart keeps that selected model.
 await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
 await expect(page.locator('.mfd-page .mfd-fill')).toHaveAttribute('data-models',/\bgpt-x11\b/);
});

// macrevc-1058-6: every project in the title is a row (the list scrolls).
test('CKP-MFD-67 ten projects give ten rows',async({page})=>{
 const data=withHistory();
 data.history.projects.recent7d=Array.from({length:10},(_,i)=>({ref:'p'+i,label:'proj'+i,model:'gpt-6.1-sol',effort:'high',observedOutputTokens:10,share:.1}));
 await open(page,data);await page.locator('[data-mfd="page:where"]').click();
 await expect(page.locator('.mfd-page .wd-h')).toHaveText('7d · 10 projects');await expect(page.locator('.mfd-page .wd')).toHaveCount(10);
});

// macrevc-1058-7: Today has no per-model ranking, so the list says so instead of showing the published order.
test('CKP-MFD-65 the Models list says Today has no statistics yet',async({page})=>{
 const {send,receive}=await open(page,withHistory());await page.locator('[data-mfd="page:tune"]').click();
 expect(await receive(send('shell',{...shell,range:'today'}))).toBe(true);
 await expect(page.locator('.mfd-page .mp-empty',{hasText:/No statistics for today/})).toBeVisible();
 await expect(page.locator('.mfd-page .md-row')).toHaveCount(0);
});

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
 // Today has no model ranking yet: the page says so (macrevc-1058-7).
 expect(await receive(send('shell',{...shell,range:'today'}))).toBe(true);
 await expect(page.locator('.mfd-page .mp-empty')).toBeVisible();
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
 await expect(page.locator('.mfd-ok [data-opt="range"]')).toHaveCount(0);await expect(page.locator('.mfd-ok .ok:not(.off)')).toHaveCount(1);
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
