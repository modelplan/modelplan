// SPDX-License-Identifier: MIT
// Porthole step 1: the official edition paints the default public fleet's baked still, statically.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell} from '../fixture.mjs';
const projections={'night-tall':'4ff2bad27654','day-tall':'52b72f54aee9','night-compact':'a92b7ce62cfe','day-compact':'28592ba812cd'};
async function open(page,theme,tier){
  await page.setViewportSize({width:636,height:tier==='tall'?890:640});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier}}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:sample()}))).toBe(true);
  return {send,receive};
}
const state=page=>page.evaluate(()=>{
  const field=document.querySelector('.ck-field'),port=document.querySelector('.ck-port').getBoundingClientRect(),box=field.getBoundingClientRect();
  return {still:field.dataset.still,projection:field.querySelector('.ck-still')?.dataset.projection??null,
    layers:field.querySelectorAll('.ck-still-layer').length,additive:field.querySelectorAll('.ck-still-add').length,
    media:field.querySelectorAll('img,svg,canvas,video').length,
    animations:document.getAnimations().filter(a=>a.effect?.target?.closest?.('.ck-field')).length,
    covers:Math.abs(box.width-document.querySelector('.ck-port').clientWidth)<1&&box.height>0&&box.top>=port.top,
    blend:getComputedStyle(field.querySelector('.ck-still-add')).mixBlendMode};
});
for(const theme of ['night','day'])for(const tier of ['tall','compact'])test(`porthole still ${theme} ${tier}`,async({page})=>{
  await open(page,theme,tier);
  await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
  const s=await state(page);
  // Background + flame, halo and body for each of the seven default-fleet models.
  expect(s).toEqual({still:'ready',projection:projections[`${theme}-${tier}`],layers:22,additive:14,media:0,animations:0,covers:true,blend:'plus-lighter'});
  // Every layer image is part of the bundle and loads.
  const urls=await page.locator('.ck-still-layer').evaluateAll(es=>es.map(e=>getComputedStyle(e).backgroundImage.slice(5,-2)));
  for(const url of urls)expect((await page.request.get(url)).status(),url).toBe(200);
});
test('porthole still follows live theme and layout changes and stays static',async({page})=>{
  const {send,receive}=await open(page,'night','tall');
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['night-tall']);
  expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['day-tall']);
  await page.setViewportSize({width:636,height:640});
  expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['day-compact']);
  expect((await state(page)).animations).toBe(0);
});
