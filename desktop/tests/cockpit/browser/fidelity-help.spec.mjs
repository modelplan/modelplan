// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';
for(const locale of ['en','zh-CN'])test(`Option help follows the visible cockpit (${locale})`,async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 const map=page.locator('#help-map');await expect(map).toBeHidden();
 await page.keyboard.down('Alt');await expect(map).toBeVisible();
 await expect(map.locator('[data-target="[data-settings]"]')).toContainText(locale==='en'?'Settings:':'设置：');
 await expect(map.locator('[data-target=".dk-fad"]')).toContainText(locale==='en'?'Faders:':'推杆：');
 await page.keyboard.up('Alt');await expect(map).toBeHidden();
 await page.keyboard.down('Alt');await page.keyboard.press('Escape');await expect(map).toBeHidden();await page.keyboard.up('Alt');
 await page.keyboard.down('Alt');await expect(map).toBeVisible();await page.mouse.click(1,1);await expect(map).toBeHidden();await page.keyboard.up('Alt');
});
