// SPDX-License-Identifier: MIT
// WP-21 lane B, spec 1: the cockpit key and selection rules on the built page through its normal bridge, synthetic data only.
// Covers the key families that had owner defects: subscription keys, plugin keys, the All key, the date keys, the number
// shortcuts and the Settings key. The keyboard-ring rule (G3-153, G3-165) is owned by #1153 / #1163 and not repeated here.
// CKP-ENG-21 (re-press returns to All) stays in ckp-eng-21-key-toggle.spec.mjs; D387/D400/D401 journeys stay in their specs.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const on={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
async function open(page,{range='7d'}={}){
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:on}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 return {send,receive};
}
const actions=(page,name)=>page.evaluate(n=>window.sent.filter(m=>m.type==='action'&&m.action===n).map(m=>m.key??m.range??m.value??null),name);
// Every lit key of the engine strip, by family. A key is lit by aria-pressed or the "on" class, as the owner sees it.
const lit=page=>page.evaluate(()=>{
 const is=k=>k.getAttribute('aria-pressed')==='true'||k.classList.contains('on');
 return {
  subs:[...document.querySelectorAll('.eng-keys .ek[data-sub]')].filter(is).map(k=>k.dataset.sub),
  all:[...document.querySelectorAll('.ek[data-all]')].filter(is).length,
  plugins:[...document.querySelectorAll('.eng-keys .pl-key')].filter(is).map(k=>k.dataset.plugin),
 };});
const total=s=>s.subs.length+s.all+s.plugins.length;
const sub=(page,i)=>page.locator('.eng-keys .ek[data-sub]').nth(i);
const plugin=(page,id)=>page.locator(`.eng-keys .pl-key[data-plugin="${id}"]`);

test('G3-174 G3-212 exactly one key of the strip is lit at any time: a subscription, All, Calendar or Resources',async({page})=>{
 await open(page);
 let s=await lit(page);expect(s.all,'All is lit on first open').toBe(1);expect(total(s)).toBe(1);
 const subs=await page.locator('.eng-keys .ek[data-sub]').count();expect(subs).toBeGreaterThan(1);
 for(let i=0;i<Math.min(subs,3);i++){
  await sub(page,i).click();s=await lit(page);
  expect(total(s),`subscription key ${i} alone`).toBe(1);expect(s.subs).toHaveLength(1);
 }
 for(const id of ['calendar','resources']){
  await plugin(page,id).click();s=await lit(page);
  expect(s,`${id} alone is lit and pressed`).toEqual({subs:[],all:0,plugins:[id]});
  await expect(plugin(page,id)).toHaveAttribute('aria-pressed','true');
 }
 // Pressing the other plugin moves the light, it never adds one.
 await plugin(page,'calendar').click();s=await lit(page);expect(s.plugins).toEqual(['calendar']);expect(total(s)).toBe(1);
 await page.locator('.ek[data-all]').click();s=await lit(page);expect(s).toEqual({subs:[],all:1,plugins:[]});
 await expect(plugin(page,'calendar')).toHaveAttribute('aria-pressed','false');
});

test('G3-212 CKP-ENG-21 a plugin key is a screen key: it posts no scope change, and pressing it again closes the screen',async({page})=>{
 await open(page);
 await sub(page,0).click();const before=await actions(page,'scopeSelect');expect(before).toHaveLength(1);
 await plugin(page,'resources').click();
 await expect(page.locator('.pl-screen[data-plugin="resources"]')).toHaveCount(1);
 expect(await actions(page,'scopeSelect'),'opening a plugin does not change the app scope').toEqual(before);
 await plugin(page,'resources').click();
 await expect(page.locator('.pl-screen')).toHaveCount(0);
 expect((await lit(page)).subs,'the remembered subscription is lit again').toHaveLength(1);
 expect(await actions(page,'scopeSelect')).toEqual(before);
});

test('CKP-ENG-21 re-pressing the selected subscription key from a plugin screen only brings the subscription back (D401)',async({page})=>{
 await open(page);
 await sub(page,0).click();const ref=(await lit(page)).subs[0];
 await plugin(page,'calendar').click();
 await sub(page,0).click();
 expect(await lit(page)).toEqual({subs:[ref],all:0,plugins:[]});
 await expect(page.locator('.pl-screen')).toHaveCount(0);
 // The next press is the toggle: back to All.
 await sub(page,0).click();expect((await lit(page)).all).toBe(1);
});

