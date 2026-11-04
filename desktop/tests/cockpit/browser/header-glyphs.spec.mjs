// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

test('official built header displays each approved control glyph',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance,shell}))).toBe(true);
 const cases=[
  {selector:'[data-settings]',part:'::before',property:'backgroundImage',asset:'gear-normal@3x.png'},
  {selector:'[data-close]',part:'::before',property:'backgroundImage',asset:'close-normal@3x.png'},
  {selector:'[data-detach] .detach-glyph',part:null,property:'webkitMaskImage',asset:'detach.svg'},
  {selector:'[data-shutter] .shutter-thumb',part:null,property:'backgroundImage',asset:'thumb-open@3x.png'},
  {selector:'.s6-alert',part:'::after',property:'backgroundImage',asset:'lamp-off-body@3x.png'},
 ];
 for(const item of cases){
  const node=page.locator(item.selector);await expect(node).toBeVisible();
  const paint=await node.evaluate((el,{part,property})=>{const s=getComputedStyle(el,part),r=el.getBoundingClientRect();return {value:s[property],opacity:Number(s.opacity),visibility:s.visibility,width:r.width,height:r.height};},item);
  expect(paint.visibility).toBe('visible');expect(paint.opacity).toBeGreaterThan(0);expect(paint.width).toBeGreaterThan(0);expect(paint.height).toBeGreaterThan(0);
  const urls=[...paint.value.matchAll(/url\(["']?([^"')]+)["']?\)/g)].map(m=>m[1]);
  const url=urls.find(value=>value.endsWith('/'+item.asset));expect(url,`${item.selector} missing ${item.asset}`).toBeTruthy();
  expect(await page.evaluate(src=>new Promise(resolve=>{const image=new Image();image.onload=()=>resolve(image.naturalWidth>0&&image.naturalHeight>0);image.onerror=()=>resolve(false);image.src=src;}),url)).toBe(true);
 }
 expect(await page.locator('.private-content img').count()).toBe(0);
});
