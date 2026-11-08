// SPDX-License-Identifier: MIT
// Porthole step 1: the official edition paints the default public fleet's baked still; flames and halos flicker
// (owner D39/D-H) only on an active, open page and never under Reduce Motion.
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
    // The field covers the whole port (and, in the official edition, the canopy window around it: d-porthole-frame).
    covers:box.left<=port.left&&box.right>=port.right&&box.top<=port.top&&box.height>0,
    blend:getComputedStyle(field.querySelector('.ck-still-add')).mixBlendMode};
});
for(const theme of ['night','day'])for(const tier of ['tall','compact'])test(`porthole still ${theme} ${tier}`,async({page})=>{
  await open(page,theme,tier);
  await expect(page.locator('.ck-field')).toHaveAttribute('data-still','ready');
  const s=await state(page);
  // Background + flame, halo and body for each of the seven default-fleet models.
  expect(s).toEqual({still:'ready',projection:projections[`${theme}-${tier}`],layers:22,additive:14,media:0,animations:14,covers:true,blend:'plus-lighter'});
  // Every layer image is part of the bundle and loads.
  const urls=await page.locator('.ck-still-layer').evaluateAll(es=>es.map(e=>getComputedStyle(e).backgroundImage.slice(5,-2)));
  for(const url of urls)expect((await page.request.get(url)).status(),url).toBe(200);
});
test('porthole still follows live theme and layout changes',async({page})=>{
  const {send,receive}=await open(page,'night','tall');
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['night-tall']);
  expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['day-tall']);
  await page.setViewportSize({width:636,height:640});
  expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
  await expect(page.locator('.ck-still')).toHaveAttribute('data-projection',projections['day-compact']);
  expect((await state(page)).animations).toBe(14);
});
test('porthole flicker follows the prototype timing and stops on every gate',async({page})=>{
  const {send,receive}=await open(page,'night','tall');
  await expect.poll(async()=>(await state(page)).animations).toBe(14);
  const timing=await page.evaluate(()=>document.getAnimations().filter(a=>a.effect.target.closest('.ck-still')).map(a=>{const t=a.effect.getTiming(),e=a.effect.target;return {d:t.duration,delay:t.delay,unbounded:!Number.isFinite(t.iterations),dir:t.direction,ease:getComputedStyle(e).animationTimingFunction,flame:e.classList.contains('ck-still-flame')||e.classList.contains('ck-still-halo'),origin:getComputedStyle(e).transformOrigin};}));
  // Prototype composer.js:26: period 0.43 + (i mod 4) x 0.07 s, phase -(i mod 3) x 0.13 s, alternate, about the nozzle.
  expect(new Set(timing.map(t=>t.d))).toEqual(new Set([430,500,570,640]));expect(new Set(timing.map(t=>t.delay))).toEqual(new Set([0,-130,-260]));
  expect(timing.every(t=>t.unbounded&&t.dir==='alternate'&&t.ease==='ease-in-out'&&t.flame&&t.origin!=='50% 50%')).toBe(true);
  const frames=await page.evaluate(()=>document.getAnimations().find(a=>a.effect.target.closest('.ck-still')).effect.getKeyframes().map(k=>[k.opacity,k.transform]));
  expect(frames).toEqual([['0.94','scale(0.985, 0.98)'],['1','scale(1.015, 1.02)']]);
  // Host Reduce Motion, then the system setting, then a closed shutter and a hidden page each leave it static.
  expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);await expect.poll(async()=>(await state(page)).animations).toBe(0);
  expect(await receive(send('appearance',appearance))).toBe(true);await expect.poll(async()=>(await state(page)).animations).toBe(14);
  await page.emulateMedia({reducedMotion:'reduce'});await expect.poll(async()=>(await state(page)).animations).toBe(0);
  await page.emulateMedia({reducedMotion:'no-preference'});await expect.poll(async()=>(await state(page)).animations).toBe(14);
  expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);await expect.poll(async()=>(await state(page)).animations).toBe(0);
  expect(await receive(send('shell',shell))).toBe(true);await expect.poll(async()=>(await state(page)).animations).toBe(14);
  expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);await expect.poll(async()=>(await state(page)).animations).toBe(0);
});
