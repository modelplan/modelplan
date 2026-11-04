// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';
test('load and appearance share the inclusive threshold across engine and deck',async({page})=>{
 const data=currentSample();for(const row of data.projection.rows)for(const account of row.accounts)for(const w of account.windows)w.remainingPercent=20;
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:10}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-mid').first()).toBeVisible();
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await expect(page.locator('.sa-list .sa').first().locator('.v.lv-mid')).toHaveText('20%');
 expect(await receive(send('appearance',{...appearance,redBelow:20}))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-low').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-low')).toHaveText('20%');
 expect(await receive(send('appearance',{...appearance,redBelow:10}))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-mid').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-mid')).toHaveText('20%');
 expect(await receive(send('appearance',{...appearance,redBelow:17}))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-low').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-low')).toHaveText('20%');
 expect(await receive(send('appearance',appearance))).toBe(true);
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-low').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-low')).toHaveText('20%');
});
