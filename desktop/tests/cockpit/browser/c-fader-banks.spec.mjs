// SPDX-License-Identifier: MIT
// QA 11-08 / owner: one fader per model, three per bank, paged with ◀ ▶ and [ ] (CKP-FAD-01, CKP-FAD-02, CKP-FAD-15).
// The built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
// The engine's publication: three models, the one in use first. Published: those three, four more OpenAI models,
// one from a developer with no subscription here (xAI) and one Anthropic model in use beyond the engine's three.
function fixture(){
 const data=visualFixture().data;
 const publication=[model('used','openai'),model('lineup-1','openai'),model('lineup-2','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('more-1','openai'),model('xai-1','xai'),model('more-2','openai'),model('also-used','anthropic'),model('more-3','openai')];
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'codex',subscriptionRef:null,model:'used',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null},
  {sessionRef:'00000000000000a2',source:'claude',subscriptionRef:null,model:'also-used',effort:'medium',projectLabel:null,lastObservedAt:new Date(Date.now()-60e3).toISOString(),state:'idle',rate:null}];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const names=page=>page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(e=>e.getAttribute('aria-label').split(':')[0]));

test('CKP-FAD-01 one fader per model beyond the engine three, three per bank, models in use first',async({page})=>{
 await open(page,fixture());
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/3');
 expect(await names(page)).toEqual(['Synthetic used','Synthetic also-used','Synthetic lineup-1']);
 await page.locator('[data-bank="1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 expect(await names(page)).toEqual(['Synthetic lineup-2','Synthetic more-1','Synthetic more-2']);
 await page.locator('[data-bank="1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 expect(await names(page)).toEqual(['Synthetic more-3']);
 // A developer without a subscription here gets no fader.
 for(const label of await page.locator('.fd-strip[aria-label]').evaluateAll(l=>l.map(e=>e.getAttribute('aria-label'))))expect(label).not.toContain('xai-1');
});

test('CKP-FAD-15 [ and ] page the banks like ◀ ▶',async({page})=>{
 await open(page,fixture());
 await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 await page.keyboard.press('[');await expect(page.locator('.bank-lcd')).toHaveText('Bank 2/3');
 await page.locator('[data-bank="-1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/3');
});

test('CKP-FAD-01 three models or fewer keep one bank and no pager',async({page})=>{
 const data=fixture();data.details.publishedModels=data.details.publication.models;
 await open(page,data);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);await expect(page.locator('.bank-lcd')).toHaveCount(0);
});

// Build 14c (owner): a trial on a model with no live session (current unreported) showed no chart on the MFD compare
// page. The table keeps its dashes (CKP-MFD-19); the chart is drawn relative to ★ = 1 with ★ and trial markers.
test('build 14c: a trial on a fader with no live session keeps table dashes and draws the chart relative to ★',async({page})=>{
 await open(page,fixture());
 const idle=page.locator('.fd-ch:not(.empty)').nth(2);await expect(idle.locator('.fd-strip')).toHaveAttribute('aria-label',/^Synthetic lineup-1:/);
 await idle.locator('.fd-strip').click();const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
 await screen.locator('.cmp-lad [data-mfd="try:Low"]').click();
 await expect(screen.locator('.cmp-note')).toContainText('current unknown · chart relative to ★');
 const value=role=>screen.locator(`table.cmp td[data-role="${role}"] .cmp-value`);
 await expect(value('current')).toHaveText(['--','--','--']);
 await expect(value('trial')).toHaveText(['—','—','—']);
 await expect(value('rec')).toHaveText(['—','—','—']);
 const chart=screen.locator('svg.cmp-chart');await expect(chart).toHaveCount(1);
 expect(await chart.locator('polyline').count()).toBeGreaterThan(0);
 await expect(chart.locator('.cfg-trial')).not.toHaveCount(0);await expect(chart.locator('.cfg-rec')).not.toHaveCount(0);
});

// D123 / D135 / CKP-FAD-16 through the normal bridge: all-known developers, more than twelve qualifying models.
function crowded(){
 const data=visualFixture().data;
 const own=Array.from({length:16},(_,i)=>model('own-'+String(i+1).padStart(2,'0'),'openai'));
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:own.slice(0,3)};
 data.details.publishedModels=[...own,model('xai-1','xai'),model('old-1','openai')];
 data.details.sessions=[{sessionRef:'00000000000000b1',source:'codex',subscriptionRef:null,model:'own-16',effort:'medium',projectLabel:null,lastObservedAt:new Date(Date.now()-3600e3).toISOString(),state:'idle',rate:null},
  {sessionRef:'00000000000000b2',source:'codex',subscriptionRef:null,model:'old-1',effort:'medium',projectLabel:null,lastObservedAt:new Date(Date.now()-10*86400e3).toISOString(),state:'idle',rate:null}];
 return data;
}
test('CKP-FAD-16 the row is capped at 12 faders; a model used in the last 7 days stays in, the weakest others drop',async({page})=>{
 await open(page,crowded());
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/4');
 expect(await names(page)).toEqual(['Synthetic own-16','Synthetic own-01','Synthetic own-02']);
 await page.keyboard.press(']');await page.keyboard.press(']');await page.keyboard.press(']');await expect(page.locator('.bank-lcd')).toHaveText('Bank 4/4');
 expect(await names(page)).toHaveLength(3);
 const all=[];for(const l of await page.locator('.fd-strip[aria-label]').evaluateAll(l=>l.map(e=>e.getAttribute('aria-label'))))all.push(l);
 for(const label of all){expect(label).not.toContain('xai-1');expect(label).not.toContain('old-1');}
});
test('SET-9-30 show all models lifts the cap and the own-plans filter',async({page})=>{
 const {send,receive}=await open(page,crowded());
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/4');
 expect(await receive(send('appearance',{...appearance,redBelow:25,showAllModels:true}))).toBe(true);
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/6');
 expect(await receive(send('appearance',{...appearance,redBelow:25,showAllModels:false}))).toBe(true);
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/4');
});
