// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';

// D466: the calendar is the fixed 日历 page, not a plugin screen; these screen regressions run on Resources.
for (const plugin of ['resources']) test(`${plugin} followed by a HUD model shows the model`,async({page})=>{
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

test('Resources followed by a fader card shows its effort view',async({page})=>{
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await page.locator('.fd-ch:not(.empty) .fd-strip').first().click();
 await expect(page.locator('.mfd-screen .pl-screen')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
});

test('Resources followed by an effort-scale key shows its effort view',async({page})=>{
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator('.fd-ch:not(.empty) .fd-strip').first().click();
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await page.locator('.fd-scale .sc-l[data-level="Low"]').first().click();
 await expect(page.locator('.mfd-screen .pl-screen')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
});

test('Resources over a selected fader: re-click reveals the existing comparison without a trial',async({page})=>{
 test.setTimeout(90000);
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 const fader=page.locator('.fd-ch:not(.empty) .fd-strip[aria-label*="Astra"]').first();
 await expect(fader).toHaveAttribute('aria-label',/not reported|未报告/i);
 await fader.click();await expect(page.locator('.pg-compare')).toBeVisible();
 await expect(page.locator('.pg-compare .cmp-bars-row')).toHaveAttribute('data-trying','false');
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await fader.click();
 await expect(page.locator('.pl-screen')).toHaveCount(0);await expect(page.locator('.pg-compare')).toBeVisible();
 await expect(page.locator('.pg-compare .cmp-bars-row')).toHaveAttribute('data-trying','false');
 await fader.click();await expect(page.locator('.pg-compare')).toHaveCount(0);
});

test('Resources followed by ALERT reveals Alerts',async({page})=>{
 test.setTimeout(90000);
 await excludePortholeFlicker(page);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await page.locator('[data-caution]').click();
 await expect(page.locator('.pl-screen')).toHaveCount(0);await expect(page.locator('.pg-alerts')).toBeVisible();
});
