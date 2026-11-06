// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('C-13 unavailable effort and breakdown pages show localized placeholders on the normal page',async({page})=>{
 test.setTimeout(90000);
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 for(const [locale,placeholder] of [['en','Data unavailable'],['zh-CN','暂无数据']]){
  expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
  for(const index of [2,3]){
   const button=page.locator('.mfd-pk button').nth(index),box=await button.boundingBox();expect(box).not.toBeNull();await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
   await expect(button).toHaveAttribute('aria-pressed','true');
   const empty=page.locator('.mfd-page .mp-empty').first();await expect(empty).toBeVisible();await expect(empty).toHaveText(placeholder);
   await expect(page.locator('.mfd-page [data-mfd^="session:"]')).toHaveCount(0);
  }
 }
});
