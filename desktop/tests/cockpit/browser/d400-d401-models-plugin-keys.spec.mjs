// SPDX-License-Identifier: MIT
// D400: the Models page is one page with one behaviour for both entries (a HUD click and the 模型 tab): the same page
// state, the user's list/chart choice kept, the same return behaviour. D401: a plugin key follows the subscription-key
// logic: selecting a plugin deselects the subscription, only the plugin key is lit, the overview restores the selection.
// Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));
const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
const model=(id,ability,cost)=>({id,name:'Synthetic '+id,developerId:'openai',recommended:'high',efforts:[effort('low',ability-8,cost/3),effort('high',ability,cost,true)]});
const models=Array.from({length:8},(_,i)=>model('m'+i,40+i,.1*(i+1)));
const on={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
async function open(page){
 const {data}=visualFixture();data.details.publishedModels=models;
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,range:'7d'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:on}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
// What the owner sees of the lower panel and the keys.
const snap=page=>page.evaluate(()=>{
 const shown=e=>!!e&&!e.hidden&&e.getClientRects().length>0,pg=document.querySelector('.dk-mfd .mfd-page');
 const lit=sel=>[...document.querySelectorAll(sel)].filter(k=>k.getAttribute('aria-pressed')==='true'||k.classList.contains('on')).map(k=>k.dataset.plugin||k.dataset.sub||(k.hasAttribute('data-all')?'all':k.dataset.mfd||k.className));
 return {
  page:shown(pg)?[...pg.classList].find(c=>c.startsWith('pg-')):null,
  view:pg?.querySelector('.fc')?'chart':pg?.querySelector('.md-list')?'list':null,
  selected:[...document.querySelectorAll('.dk-mfd .md-row.sel')].map(e=>e.dataset.model),
  pageKeys:lit('.dk-mfd .mfd-pk > .pk'),
  switchShown:shown(document.querySelector('.dk-mfd .mfd-pk .pk-seg')),
  back:document.querySelectorAll('.dk-mfd .mfd-back').length,
  subs:lit('.eng-keys .ek[data-sub]'),all:lit('.ek[data-all]'),plugins:lit('.eng-keys .pl-key'),
 };});
const hud=page=>page.locator('.hud .hp').first();
const tab=page=>page.locator('[data-mfd="page:tune"]');
const choice=(page,v)=>page.locator(`.mfd-ok [data-opt="models"] [data-choice="${v}"]`).click();
test('D400 a HUD click selects the model and keeps the list/chart choice the user last used',async({page})=>{
 await open(page);
 await hud(page).click();let s=await snap(page);
 expect(s.page).toBe('pg-tune');expect(s.view,'the default list stays a list').toBe('list');expect(s.selected.length).toBe(1);
 await choice(page,'chart');expect((await snap(page)).view).toBe('chart');
 await page.locator('[data-mfd="page:overview"]').click();
 await hud(page).click();s=await snap(page);expect(s.view,'the chart choice is kept').toBe('chart');
 await choice(page,'list');await page.locator('[data-mfd="page:overview"]').click();
 await hud(page).click();expect((await snap(page)).view).toBe('list');
});
test('D400 the 模型 tab opens the same page in the last-used view',async({page})=>{
 await open(page);
 await tab(page).click();expect((await snap(page)).view).toBe('list');
 await choice(page,'chart');await page.locator('[data-mfd="page:overview"]').click();
 await tab(page).click();expect((await snap(page)).view).toBe('chart');
});
test('D400 both entries give the same page state and the same return behaviour',async({page})=>{
 await open(page);
 const state=async()=>{const {selected,...rest}=await snap(page);return rest;};
 await tab(page).click();const viaTab=await state();
 await page.keyboard.press('Escape');const tabEsc=await state();
 await page.locator('[data-mfd="page:overview"]').click();
 await hud(page).click();const viaHud=await state();
 expect(viaHud).toEqual(viaTab);expect(viaHud.pageKeys).toEqual(['page:tune']);expect(viaHud.switchShown).toBe(false);expect(viaHud.back).toBe(0);
 await page.keyboard.press('Escape');expect(await state(),'Escape does the same from either entry').toEqual(tabEsc);
 // Leaving: the Overview key returns from either entry.
 await page.locator('[data-mfd="page:overview"]').click();expect((await snap(page)).page).toBe('pg-overview');
 await hud(page).click();await page.locator('[data-mfd="page:overview"]').click();expect((await snap(page)).page).toBe('pg-overview');
});
const key=(page,id)=>page.locator(`.eng-keys .pl-key[data-plugin="${id}"]`);
test('D401 selecting a plugin deselects the subscription: only the plugin key is lit',async({page})=>{
 await open(page);
 await page.keyboard.press('1');let s=await snap(page);expect(s.subs.length).toBe(1);const sub=s.subs[0];
 for(const id of ['calendar','resources']){
  await key(page,id).click();s=await snap(page);
  expect(s.subs,`${id}: no subscription lit`).toEqual([]);expect(s.all,`${id}: All not lit`).toEqual([]);expect(s.plugins).toEqual([id]);expect(s.pageKeys).toEqual([]);
  await page.keyboard.press('Escape');s=await snap(page);
  expect(s.subs,`${id}: Escape restores the selection`).toEqual([sub]);expect(s.plugins).toEqual([]);expect(s.pageKeys).toEqual(['page:overview']);
 }
});
test('D401 the overview, the switch and the same key all restore the previous selection',async({page})=>{
 await open(page);
 await page.keyboard.press('1');const sub=(await snap(page)).subs[0];
 await key(page,'calendar').click();await page.getByRole('tab',{name:'Overview'}).click();expect((await snap(page)).subs).toEqual([sub]);
 await key(page,'resources').click();await key(page,'resources').click();expect((await snap(page)).subs).toEqual([sub]);
 await key(page,'calendar').click();await key(page,'resources').click();const s=await snap(page);expect(s.plugins).toEqual(['resources']);expect(s.subs).toEqual([]);
 // Pressing the remembered subscription key brings it back (it is not toggled off); another one selects that one.
 await page.locator(`.eng-keys .ek[data-sub="${sub}"]`).click();let t=await snap(page);expect(t.subs).toEqual([sub]);expect(t.plugins).toEqual([]);
 await key(page,'calendar').click();await page.locator('.eng-keys .ek[data-sub]').nth(1).click();t=await snap(page);expect(t.subs.length).toBe(1);expect(t.subs[0]).not.toBe(sub);expect(t.plugins).toEqual([]);
 await key(page,'calendar').click();await page.locator('.ek[data-all]').click();t=await snap(page);expect(t.all).toEqual(['all']);expect(t.subs).toEqual([]);
});
test('D401 with All selected a plugin leaves nothing but the plugin key lit, and All returns',async({page})=>{
 await open(page);
 expect((await snap(page)).all).toEqual(['all']);
 await key(page,'calendar').click();let s=await snap(page);expect(s.all).toEqual([]);expect(s.plugins).toEqual(['calendar']);
 await page.keyboard.press('Escape');s=await snap(page);expect(s.all).toEqual(['all']);expect(s.plugins).toEqual([]);
});
