// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

for(const locale of ['en','zh-CN'])test(`credits use rounded grouped numbers in all cockpit surfaces (${locale})`,async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample(),account=data.projection.rows[0].accounts[0];
 account.credits={balance:19613.957,unit:'credits'};
 expect(await receive(send('load',{appearance:{...appearance,locale},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 const reserve=()=>page.locator('.eng-cols .ec').first().locator('.qrv-p');
 await expect(reserve()).toHaveText('19,614');
 await page.getByRole('button',{name:locale==='en'?'Subscription':'订阅',exact:true}).click();
 await expect(page.locator('.sa-list .sa').first().locator('.sa-r i').last()).toHaveText('19,614');
 account.credits.balance=0.25;expect(await receive(send('display',{data}))).toBe(true);
 await expect(reserve()).toHaveText('<1');await expect(page.locator('.sa-list .sa').first().locator('.sa-r i').last()).toHaveText('<1');
 account.credits.balance=19613.957;expect(await receive(send('display',{data}))).toBe(true);
 await page.locator('.sa-list .sa').first().click();await expect(page.locator('.mfd-page .cr-bal')).toHaveText('19,614');
 for(const [balance,expected] of [[0.1,'<1'],[0.999,'<1'],[0,'0'],[1,'1'],[999.6,'1,000']]){
  account.credits.balance=balance;expect(await receive(send('display',{data}))).toBe(true);
  await expect(reserve()).toHaveText(expected);await expect(page.locator('.mfd-page .cr-bal')).toHaveText(expected);
 }
 account.credits.balance=null;expect(await receive(send('display',{data}))).toBe(true);
 await expect(reserve()).toHaveCount(0);await expect(page.locator('.mfd-page .cr-bal')).toHaveCount(0);
});
