// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';
test('subscription reset uses the last supplied clock for future and past',async({page})=>{
 const now=Date.now(),data=currentSample();
 for(const row of data.projection.rows)for(const account of row.accounts){
  account.freshUntil=new Date(now+86400000).toISOString();
  for(const w of account.windows){w.validUntil=account.freshUntil;w.resetsAt=new Date(now+138*60000).toISOString();}
 }
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 expect(await receive(send('tick',{nowUnixMs:String(now),reason:'clockChange'}))).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 const first=page.locator('.sa-list .sa').first();await expect(first).toContainText('in 2h18');
 expect(await receive(send('tick',{nowUnixMs:String(now+140*60000),reason:'clockChange'}))).toBe(true);
 await expect(first).toContainText('2m ago');
 // Page interactions must keep the supplied tick time, not consult the host clock.
 await page.getByRole('button',{name:'Overview',exact:true}).click();
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await expect(first).toContainText('2m ago');
});
