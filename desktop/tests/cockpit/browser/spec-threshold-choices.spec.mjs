// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('C-07 C-23 shared threshold choices use inclusive remaining quota and legacy fallback',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample();data.projection.rows=data.projection.rows.slice(0,1);data.subscriptions=[];const account=data.projection.rows[0].accounts[0];account.subscriptionRef=null;account.accountLocator=null;const w=account.windows[0];Object.assign(w,{id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main'});delete w.modelScope;
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const cell=page.locator('.eng-cols .ec .qcell[data-row=first]');
 for(const threshold of [10,15,20,25,30,40]){
  expect(await receive(send('appearance',{...appearance,redBelow:threshold}))).toBe(true);
  w.remainingPercent=threshold;expect(await receive(send('display',{data}))).toBe(true);await expect(cell).toHaveClass(/lv-low/);
  w.remainingPercent=threshold+1;expect(await receive(send('display',{data}))).toBe(true);await expect(cell).not.toHaveClass(/lv-low/);
 }
 expect(await receive(send('appearance',{...appearance,redBelow:16}))).toBe(true);w.remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(cell).toHaveClass(/lv-low/);
 w.remainingPercent=26;expect(await receive(send('display',{data}))).toBe(true);await expect(cell).not.toHaveClass(/lv-low/);
});

test('C-07 C-23 D22 warning band is consistent in engine, Subscription and caution',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample();data.details=null;data.projection.rows=data.projection.rows.slice(0,1);data.subscriptions=[];const account=data.projection.rows[0].accounts[0];account.subscriptionRef=null;account.accountLocator=null;const w=account.windows[0];Object.assign(w,{id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main'});delete w.modelScope;account.windows=[w];
 for(const raw of [send('load',{appearance,shell,redBelow:40}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();const cell=page.locator('.eng-cols .ec .qcell[data-row=first]'),value=page.locator('.sa-list .sa').first().locator('.v'),lamp=page.locator('[data-caution]');
 for(const [threshold,remaining,level] of [[40,40,'low'],[40,41,'mid'],[40,50,'mid'],[40,51,'ok'],[10,11,'mid'],[25,50,'mid']]){expect(await receive(send('appearance',{...appearance,redBelow:threshold}))).toBe(true);w.remainingPercent=remaining;expect(await receive(send('display',{data}))).toBe(true);await expect(cell).toHaveClass(new RegExp('lv-'+level));await expect(value).toHaveClass(new RegExp('lv-'+level));if(level==='ok')await expect(lamp).not.toHaveClass(/\blit\b/);else await expect(lamp).toHaveClass(/\blit\b/);}
 w.remainingPercent=null;expect(await receive(send('display',{data}))).toBe(true);await expect(cell.locator('.qvalue')).toHaveText('--');await expect(lamp).not.toHaveClass(/\blit\b/);
});
