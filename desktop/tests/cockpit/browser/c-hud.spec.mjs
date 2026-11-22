// SPDX-License-Identifier: MIT
// The porthole HUD from published public data, through the normal bridge. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {shortLabel} from '../../../cockpit/study/rocket-r1/short-label.js';

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
// D371 B2 option A (owner 11-21): no panel, one edge-fading scrim, a 1 px dark text outline, inside the safe area, whole rows only.
test('CKP-PORT-03 D371 the HUD has no panel: transparent box, no border, no shadow, one scrim fading to nothing at its edge',async({page})=>{
 await open(page);
 const look=await page.locator('.hud').evaluate(h=>{const c=getComputedStyle(h),s=getComputedStyle(h,'::before');return {bg:c.backgroundColor,bgImage:c.backgroundImage,border:c.borderTopWidth,shadow:c.boxShadow,radius:c.borderTopLeftRadius,scrim:s.backgroundImage,content:s.content};});
 expect(look.bg).toBe('rgba(0, 0, 0, 0)');expect(look.bgImage).toBe('none');expect(look.border).toBe('0px');expect(look.shadow).toBe('none');expect(look.radius).toBe('0px');
 expect(look.scrim).toMatch(/radial-gradient/);expect(look.scrim).toMatch(/rgba\(0, 0, 0, 0\)\s*\d*%?\)?$|transparent/);
});
test('CKP-PORT-03 D371 list and chart text carry a 1 px dark outline',async({page})=>{
 await open(page);
 const outline=await page.locator('.hud').evaluate(h=>{const w=e=>parseFloat(getComputedStyle(e).webkitTextStrokeWidth||'0');return {name:w(h.querySelector('.hp b')),rec:w(h.querySelector('.hp-rec')),num:w(h.querySelector('.hp-n')),axis:parseFloat(getComputedStyle(h.querySelector('.hud-axis-label')).strokeWidth)};});
 expect(outline).toEqual({name:1,rec:1,num:1,axis:1});
});
test('CKP-PORT-03 D371 the whole HUD stays inside the safe area, 10 px in from the glass edge',async({page})=>{
 await open(page);
 const [hud,port]=await Promise.all([page.locator('.hud').boundingBox(),page.locator('.ck-port').boundingBox()]);
 expect(hud.x-port.x).toBeGreaterThanOrEqual(10);expect(hud.y-port.y).toBeGreaterThanOrEqual(10);
 expect(port.x+port.width-(hud.x+hud.width)).toBeGreaterThanOrEqual(10);expect(port.y+port.height-(hud.y+hud.height)).toBeGreaterThanOrEqual(10);
});
test('CKP-PORT-03 D371 variant B: a half-opacity scrim reaching 48 pt left and right and 16 pt above and below the list; grey #aab6bf reads',async({page})=>{
 await open(page);
 const look=await page.locator('.hud').evaluate(h=>{const box=h.getBoundingClientRect(),s=getComputedStyle(h,'::before'),lum=c=>{const [r,g,b]=c.match(/[\d.]+/g).slice(0,3).map(Number).map(v=>{v/=255;return v<=.03928?v/12.92:((v+.055)/1.055)**2.4;});return .2126*r+.7152*g+.0722*b;},ratio=c=>(lum(c)+.05)/(lum('rgb(3, 8, 16)')+.05);
  return {inset:[s.top,s.right,s.bottom,s.left],image:s.backgroundImage,rank:getComputedStyle(h.querySelector('.hp-n')).color,rec:getComputedStyle(h.querySelector('.hp-rec')).color,rankRatio:ratio(getComputedStyle(h.querySelector('.hp-n')).color),recRatio:ratio(getComputedStyle(h.querySelector('.hp-rec')).color)};});
 expect(look.inset).toEqual(['-16px','-48px','-16px','-48px']);
 expect(look.image).toContain('rgba(0, 0, 0, 0.25)');expect(look.image).not.toContain('rgba(0, 0, 0, 0.5)');
 expect(look.rank).toBe('rgb(170, 182, 191)');
 expect(look.rankRatio).toBeGreaterThan(7);expect(look.recRatio).toBeGreaterThan(7);
});
test('CKP-PORT-04 D371 the ★ effort column lines up across rows whatever the name length',async({page})=>{
 const names=['A','GPT-6.1 Terra Max','Luna','Gemini 4 Argon','MiMo','Sol'];
 await open(page,{published:names.map((name,i)=>({...model('q'+i,40+i,.1*(i+1)),name}))});
 const xs=await page.locator('.hud .hp-rec').evaluateAll(a=>a.map(e=>Math.round(e.getBoundingClientRect().left)));
 expect(new Set(xs).size).toBe(1);
 const names2=await page.locator('.hud .hp b').evaluateAll(a=>a.map(e=>e.scrollWidth>e.clientWidth+.5));expect(names2.every(c=>!c)).toBe(true);
});
test('CKP-PORT-04 D371 when six rows do not fit the safe area, fewer whole rows are shown (never a cut row or an ellipsis)',async({page})=>{
 const {send,receive}=await open(page);
 await expect(page.locator('.hud .hp')).toHaveCount(6);
 await page.evaluate(()=>{document.querySelector('.ck-port').style.height='138px';});
 expect(await receive(send('shell',{...shell,tier:'tall'}))).toBe(true);
 const n=await page.locator('.hud .hp').count();expect(n).toBeGreaterThanOrEqual(1);expect(n).toBeLessThan(6);
 const room=await page.evaluate(()=>{const p=document.querySelector('.ck-port').getBoundingClientRect(),rows=[...document.querySelectorAll('.hud .hp')];return p.bottom-10-rows.at(-1).getBoundingClientRect().bottom;});
 expect(room).toBeGreaterThanOrEqual(-0.5);
 expect(await page.locator('.hud .hp b').evaluateAll(a=>a.some(e=>e.scrollWidth>e.clientWidth+.5||getComputedStyle(e).textOverflow==='ellipsis'))).toBe(false);
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
// D86: "All" is the union of the user's own subscriptions, never the whole published field.
const keepRows=ids=>data=>{data.projection.rows=data.projection.rows.filter(r=>ids.includes(r.id));data.subscriptions=data.subscriptions.filter(s=>data.projection.rows.some(r=>r.accounts.some(a=>a.subscriptionRef===s.subscriptionRef)));};
const mixed=()=>[model('gpt-a',50,.3),model('gpt-b',45,.2),{...model('claude-a',60,.5),developerId:'anthropic'},{...model('google-a',55,.4),developerId:'google'}];
test('CKP-PORT-04 D86 one GPT subscription: All lists only that plan\'s models, on the HUD and the 模型 page',async({page})=>{
 await open(page,{published:mixed(),edit:keepRows(['codex'])});
 expect((await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).sort()).toEqual(['gpt-a','gpt-b']);
 await page.getByRole('button',{name:'Models',exact:true}).click(); await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
 const ids=await page.locator('.pg-tune [data-fill="fc"]').getAttribute('data-models');expect(ids.split(' ').sort()).toEqual(['gpt-a','gpt-b']);
});
test('CKP-PORT-04 D86 two subscriptions: All is the union of both and nothing else',async({page})=>{
 await open(page,{published:mixed(),edit:keepRows(['codex','claude'])});
 expect((await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).sort()).toEqual(['claude-a','gpt-a','gpt-b']);
 await page.getByRole('button',{name:'Models',exact:true}).click(); await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
 const ids=await page.locator('.pg-tune [data-fill="fc"]').getAttribute('data-models');expect(ids.split(' ').sort()).toEqual(['claude-a','gpt-a','gpt-b']);
});
test('CKP-PORT-04 D86 a published plan model list narrows All to the models that plan lists',async({page})=>{
 await open(page,{published:mixed(),edit:data=>{keepRows(['codex'])(data);data.projection.rows[0].accounts[0].plan={id:'plus'};data.details.planModels=[{planId:'openai-plus',basis:'access',modelIds:['gpt-a']}];}});
 expect(await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).toEqual(['gpt-a']);
});
// D98: the models the tool reports for the signed-in account (details.subscriptions[].reportedModels) decide before the
// published plan list; a subscription the tool reported nothing for keeps the plan list.
const reported=ids=>data=>{keepRows(['codex'])(data);data.projection.rows[0].accounts[0].plan={id:'plus'};data.details.planModels=[{planId:'openai-plus',basis:'access',modelIds:['gpt-a']}];
 const ref=data.projection.rows[0].accounts[0].subscriptionRef,sub=data.details.subscriptions.find(s=>s.subscriptionRef===ref);if(!sub)throw Error('fixture has no codex subscription details');if(ids)sub.reportedModels=ids;};
test('CKP-FAD-25 D98 the tool-reported models decide All before the published plan list, on the HUD and the 模型 page',async({page})=>{
 await open(page,{published:mixed(),edit:reported(['gpt-b'])});
 expect(await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).toEqual(['gpt-b']);
 await page.getByRole('button',{name:'Models',exact:true}).click(); await page.locator('.ok[data-opt="models"] b[data-choice="chart"]').click();
 expect(await page.locator('.pg-tune [data-fill="fc"]').getAttribute('data-models')).toBe('gpt-b');
});
test('CKP-FAD-25 D98 without a reported list the published plan list still decides',async({page})=>{
 await open(page,{published:mixed(),edit:reported(null)});
 expect(await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).toEqual(['gpt-a']);
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
 await expect(hud.locator('.hp b')).toHaveText(longNames.map(name=>shortLabel(name)));// the HUD shows the study's short names (#761)
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
 expect(await local(page)).toEqual([62,25,216,30]);
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
 // The boxes above can fit while the glyphs still paint past them: check the painted text against the ★.
 const painted=await page.locator('.hud-strip .hp').evaluateAll(rows=>rows.map(r=>{
  const name=r.querySelector('b'),rec=r.querySelector('.hp-rec').getBoundingClientRect(),style=getComputedStyle(name);
  const range=document.createRange();range.selectNodeContents(name);const text=range.getBoundingClientRect();
  const clipped=style.overflow==='hidden'&&style.textOverflow==='ellipsis'&&style.whiteSpace==='nowrap';
  return {overflows:name.scrollWidth>name.clientWidth,clipped,textRight:text.right,boxRight:name.getBoundingClientRect().right,recLeft:rec.left,lineHeight:style.lineHeight,rowHeight:r.getBoundingClientRect().height};
 }));
 for(const p of painted){
  expect(p.overflows&&!p.clipped,'a name wider than its box must be clipped with an ellipsis').toBe(false);
  expect(p.clipped?p.boxRight:p.textRight).toBeLessThanOrEqual(p.recLeft);
  expect([p.lineHeight,p.rowHeight]).toEqual(['10px',10]);
 }
});
test('CKP-PORT-06 a row opens 模型 and Esc or the Overview tab returns to the overview',async({page})=>{
 await open(page);
 await page.locator('.hud .hp').first().click();await expect(page.locator('.fc')).toBeVisible();
 await expect(page.locator('.mfd-pk .pk-seg:not([hidden])')).toBeVisible();await page.keyboard.press('Escape');await expect(page.locator('.fc')).toHaveCount(0);
 await page.locator('.hud-dot').first().click();await expect(page.locator('.fc')).toBeVisible();
 await page.getByRole('tab',{name:'Overview'}).click();await expect(page.locator('.fc')).toHaveCount(0);
});
const fieldOpens=page=>page.evaluate(()=>window.__actions.filter(a=>a==='openField').length);
test('CKP-PORT-06 a HUD click opens 模型 only; the port beside it still opens the field',async({page})=>{
 await open(page);await page.locator('.ck-port').click({position:{x:520,y:120}});await expect.poll(()=>fieldOpens(page)).toBe(1);
 await page.locator('.hud .hp').first().click();await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
 await page.keyboard.press('Escape');await page.locator('.hud-dot').first().click();await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
});
for(const key of ['Enter','Space'])test(`CKP-PORT-06 ${key} on a HUD row opens 模型 only; on the port's ⤢ key it opens the field`,async({page})=>{
 await open(page);await page.locator('.port-big[data-bigfield]').focus();await page.keyboard.press(key);await expect.poll(()=>fieldOpens(page)).toBe(1);
 await page.locator('.hud .hp').first().focus();await page.keyboard.press(key);await expect(page.locator('.fc')).toBeVisible();expect(await fieldOpens(page)).toBe(1);
});
test('clearing the data leaves no HUD box and no Back button',async({page})=>{
 const {send,receive}=await open(page);await page.locator('.hud .hp').first().click();await expect(page.locator('.mfd-pk .pk-seg:not([hidden])')).toBeVisible();
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(page.locator('.hud')).toBeHidden();await expect(page.locator('.hud .hp')).toHaveCount(0);await expect(page.locator('.mfd-pk .pk-seg:not([hidden])')).toHaveCount(0);
 await page.keyboard.press('Escape');await expect(page.locator('.mfd-pk .pk-seg:not([hidden])')).toHaveCount(0);
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
// WP-22 macrevb-1062-3: a rocket chosen in the enlarged field arrives as the host's `select` message (public model id) and
// selects the same model on the HUD, the faders and the porthole still; a clear from the field clears all three.
test('WP-22 the field\'s selection selects the model on the HUD, the faders and the porthole, and a clear clears them',async({page})=>{
 const sonnet={...model('sonnet-5.5',62,.4),name:'Claude Sonnet 5.5',developerId:'anthropic'};
 const published=[sonnet,...models];
 const {send,receive}=await open(page,{published,lineup:[sonnet,published[1]]});
 await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
 const marked=()=>page.locator('.ck-field .ck-still-body.ck-sel').evaluateAll(e=>e.map(x=>x.dataset.modelName));
 const fader=()=>page.locator('.fd-ch.sel [data-travel]').evaluateAll(e=>e.map(x=>x.getAttribute('aria-label')));
 expect(await receive(send('select',{model:'sonnet-5.5'}))).toBe(true);
 await expect(page.locator('.hud .hp.selected')).toHaveCount(1);
 await expect(page.locator('.hud .hp.selected')).toHaveAttribute('data-hud-model','sonnet-5.5');
 expect(await fader()).toEqual(['Claude Sonnet 5.5']);
 expect(await marked()).toEqual(['Claude Sonnet 5.5']);
 expect(await receive(send('select',{model:null}))).toBe(true);
 await expect(page.locator('.hud .hp.selected')).toHaveCount(0);
 expect(await fader()).toEqual([]);
 expect(await marked()).toEqual([]);
 expect(await receive(send('select',{model:'sonnet-5.5',effort:'high'}))).toBe(false);
 await expect(page.locator('.hud .hp.selected')).toHaveCount(0);
});
// macrevb-1062-3 r2: the fader renderer resolves the shared effort keys on the visible bank only, so a model chosen in the
// field whose fader sits on another bank must bring that bank up; a clear keeps the bank and selects no channel.
test('WP-22 the field\'s selection shows the selected fader\'s bank and the effort keys act on it; a clear keeps the bank',async({page})=>{
 const {send,receive}=await open(page,{lineup:[models[0]]});
 const visible=()=>page.locator('.fd-ch [data-travel]').evaluateAll(e=>e.map(x=>x.getAttribute('aria-label')));
 const selected=()=>page.locator('.fd-ch.sel [data-travel]').evaluateAll(e=>e.map(x=>x.getAttribute('aria-label')));
 const first=await visible();expect(first).not.toContain('Synthetic m1');
 expect(await receive(send('select',{model:'m1'}))).toBe(true);
 expect(await visible()).toContain('Synthetic m1');
 expect(await selected()).toEqual(['Synthetic m1']);
 await page.locator('.sc-l:not(.na)').first().click();
 await expect(page.locator('.fd-ch.trying [data-travel]')).toHaveAttribute('aria-label','Synthetic m1');
 const bank=await visible();
 expect(await receive(send('select',{model:null}))).toBe(true);
 expect(await selected()).toEqual([]);
 expect(await visible()).toEqual(bank);
 expect(await receive(send('select',{model:'m0'}))).toBe(true);
 expect(await visible()).toEqual(first);expect(await selected()).toEqual(['Synthetic m0']);
});
// Owner 11-19 (#1062): the enlarged field opens on a click on the port, not on a drag across it, and not on the click
// that bounces off the field's close (the cockpit, inactive while the field held key, becomes active again).
test('WP-22 a drag across the porthole does not open the field; a press that stays within 4 px still does',async({page})=>{
 await open(page);const box=await page.locator('.ck-port').boundingBox(),x=box.x+520,y=box.y+120;
 await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+12,y+3,{steps:4});await page.mouse.up();
 await page.waitForTimeout(100);expect(await fieldOpens(page)).toBe(0);
 await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+3,y+2,{steps:2});await page.mouse.up();
 await expect.poll(()=>fieldOpens(page)).toBe(1);
});
test('WP-22 a porthole click within 300 ms of the field closing is ignored; a later one opens it',async({page})=>{
 // Controlled time: the page's clock only moves when the test moves it.
 await page.clock.install({time:new Date('2026-11-19T12:00:00Z')});
 const {send,receive}=await open(page);const port=page.locator('.ck-port');
 await page.clock.pauseAt(new Date('2026-11-19T12:00:10Z'));
 await port.click({position:{x:520,y:120}});await expect.poll(()=>fieldOpens(page)).toBe(1);
 // A cockpit reactivation alone is not a field close: no guard.
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await port.click({position:{x:520,y:120}});await expect.poll(()=>fieldOpens(page)).toBe(2);
 // The host's field close starts the guard.
 expect(await receive(send('fieldClosed',{}))).toBe(true);
 await port.click({position:{x:520,y:120}});
 await page.clock.runFor(299);
 await port.click({position:{x:520,y:120}});
 expect(await fieldOpens(page)).toBe(2);
 await page.clock.runFor(2);
 await port.click({position:{x:520,y:120}});await expect.poll(()=>fieldOpens(page)).toBe(3);
});
// v1 final (WP-14, V1-FINAL §5): the HUD is the legend of the user's own models. A session does not add a model its
// subscription does not carry (a Claude Code session pointed at another vendor's model is not that subscription's model),
// the rows stop at six (three on the short cockpit) on no panel, names 10 px white, and a small green dot
// follows the ★ effort of every model a session is running right now.
const running=(ref,id,state='running',source='codex')=>({sessionRef:ref.repeat(16),source,subscriptionRef:null,model:id,effort:'high',projectLabel:null,lastObservedAt:observed(),state,rate:null});
test('CKP-PORT-50 a session on a model outside its subscription does not list that model',async({page})=>{
 await open(page,{published:mixed(),edit:keepRows(['codex']),sessions:[running('a','claude-a'),running('b','google-a','idle')]});
 expect((await page.locator('.hud .hp').evaluateAll(rows=>rows.map(r=>r.dataset.hudModel))).sort()).toEqual(['gpt-a','gpt-b']);
});
const backing=page=>page.locator('.hud').evaluate(h=>{const cs=getComputedStyle(h),box=h.getBoundingClientRect(),alpha=(/rgba?\(([^)]+)\)/.exec(cs.backgroundColor)?.[1].split(',').map(Number)[3])??1;
 return {image:cs.backgroundImage,alpha,inside:[...h.querySelectorAll('.hp')].every(r=>{const b=r.getBoundingClientRect();return b.left>=box.left-.5&&b.right<=box.right+.5&&b.top>=box.top-.5&&b.bottom<=box.bottom+.5;}),
  names:[...h.querySelectorAll('.hp b')].map(b=>[getComputedStyle(b).fontSize,getComputedStyle(b).color])};});
for(const [tier,cap] of [['tall',6],['compact',3]])test(`CKP-PORT-50 ${tier}: at most ${cap} rows of owned models on no panel, names 10 px white`,async({page})=>{
 await open(page,{tier,sessions:[running('a','m6'),running('b','m7')]});
 await expect(page.locator('.hud .hp')).toHaveCount(cap);
 const b=await backing(page);
 expect(b.image).toBe('none');expect(b.alpha).toBe(0);expect(b.inside).toBe(true);// D371: the backing is gone (a scrim, not a panel)
 for(const [size,colour] of b.names)expect([size,colour]).toEqual(['10px','rgb(233, 237, 240)']);
});
test('CKP-PORT-51 a green dot follows the ★ effort of each model a session is running now, and only those',async({page})=>{
 await open(page,{sessions:[running('a','m7'),running('b','m6'),running('c','m5','idle')]});
 await expect(page.locator('.hud .hp .hp-on')).toHaveCount(2);
 for(const id of ['m7','m6']){const row=page.locator(`.hud .hp[data-hud-model=${id}]`),dot=row.locator('.hp-on');
  await expect(dot).toHaveCSS('background-color','rgb(90, 217, 186)');
  const [rec,mark]=await Promise.all([row.locator('.hp-rec').boundingBox(),dot.boundingBox()]);expect(mark.x).toBeGreaterThanOrEqual(rec.x+rec.width);expect(mark.width).toBeLessThanOrEqual(6);}
 await expect(page.locator('.hud .hp[data-hud-model=m5] .hp-on')).toHaveCount(0);
 await expect(page.locator('.hud .hp[data-hud-model=m7] .hp-on')).toHaveAttribute('aria-label','Running');
});
test('CKP-PORT-51 the compact strip keeps the dot inside its row',async({page})=>{
 await open(page,{tier:'compact',sessions:[running('a','m0')]});
 const row=page.locator('.hud.hud-strip .hp').first();await expect(row.locator('.hp-on')).toHaveCount(1);
 const [r,d,hud]=await Promise.all([row.boundingBox(),row.locator('.hp-on').boundingBox(),page.locator('.hud').boundingBox()]);
 expect(d.y).toBeGreaterThanOrEqual(r.y-.5);expect(d.y+d.height).toBeLessThanOrEqual(r.y+r.height+.5);expect(d.x+d.width).toBeLessThanOrEqual(hud.x+hud.width+.5);
});
