// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';

for (const plugin of ['calendar','resources']) test(`${plugin} followed by a HUD model shows the model`,async({page})=>{
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator(`.eng-keys .pl-key[data-plugin="${plugin}"]`).click();
 await expect(page.locator(`.mfd-screen .pl-screen[data-plugin="${plugin}"]`)).toBeVisible();
 await page.locator('.hud .hp').first().click();
 await expect(page.locator('.mfd-screen .pl-screen')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-tune')).toBeVisible();
});

test('Calendar followed by a fader card shows its effort view',async({page})=>{
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'calendar',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click();
 await page.locator('.fd-ch:not(.empty) .fd-strip').first().click();
 await expect(page.locator('.mfd-screen .pl-screen')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
});

test('Calendar followed by an effort-scale key shows its effort view',async({page})=>{
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'calendar',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator('.fd-ch:not(.empty) .fd-strip').first().click();
 await page.locator('.eng-keys .pl-key[data-plugin="calendar"]').click();
 await page.locator('.fd-scale .sc-l[data-level="Low"]').click();
 await expect(page.locator('.mfd-screen .pl-screen')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
});
