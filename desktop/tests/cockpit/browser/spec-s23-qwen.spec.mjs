// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('S23 canonical Qwen identity stays orange while quota status changes independently',async({page})=>{
 const data=currentSample(),row=data.projection.rows[0];data.projection.rows=[row];data.subscriptions=[];
 row.id='qwen';row.name={en:'Qwen',zh:'Qwen'};row.vendorKey=null;row.accounts[0].subscriptionRef=null;row.accounts[0].accountLocator=null;
 const w=row.accounts[0].windows[0];Object.assign(w,{id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main',remainingPercent:75});delete w.modelScope;
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const key=page.locator('.eng-keys .ek[data-sub]').first(),cell=page.locator('.eng-cols .ec .qcell[data-row=first]');
 const color=()=>key.locator('.bl').evaluate(e=>getComputedStyle(e).getPropertyValue('--v').trim());
 await expect(key).toBeVisible();expect(await color()).toBe('#ff6a00');await expect(key.locator('img')).toHaveCount(0);await expect(cell).toHaveClass(/lv-ok/);const normalInk=await cell.locator('.qvalue').evaluate(e=>getComputedStyle(e).color);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await expect(page.locator('.sa .chip').first()).toHaveCSS('--v','#ff6a00');
 w.remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);expect(await color()).toBe('#ff6a00');await expect(cell).toHaveClass(/lv-low/);expect(await cell.locator('.qvalue').evaluate(e=>getComputedStyle(e).color)).not.toBe(normalInk);
 row.id='synthetic-other';row.name={en:'Other',zh:'Other'};expect(await receive(send('display',{data}))).toBe(true);expect(await color()).not.toBe('#ff6a00');
});
