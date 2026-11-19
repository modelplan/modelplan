// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('COL-2.1-06 COL-2.1-07 quota status changes without changing vendor identity',async({page})=>{
 const data=currentSample(),row=data.projection.rows[0];data.projection.rows=[row];data.subscriptions=[];
 row.vendorKey='openai';row.accounts[0].subscriptionRef=null;row.accounts[0].accountLocator=null;
 const window=row.accounts[0].windows[0];Object.assign(window,{id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main',remainingPercent:75});delete window.modelScope;
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const key=page.locator('.eng-keys .ek[data-sub]').first(),cell=page.locator('.eng-cols .ec .qcell[data-row=first]');
 const identity=()=>key.locator('.bl').evaluate(e=>getComputedStyle(e).getPropertyValue('--v').trim());
 await expect(key).toBeVisible();expect(await identity()).toBe('#6aa8ff');await expect(cell).toHaveClass(/\blv-ok\b/);
 const normal=await cell.locator('.qvalue').evaluate(e=>getComputedStyle(e).color);
 window.remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);
 expect(await identity()).toBe('#6aa8ff');await expect(cell).toHaveClass(/\blv-low\b/);expect(await cell.locator('.qvalue').evaluate(e=>getComputedStyle(e).color)).not.toBe(normal);
});
