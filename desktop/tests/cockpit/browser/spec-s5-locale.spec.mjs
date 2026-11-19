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

test('CKP-MFD-03 LBL-2.2-03 option keys show choices and switch the active LED without moving',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const slots=page.locator('.mfd-ok > *');await expect(slots).toHaveCount(3);
 const boxes=await slots.evaluateAll(nodes=>nodes.map(n=>{const r=n.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};}));
 for(const box of boxes)expect(Math.abs(box.y-boxes[0].y)).toBeLessThanOrEqual(1);
 const chart=page.locator('[data-opt="chart"]'),choices=chart.locator('[data-choice]');await expect(choices).toHaveCount(2);
 await expect(choices.nth(0)).toHaveClass(/\bon\b/);await expect(choices.nth(1)).not.toHaveClass(/\bon\b/);
 const led=await choices.nth(0).evaluate(e=>{const s=getComputedStyle(e,'::after');return {content:s.content,height:parseFloat(s.height),background:s.backgroundColor};});
 expect(led.content).toBe('""');expect(led.height).toBeGreaterThan(0);expect(led.background).not.toBe('rgba(0, 0, 0, 0)');
 await expect(chart).not.toContainText('▾');await expect(chart).not.toContainText('▼');
 const before=await chart.boundingBox(),target=await choices.nth(1).boundingBox();expect(before).not.toBeNull();expect(target).not.toBeNull();
 await page.mouse.click(target.x+target.width/2,target.y+target.height/2);
 await expect(choices.nth(1)).toHaveClass(/\bon\b/);await expect(choices.nth(0)).not.toHaveClass(/\bon\b/);
 const after=await chart.boundingBox();for(const k of ['x','y','width','height'])expect(Math.abs(after[k]-before[k])).toBeLessThanOrEqual(1);
});

test('CKP-STRIP-07 Option help tracks detach state without moving the header',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 await expect(page.getByRole('button',{name:'?',exact:true})).toHaveCount(0);
 const target=page.locator('[data-detach]'),before=await target.boundingBox();expect(before).not.toBeNull();
 await page.keyboard.down('Alt');const help=page.locator('#help-map');await expect(help).toBeVisible();
 await expect(help.locator('[data-target="[data-detach]"]')).toContainText('Detach');
 const during=await target.boundingBox();for(const k of ['x','y','width','height'])expect(Math.abs(before[k]-during[k])).toBeLessThanOrEqual(1);
 await page.keyboard.up('Alt');await expect(help).toBeHidden();
 expect(await receive(send('shell',{...shell,attached:false}))).toBe(true);
 await page.keyboard.down('Alt');await expect(help).toBeVisible();await expect(help.locator('[data-target="[data-detach]"]')).toContainText('Put back');
 await page.keyboard.up('Alt');await expect(help).toBeHidden();
});

test('CKP-STRIP-02 visible wordmark is ModelPlan with a red Plan in both themes',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 const wordmark=page.locator('.ck-brand .wordmark'),plan=wordmark.locator('b');
 await expect(wordmark).toHaveText('ModelPlan');await expect(plan).toHaveText('Plan');await expect(wordmark).toBeVisible();
 for(const theme of ['night','day']){
  expect(await receive(send('appearance',{...appearance,theme}))).toBe(true);
  const box=await wordmark.boundingBox();expect(box).not.toBeNull();const png=await page.screenshot({clip:box,animations:'disabled'});
  const red=await page.evaluate(async bytes=>{const image=await createImageBitmap(new Blob([new Uint8Array(bytes)],{type:'image/png'}));const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);const pixels=ctx.getImageData(0,0,image.width,image.height).data;let n=0;for(let i=0;i<pixels.length;i+=4){const x=(i/4)%image.width;if(x>=image.width*.4&&pixels[i]>90&&pixels[i]>pixels[i+1]*1.3&&pixels[i]>pixels[i+2]*1.3)n++;}return n;},[...png]);
  expect(red,`${theme} must render red brand pixels`).toBeGreaterThan(5);
 }
});
