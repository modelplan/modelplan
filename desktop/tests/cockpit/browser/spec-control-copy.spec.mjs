// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('LBL-2.2-02 page-key silkscreens use short localized labels',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const labels=page.locator('.mfd-pk button');await expect(labels).toHaveCount(4);
 for(const [i,text] of ['Overview','Subscription','Effort','Breakdown'].entries()){await expect(labels.nth(i)).toBeVisible();await expect(labels.nth(i)).toHaveText(text);expect(text.split(/\s+/).length).toBeLessThanOrEqual(2);}
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 for(const [i,text] of ['总览','订阅','档位','去向'].entries()){await expect(labels.nth(i)).toBeVisible();await expect(labels.nth(i)).toHaveText(text);}
});
