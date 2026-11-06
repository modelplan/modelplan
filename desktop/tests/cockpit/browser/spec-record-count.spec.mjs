// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('CKP-STRIP-08 record strip keeps five tall and three compact lines in both shell profiles',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:visualFixture().data})])expect(await receive(raw)).toBe(true);
 const lines=page.locator('.ck-tape .t-lines > .tl');
 for(const tier of ['tall','compact'])for(const profile of ['open','closed']){
  expect(await receive(send('shell',{...shell,tier,profile}))).toBe(true);
  await expect(lines).toHaveCount(tier==='tall'?5:3);
  await expect(page.locator('.ck-tape')).toBeVisible();
  for(const line of await lines.all())await expect(line).toBeVisible();
 }
});