test('CKP-SHELL-50 G3-175 the number keys select: 0 is All, 1..n the nth subscription, from any screen',async({page})=>{
 await open(page);
 const n=await page.locator('.eng-keys .ek[data-sub]').count();
 for(let i=1;i<=Math.min(n,4);i++){
  await page.keyboard.press(String(i));
  const s=await lit(page);expect(s.subs,`key ${i}`).toEqual([await sub(page,i-1).getAttribute('data-sub')]);expect(total(s)).toBe(1);
 }
 await plugin(page,'calendar').click();
 await page.keyboard.press('2');
 await expect(page.locator('.pl-screen')).toHaveCount(0);
 expect(await lit(page),'a number key closes the plugin screen and selects that subscription').toEqual({subs:[await sub(page,1).getAttribute('data-sub')],all:0,plugins:[]});
 await page.keyboard.press('0');expect(await lit(page)).toEqual({subs:[],all:1,plugins:[]});
 // A number key is a select, not a toggle: pressing the selected one again keeps it.
 await page.keyboard.press('1');const sent=(await actions(page,'scopeSelect')).length;
 await page.keyboard.press('1');expect((await lit(page)).subs).toHaveLength(1);
 expect((await actions(page,'scopeSelect')).slice(sent).every(k=>k!=='all')).toBe(true);
});

test('CKP-SHELL-50 the number keys and T are ignored with a modifier, and while a text field has the focus',async({page})=>{
 await open(page);
 const sentBefore=async()=>(await actions(page,'scopeSelect')).length+(await actions(page,'rangeSelect')).length;
 const base=await sentBefore();
 for(const combo of ['Control+1','Meta+1','Alt+1','Shift+1','Control+t','Meta+t'])await page.keyboard.press(combo);
 expect(await sentBefore(),'modified keys select nothing').toBe(base);
 await page.evaluate(()=>{const i=document.createElement('input');i.id='typing';document.querySelector('#cockpit').append(i);i.focus();});
 await page.keyboard.type('12t0');
 expect(await sentBefore(),'typing into a field selects nothing').toBe(base);
 expect(await page.locator('#typing').inputValue()).toBe('12t0');
});

test('CKP-SHELL-50 the date keys are one radio group: the clicked key is checked, the request is typed, the scope is untouched',async({page})=>{
 await open(page,{range:'7d'});
 const checked=()=>page.locator('[data-range-key][aria-checked="true"]').evaluateAll(k=>k.map(e=>e.dataset.rangeKey));
 expect(await checked()).toEqual(['7d']);
 await sub(page,0).click();const scope=await lit(page);
 await page.locator('[data-range-key="30d"]').click();expect(await checked()).toEqual(['30d']);
 await page.locator('[data-range-key="today"]').click();expect(await checked()).toEqual(['today']);
 expect(await actions(page,'rangeSelect')).toEqual(['30d','today']);
 expect(await lit(page),'choosing a range never moves the selected key').toEqual(scope);
 // Clicking the checked key again re-requests it, it never unchecks.
 await page.locator('[data-range-key="today"]').click();expect(await checked()).toEqual(['today']);
 // T walks Today, 7d, 30d, Today.
 await page.keyboard.press('t');expect(await checked()).toEqual(['7d']);
 await page.keyboard.press('t');expect(await checked()).toEqual(['30d']);
 await page.keyboard.press('t');expect(await checked()).toEqual(['today']);
});

test('CKP-SHELL-50 the date keys keep one tab stop: only the checked key is tabbable, arrows move the choice',async({page})=>{
 await open(page,{range:'7d'});
 const stops=()=>page.locator('[data-range-key]').evaluateAll(k=>k.filter(e=>e.tabIndex===0).map(e=>e.dataset.rangeKey));
 expect(await stops()).toEqual(['7d']);
 await page.locator('[data-range-key="7d"]').focus();
 await page.keyboard.press('ArrowRight');expect(await stops()).toEqual(['30d']);
 await page.keyboard.press('ArrowRight');expect(await stops()).toEqual(['today']);
 await page.keyboard.press('ArrowLeft');expect(await stops()).toEqual(['30d']);
 expect(await actions(page,'rangeSelect')).toEqual(['30d','today','30d']);
});

test('G3-60 the Settings key keeps its strip slot beside the detach and close keys and asks the app to open Settings',async({page})=>{
 await open(page);
 const box=s=>page.locator('.ck-head '+s).boundingBox();
 const [settings,detach,close]=[await box('[data-settings]'),await box('[data-detach]'),await box('[data-close]')];
 expect(settings&&detach&&close).toBeTruthy();
 expect(settings.x,'Settings, then detach, then close').toBeLessThan(detach.x);expect(detach.x).toBeLessThan(close.x);
 await page.locator('.ck-head [data-settings]').click();
 expect(await actions(page,'openSettings')).toHaveLength(1);
});
