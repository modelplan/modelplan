// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell} from '../fixture.mjs';

for(const count of [5,6])test(`engine names remain visible with ${count} slots`,async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=sample(),accounts=data.projection.rows[0].accounts;
 while(data.projection.rows.length+accounts.length-1<count){const account=structuredClone(accounts[0]);account.subscriptionRef=null;account.accountLocator=null;accounts.push(account);}
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots',String(count));
 const names=page.locator('.eng-keys .ek[data-sub] .ek-name');await expect(names).toHaveCount(count);
 for(const name of await names.all()){await expect(name).toBeVisible();expect((await name.boundingBox()).width).toBeGreaterThan(0);await expect(name).not.toBeEmpty();}
});
