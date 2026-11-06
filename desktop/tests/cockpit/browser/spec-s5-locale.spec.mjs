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

test('LBL-2.2-16 ALERT remains English on the lamp in both locales',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 const lamp=page.locator('.s6-alert');await expect(lamp).toBeVisible();
 await expect(lamp.locator('span')).toHaveText('ALERT');await expect(lamp).toHaveAccessibleName('Alert inactive');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(lamp.locator('span')).toHaveText('ALERT');await expect(lamp).toHaveAccessibleName('告警未激活');
});

test('CKP-STRIP-04 alert lamp is rectangular and shares the header key height',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance,shell}))).toBe(true);
 const lamp=page.locator('.s6-alert'),key=page.locator('[data-settings]');await expect(lamp).toBeVisible();await expect(key).toBeVisible();
 const sizes=await page.evaluate(()=>{const a=document.querySelector('.s6-alert').getBoundingClientRect(),b=document.querySelector('[data-settings]').getBoundingClientRect();return {width:a.width,height:a.height,keyHeight:b.height};});
 expect(sizes.width).toBeGreaterThan(sizes.height);expect(Math.abs(sizes.height-sizes.keyHeight)).toBeLessThanOrEqual(1);
 await expect(lamp.locator('span')).toHaveText('ALERT');await expect(lamp).toHaveAccessibleName('Alert inactive');
});

test('CKP-MFD-01 page screen stays beside faders without an expand key',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const screen=page.locator('.mfd-screen'),faders=page.locator('.dk-fad');await expect(screen).toBeVisible();await expect(faders).toBeVisible();
 const a=await screen.boundingBox(),b=await faders.boundingBox();expect(a).not.toBeNull();expect(b).not.toBeNull();
 expect(a.x).toBeGreaterThanOrEqual(b.x+b.width-1);expect(a.width).toBeGreaterThan(b.width/2);
 await expect(page.getByRole('button',{name:/expand|扩大|展开/i})).toHaveCount(0);
});

test('CKP-MFD-02 page keys show the active selection in both locales',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const keys=page.locator('.mfd-pk button');await expect(keys).toHaveCount(4);
 for(const [i,name] of ['Overview','Subscription','Effort','Breakdown'].entries()){
  await expect(keys.nth(i)).toHaveAccessibleName(name);await expect(keys.nth(i)).toBeVisible();const r=await keys.nth(i).boundingBox();expect(r).not.toBeNull();await page.mouse.click(r.x+r.width/2,r.y+r.height/2);
  for(let j=0;j<4;j++){await expect(keys.nth(j)).toHaveAttribute('aria-pressed',String(i===j));if(i===j)await expect(keys.nth(j)).toHaveClass(/\bon\b/);else await expect(keys.nth(j)).not.toHaveClass(/\bon\b/);}
 }
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 for(const [i,name] of ['总览','订阅','档位','去向'].entries())await expect(keys.nth(i)).toHaveAccessibleName(name);
});
