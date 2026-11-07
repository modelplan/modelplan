// SPDX-License-Identifier: MIT
// S18/S22: host preference reaches the real page without changing geometry.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('S18 S22 reduced transparency gives the porthole an opaque backing in both themes and sizes',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const pane=page.locator('.ck-port'),deck=page.locator('.ck-deck'),tape=page.locator('.ck-tape');
 for(const tier of ['tall','compact'])for(const theme of ['day','night']){
  await page.setViewportSize({width:636,height:tier==='tall'?890:640});
  expect(await receive(send('shell',{...shell,tier}))).toBe(true);
  expect(await receive(send('appearance',{...appearance,theme,reduceTransparency:false}))).toBe(true);
  const before=await Promise.all([pane.boundingBox(),deck.boundingBox(),tape.boundingBox()]);
  expect(await receive(send('appearance',{...appearance,theme,reduceTransparency:true}))).toBe(true);
  const resolved=await pane.evaluate(e=>({background:getComputedStyle(e).backgroundColor,backdrop:getComputedStyle(e).backdropFilter}));
  expect(resolved.background).toMatch(/^rgb\(/);expect(resolved.backdrop).toBe('none');
  expect(await Promise.all([pane.boundingBox(),deck.boundingBox(),tape.boundingBox()])).toEqual(before);
  expect(await receive(send('appearance',{...appearance,theme,reduceTransparency:false}))).toBe(true);
  expect(await pane.evaluate(e=>getComputedStyle(e).backgroundColor)).toBe('rgb(23, 30, 38)');
 }
});

test('S27 the porthole remains dark over a light host in both themes without reduced transparency',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.evaluate(()=>{document.body.style.background='white'});
 for(const theme of ['day','night']){
  expect(await receive(send('appearance',{...appearance,theme,reduceTransparency:false}))).toBe(true);
  const rgb=await page.locator('.ck-port').evaluate(e=>getComputedStyle(e).backgroundColor);
  const channels=rgb.match(/^rgb\((\d+), (\d+), (\d+)\)$/);expect(channels).not.toBeNull();
  expect(Math.max(...channels.slice(1).map(Number))).toBeLessThan(64);
 }
});
