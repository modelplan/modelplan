// SPDX-License-Identifier: MIT
// spec-cockpit C-05: live locale, theme and page-key focus.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('C-05 live locale switches document language and accessible controls without moving focus',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const labels=page.locator('.mfd-pk button');const checkNames=async names=>{for(const [i,name] of names.entries())await expect(labels.nth(i)).toHaveAccessibleName(name);};const en=['Overview','Subscription','Effort','Breakdown'],zh=['总览','订阅','档位','去向'];const checkFit=async()=>{await expect(labels).toHaveCount(4);for(const label of await labels.all())expect(await label.evaluate(e=>e.scrollWidth<=e.clientWidth+1)).toBe(true);};
 await expect(page.locator('html')).toHaveAttribute('lang','en');await checkFit();await checkNames(en);const control=page.getByRole('button',{name:'Subscription',exact:true});await control.focus();await expect(control).toBeFocused();
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(page.locator('html')).toHaveAttribute('lang','zh-CN');await expect(page.getByRole('button',{name:'订阅',exact:true})).toBeFocused();await checkNames(zh);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN',theme:'day'}))).toBe(true);await expect(page.locator('html')).toHaveAttribute('data-theme','day');await expect(page.getByRole('button',{name:'订阅',exact:true})).toBeFocused();
 await checkFit();await checkNames(zh);
 expect(await receive(send('appearance',appearance))).toBe(true);await expect(page.locator('html')).toHaveAttribute('data-theme','night');await expect(page.locator('html')).toHaveAttribute('lang','en');await expect(page.getByRole('button',{name:'Subscription',exact:true})).toBeFocused();await checkNames(en);
});
