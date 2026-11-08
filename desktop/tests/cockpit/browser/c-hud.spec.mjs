// SPDX-License-Identifier: MIT
// The porthole HUD from published public data, through the normal bridge. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
const model=(id,ability,cost)=>({id,name:'Synthetic '+id,developerId:'openai',recommended:'high',efforts:[effort('low',ability-8,cost/3),effort('high',ability,cost,true)]});
const models=Array.from({length:8},(_,i)=>model('m'+i,40+i,.1*(i+1)));models.push(model('dominated-sol',30,2));
const observed=()=>new Date().toISOString();
async function open(page,{tier='tall',published=models,session=null,sessions=null,lineup=null,scope='all',edit=null}={}) {
 const {data}=visualFixture();if(published)data.details.publishedModels=published;if(session)data.details.sessions=[session];if(sessions)data.details.sessions=sessions;if(lineup)data.details.publication={contractVersion:1,publicationId:'a'.repeat(24),publishedAt:'2026-10-20T14:05:00Z',source:'client',models:lineup,truncated:false};edit?.(data);
 await page.addInitScript(()=>{window.__actions=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){const m=JSON.parse(raw);if(m.type==='action')window.__actions.push(m.action??m.payload?.action);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// Window-local: the prototype's window is the 620 pt cockpit, centred in the test viewport.
const local=async page=>{const [hud,window]=await Promise.all([page.locator('.hud').boundingBox(),page.locator('#cockpit').boundingBox()]);return [hud.x-window.x,hud.y-window.y,hud.width,hud.height];};
test('CKP-PORT-04 the tall HUD lists the first six models, complete, under a mini chart',async({page})=>{
 await open(page);const hud=page.locator('.hud');
 await expect(hud.locator('.hp')).toHaveCount(6);await expect(hud.locator('.hp b').first()).toHaveText('Synthetic m0');await expect(hud.locator('.hp-rec').first()).toHaveText('★high');
 const box=await hud.boundingBox();expect([box.width,box.height]).toEqual([180,160]);
 const svg=await hud.locator('svg.hud-mini').boundingBox();expect([svg.width,svg.height]).toEqual([162,77]);
});
test('CKP-PORT-03 HUD B sits at window-local (76,24)',async({page})=>{
 await open(page);expect(await local(page)).toEqual([76,24,180,160]);
});
test('CKP-PORT-04 chart order: this week\'s models, the lineup, then developers in turn, dominated last',async({page})=>{
 const other=m=>({...m,developerId:'anthropic'}),a=model('a',40,.1),b=model('b',50,.3),c=other(model('c',60,.5)),d=other(model('d',70,.7)),e=model('e',80,.9),beaten=model('beaten',30,2);
 const session={sessionRef:'0'.repeat(16),source:'codex',subscriptionRef:null,model:'e',effort:'high',projectLabel:null,lastObservedAt:observed(),state:'running',rate:null};
 await open(page,{published:[beaten,a,b,c,d,e],lineup:[d],session});
 expect(await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).toEqual(['e','d','a','c','b','beaten']);
 await expect(page.locator('.hud .hp').last()).toHaveClass(/dominated/);
});
test('CKP-PORT-04 a session at ★ glows the star, at another effort the name turns gold',async({page})=>{
 const at=(ref,id,effort)=>({sessionRef:ref.repeat(16),source:'codex',subscriptionRef:null,model:id,effort,projectLabel:null,lastObservedAt:observed(),state:'running',rate:null});
 await open(page,{sessions:[at('a','m7','high'),at('b','m6','low')]});
 await expect(page.locator('[data-hud-model=m7].hp .hp-rec')).toHaveClass(/\bon\b/);await expect(page.locator('[data-hud-model=m7].hp b')).not.toHaveClass(/gold/);
 await expect(page.locator('[data-hud-model=m6].hp b')).toHaveClass(/gold/);await expect(page.locator('[data-hud-model=m6].hp .hp-rec')).not.toHaveClass(/\bon\b/);
});
test('CKP-PORT-04 the row last opened stays selected',async({page})=>{
 await open(page);await page.locator('.hud .hp').nth(1).click();await expect(page.locator('.hud .hp').nth(1)).toHaveClass(/selected/);await expect(page.locator('.hud .hp.selected')).toHaveCount(1);
});
test('CKP-PORT-07 a subscription scope narrows the HUD and 全部 restores it',async({page})=>{
 const other={...model('claude-model',60,.5),developerId:'anthropic'};let ref='';
 const {send,receive}=await open(page,{published:[...models.slice(0,3),other],edit:data=>{data.subscriptions=data.subscriptions.slice();const i=data.projection.rows.findIndex(r=>r.id==='claude');if(i<0)throw Error('fixture has no claude row');ref=data.subscriptions[i].subscriptionRef;}});
 await expect(page.locator('.hud .hp')).toHaveCount(4);
 expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);
 await expect(page.locator('.hud .hp')).toHaveCount(1);await expect(page.locator('.hud .hp b')).toHaveText('Synthetic claude-model');
 expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);await expect(page.locator('.hud .hp')).toHaveCount(4);
});
test('CKP-PORT-03 the HUD hides while the shutter is closed',async({page})=>{
 const {send,receive}=await open(page);await expect(page.locator('.hud')).toBeVisible();
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);await expect(page.locator('.hud')).toBeHidden();
 expect(await receive(send('shell',{...shell,profile:'open'}))).toBe(true);await expect(page.locator('.hud')).toBeVisible();
});
test('CKP-PORT-08 one point per model at ★, a dashed frontier, dominated dots dimmed, no names inside',async({page})=>{
 await open(page,{published:[model('a',40,.1),model('b',50,.3),model('c',35,.9)]});
 await expect(page.locator('.hud-dot')).toHaveCount(3);await expect(page.locator('.hud-dot.dominated')).toHaveCount(1);
 expect((await page.locator('.hud-front').getAttribute('points')).trim().split(/\s+/).length).toBe(2);
 // No names inside: the chart's only text is its two axis captions and the rank digits of the first three points.
 expect(await page.locator('.hud-mini text').allTextContents()).toEqual(expect.arrayContaining(['Ability ↑','Cost ×']));
 expect((await page.locator('.hud-mini text.hud-rank').allTextContents()).sort()).toEqual(['1','2','3']);
 for(const text of await page.locator('.hud-mini text').allTextContents())expect(text).not.toContain('Synthetic');
});
// QA 11-08 (G3-48): six rows of real-length names fit the tall HUD whole, and the chart carries the study's axis captions.
const longNames=['GPT-6 Astra','GPT-6.1 Terra','GPT-6 Luna','Gemini 4 Argon','MiMo-V2.6-Flash','GPT-6.1 Sol'];
test('CKP-PORT-04 six real-length names fit the tall HUD: no row clipped, no name or effort cut',async({page})=>{
 await open(page,{published:longNames.map((name,i)=>({...model('n'+i,40+i,.1*(i+1)),name,recommended:'max',efforts:[effort('low',32+i,.03*(i+1)),effort('max',40+i,.1*(i+1),true)]}))});
 const hud=page.locator('.hud');await expect(hud.locator('.hp')).toHaveCount(6);
 await expect(hud.locator('.hp b')).toHaveText(longNames);
 const geometry=await hud.evaluate(h=>{const box=e=>e.getBoundingClientRect(),H=box(h);return [...h.querySelectorAll('.hp')].map(r=>{const b=r.querySelector('b'),rec=r.querySelector('.hp-rec');return {bottom:box(r).bottom-H.bottom,right:box(rec).right-H.right,cut:b.scrollWidth>b.clientWidth+.5,recCut:rec.scrollWidth>rec.clientWidth+.5};});});
 for(const row of geometry){expect(row.bottom).toBeLessThanOrEqual(0.5);expect(row.right).toBeLessThanOrEqual(0.5);expect(row.cut).toBe(false);expect(row.recCut).toBe(false);}
 await expect(hud.locator('.hp-rec').nth(4)).toHaveText('★max');
 await expect(page.locator('.hud-b .hud-axis-label')).toHaveText(['Ability ↑','Cost ×']);
});
test('CKP-PORT-04 the axis captions follow the language',async({page})=>{
 const {send,receive}=await open(page);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(page.locator('.hud-b .hud-axis-label')).toHaveText(['能力 ↑','成本 ×']);
});
test('CKP-PORT-08 a different current effort is a white dot linked to its ★',async({page})=>{
 await open(page,{published:[model('a',40,.1)],session:{sessionRef:'0000000000000001',source:'Codex',subscriptionRef:null,model:'a',effort:'low',projectLabel:null,lastObservedAt:observed(),state:'running',rate:null}});
 await expect(page.locator('.hud-cur')).toHaveCount(1);await expect(page.locator('.hud-link')).toHaveCount(1);
});
test('CKP-PORT-05 the compact profile is one strip of three',async({page})=>{
 await open(page,{tier:'compact'});
 await expect(page.locator('.hud.hud-strip .hp')).toHaveCount(3);
 expect(await local(page)).toEqual([58,9,216,30]);
});
// G3-48: long published names overlapped their neighbours in three columns. The study's compact strip is an
// 86x30 chart beside three stacked 10 px rows; each name stays inside its own row, before its ★ effort.
test('G3-48 compact HUD names never overlap, however long',async({page})=>{
 const named=(id,name)=>({...model(id,50,.2),name});
 await open(page,{tier:'compact',published:[named('a','GPT-6 Astra Extended Context'),named('b','GPT-6.1 Terra'),named('c','GPT-6 Luna Preview Long Name')]});
 const svg=await page.locator('.hud-strip svg.hud-mini').boundingBox();expect([svg.width,svg.height]).toEqual([86,30]);
 const rows=await page.locator('.hud-strip .hp').evaluateAll(rows=>rows.map(r=>{const box=e=>e.getBoundingClientRect(),hud=r.closest('.hud').getBoundingClientRect(),row=box(r),name=box(r.querySelector('b')),rec=box(r.querySelector('.hp-rec'));return {top:row.top,bottom:row.bottom,nameRight:name.right,recLeft:rec.left,recRight:rec.right,hudRight:hud.right};}));
 expect(rows).toHaveLength(3);
 for(const [i,r] of rows.entries()){expect(r.nameRight).toBeLessThanOrEqual(r.recLeft);expect(r.recRight).toBeLessThanOrEqual(r.hudRight+0.5);if(i)expect(r.top).toBeGreaterThanOrEqual(rows[i-1].bottom);}
});
test('CKP-PORT-06 a row opens 档位 and Esc or Back returns to the page before',async({page})=>{
 await open(page);
 await page.locator('.hud .hp').first().click();await expect(page.locator('.fc')).toBeVisible();
 await expect(page.locator('.mfd-back')).toBeVisible();await page.keyboard.press('Escape');await expect(page.locator('.fc')).toHaveCount(0);
 await page.locator('.hud-dot').first().click();await expect(page.locator('.fc')).toBeVisible();
 await page.locator('.mfd-back').click();await expect(page.locator('.fc')).toHaveCount(0);
});
const fieldOpens=page=>page.evaluate(()=>window.__actions.filter(a=>a==='openField').length);
test('CKP-PORT-06 a HUD click opens 档位 only; the port beside it still opens the field',async({page})=>{
 await open(page);await page.locator('.ck-port').click({position:{x:520,y:120}});await expect.poll(()=>fieldOpens(page)).toBe(1);
 await page.locator('.hud .hp').first().click();await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
 await page.keyboard.press('Escape');await page.locator('.hud-dot').first().click();await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
});
for(const key of ['Enter','Space'])test(`CKP-PORT-06 ${key} on a HUD row opens 档位 only; on the port it opens the field`,async({page})=>{
 await open(page);await page.locator('.ck-port').focus();await page.keyboard.press(key);await expect.poll(()=>fieldOpens(page)).toBe(1);
 await page.locator('.hud .hp').first().focus();await page.keyboard.press(key);await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
});
test('clearing the data leaves no HUD box and no Back button',async({page})=>{
 const {send,receive}=await open(page);await page.locator('.hud .hp').first().click();await expect(page.locator('.mfd-back')).toBeVisible();
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(page.locator('.hud')).toBeHidden();await expect(page.locator('.hud .hp')).toHaveCount(0);await expect(page.locator('.mfd-back')).toHaveCount(0);
 await page.keyboard.press('Escape');await expect(page.locator('.mfd-back')).toHaveCount(0);
});
// Real public IDs and names from the publication: the roster key differs from the ID, and an older model shares a word.
test('CKP-PORT-06 hovering a row lights its rocket by published name, for real public IDs',async({page})=>{
 const real=(id,name)=>({...model(id,40,.1),name});
 await open(page,{published:[real('sol-6.1','GPT-6.1 Sol'),real('sol','GPT-6 Sol'),real('auto:anthropic:ccb37fec2677f068','Claude Haiku 5.5')]});
 const rows=page.locator('.hud .hp');
 await rows.nth(0).hover();await expect(page.locator('.ck-still-body.ck-hot')).toHaveCount(1);await expect(page.locator('.ck-still-body.ck-hot')).toHaveAttribute('data-model-name','GPT-6.1 Sol');
 await rows.nth(1).hover();await expect(page.locator('.ck-still-body.ck-hot')).toHaveCount(0);
 await rows.nth(2).hover();await expect(page.locator('.ck-still-body.ck-hot')).toHaveAttribute('data-model-name','Claude Haiku 5.5');
 await page.mouse.move(1,1);await expect(page.locator('.ck-still-body.ck-hot')).toHaveCount(0);
});
test('an older engine shows no HUD',async({page})=>{
 await open(page,{published:null});await expect(page.locator('.hud')).toBeHidden();
});
