// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,currentSample,pageId,shell} from '../fixture.mjs';
test('engine and deck share the same inclusive configurable threshold',async({page})=>{
 const data=currentSample();for(const row of data.projection.rows)for(const account of row.accounts)for(const w of account.windows)w.remainingPercent=20;
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 await page.evaluate(async({data,appearance,shell})=>{
  document.querySelector('#cockpit').remove();const root=document.createElement('main');root.id='cockpit';document.body.append(root);
  const {mountCockpit}=await import('/src/view.js');window.testThreshold=10;window.testCockpit=mountCockpit(root,()=>{},()=>window.testThreshold);
  window.testCockpit.configure(appearance);window.testCockpit.shell(shell);window.testCockpit.active(true);window.testCockpit.render(data,Date.now());
 },{data,appearance,shell});
 const cell=page.locator('.eng-cols .ec').first().locator('.qcell.lv-mid');await expect(cell.first()).toBeVisible();
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await expect(page.locator('.sa-list .sa').first().locator('.v.lv-mid')).toHaveText('20%');
 await page.evaluate(()=>{window.testThreshold=20;window.testCockpit.tick(Date.now());});
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-low').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-low')).toHaveText('20%');
 await page.evaluate(()=>{window.testThreshold=17;window.testCockpit.tick(Date.now());});
 await expect(page.locator('.eng-cols .ec').first().locator('.qcell.lv-low').first()).toBeVisible();
 await expect(page.locator('.sa-list .sa').first().locator('.v.lv-low')).toHaveText('20%');
 await page.evaluate(()=>window.testCockpit.dispose());
});
