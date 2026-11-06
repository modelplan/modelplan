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

for(const locale of ['en','zh-CN'])test(`LBL-2.2-17 today and live speed help identify their basis (${locale})`,async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.details.sessions[0].rate=58;
 for(const raw of [send('load',{appearance:{...appearance,locale},shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await expect(page.locator('.t-live').first()).toContainText('58');
 await page.keyboard.down('Alt');const help=page.locator('#help-map');await expect(help).toBeVisible();
 await expect(help.locator('[data-target=".t-live"]')).toContainText(locale==='en'?'last 60 seconds':'近 60 秒');
 await expect(help.locator('[data-target=".lb-t,.qrow-t,.qaverage"]')).toContainText(locale==='en'?'today’s average':'今日平均');
 await page.keyboard.up('Alt');await expect(help).toBeHidden();
});
