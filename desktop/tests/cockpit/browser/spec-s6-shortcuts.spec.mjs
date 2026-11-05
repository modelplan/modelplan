// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('S6 engine key digits are visible and exposed in tooltip, accessible name and Option help',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const first=page.locator('.eng-keys .ek[data-sub]').first(),all=page.locator('.ek[data-all]');
 await expect(first.locator('.ki')).toHaveText('1');await expect(first.locator('.ki')).toBeVisible();await expect(first).toHaveAttribute('aria-label',/Shortcut key 1/);await expect(first).toHaveAttribute('title',/Shortcut key 1/);await expect(all).toHaveAttribute('aria-label',/Shortcut key 0/);
 await page.keyboard.down('Alt');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('0 = All');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('1–6');await page.keyboard.up('Alt');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(first).toHaveAttribute('aria-label',/快捷键 1/);await expect(first).toHaveAttribute('title',/快捷键 1/);await expect(all).toHaveAttribute('aria-label',/快捷键 0/);
 await page.keyboard.down('Alt');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('快捷键');await page.keyboard.up('Alt');
});
