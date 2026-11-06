// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

test('CKP-STRIP-01 LBL-2.2-01 strip controls share one visible row',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance,shell}))).toBe(true);
 const selectors=['.ck-brand','[data-shutter]','.s6-alert','[data-settings]','[data-detach]','[data-close]'];
 const boxes=[];for(const selector of selectors){const element=page.locator(selector);await expect(element).toBeVisible();const box=await element.boundingBox();expect(box).not.toBeNull();boxes.push(box);}
 const centers=boxes.map(b=>b.y+b.height/2);for(const center of centers)expect(Math.abs(center-centers[0])).toBeLessThanOrEqual(2);
 for(let i=1;i<boxes.length;i++)expect(boxes[i].x).toBeGreaterThanOrEqual(boxes[i-1].x+boxes[i-1].width-1);
 await expect(page.locator('.ck-brand .wordmark')).toHaveText('ModelPlan');await expect(page.locator('.s6-alert span')).toHaveText('ALERT');
 for(const selector of ['[data-settings]','[data-detach]','[data-close]'])await expect(page.locator(selector)).toHaveText('');
 await expect(page.getByRole('button',{name:'?',exact:true})).toHaveCount(0);
});
