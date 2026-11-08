// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-53 / CKP-PORT-09 (owner Build 12: "开关窗也没效果"): a real click on the shutter asks the native shell to
// toggle, and the shell reply closes the porthole at both heights. The short profile only loses its 48 px canopy
// band (627 -> 609), which is why the change was hard to see there; the full profile drops 186 px (877 -> 691).
for(const [tier,canvas,open,closed] of [['compact',661,627,609],['tall',911,877,691]])
test(`G3-53 ${tier}: the shutter click toggles the porthole`,async({page})=>{
 await page.addInitScript(()=>{window.__ev=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__ev.push(JSON.parse(raw));}}}};});
 await page.setViewportSize({width:636,height:canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const shutter=page.locator('[data-shutter]'),root=()=>page.evaluate(()=>document.querySelector('.ck').getBoundingClientRect().height);
 await expect(shutter).toBeEnabled();expect(await root()).toBe(open);
 await shutter.click();
 expect(await page.evaluate(()=>window.__ev.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['shutterToggle']);
 expect(await receive(send('shell',{...shell,tier,profile:'closed'}))).toBe(true);
 await expect(shutter).toHaveAttribute('aria-pressed','true');
 await expect.poll(root).toBe(closed);
 expect(await page.evaluate(()=>getComputedStyle(document.querySelector('.ck-portrow')).visibility)).toBe('hidden');
 await shutter.click();
 expect(await page.evaluate(()=>window.__ev.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['shutterToggle','shutterToggle']);
 expect(await receive(send('shell',{...shell,tier,profile:'open'}))).toBe(true);
 await expect(shutter).toHaveAttribute('aria-pressed','false');await expect.poll(root).toBe(open);
});
