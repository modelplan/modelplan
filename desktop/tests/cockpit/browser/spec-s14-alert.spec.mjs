// SPDX-License-Identifier: MIT
// S14: the normal bridge/page alert journey uses synthetic quota facts only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('S14 warning acknowledgement opens Overview, escalation re-alerts and clear resets the lamp',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.details=null;data.projection.rows=data.projection.rows.slice(0,1);const windows=data.projection.rows[0].accounts[0].windows;for(const w of windows)w.remainingPercent=75;
 for(const raw of [send('load',{appearance:{...appearance,reduceMotion:false},shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const lamp=page.locator('[data-caution]');await expect(lamp).not.toHaveClass(/\blit\b/);
 windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bamber\b/);await expect(lamp).toHaveClass(/\bflash\b/);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await lamp.click();await expect(page.getByRole('button',{name:'Overview',exact:true})).toHaveAttribute('aria-pressed','true');await expect(lamp).toHaveClass(/\blit\b/);await expect(lamp).not.toHaveClass(/\bflash\b/);await expect(page.locator('.mfd-alerts')).toBeVisible();
 expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
 windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);await expect(lamp).toHaveClass(/\bflash\b/);
 expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
 for(const w of windows)w.remainingPercent=75;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit|\bflash/);
});

test('S14 only current bound alert facts trigger a cue and media Reduce Motion suppresses it',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0],window=account.windows[0],lamp=page.locator('[data-caution]');
 data.details.alerts=[];for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 data.details.alerts=[{severity:'critical',source:row.id,subscriptionRef:account.subscriptionRef,windowId:'not-a-window',remainingPercent:20}];expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit|\bflash/);
 data.details.alerts[0].windowId=window.id;await page.emulateMedia({reducedMotion:'reduce'});await page.waitForFunction(()=>matchMedia('(prefers-reduced-motion: reduce)').matches);expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);expect(await lamp.evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 window.validUntil='2026-11-03T11:59:00Z';expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit|\bflash/);
});

test('macrev2-532-2 hide and closed shell stop active caution without replaying unchanged facts',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;data.details=null;data.projection.rows=data.projection.rows.slice(0,1);const windows=data.projection.rows[0].accounts[0].windows;for(const w of windows)w.remainingPercent=75;
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const lamp=page.locator('[data-caution]');windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
 windows[0].remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);expect(await receive(send('shell',shell))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
});

test('macrev2-532-2 clear resets acknowledgement and unload refuses stale replay',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;data.details=null;data.projection.rows=data.projection.rows.slice(0,1);const windows=data.projection.rows[0].accounts[0].windows;for(const w of windows)w.remainingPercent=75;
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const lamp=page.locator('[data-caution]');windows[0].remainingPercent=35;expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);await lamp.click();await expect(lamp).not.toHaveClass(/\bflash\b/);
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(lamp).not.toHaveClass(/\blit|\bflash/);expect(await receive(send('display',{data}))).toBe(false);
 expect(await receive(send('display',{viewRevision:'4',data}))).toBe(true);await expect(lamp).toHaveClass(/\bflash\b/);expect(await receive(send('unload',{viewRevision:'4'}))).toBe(true);await expect(page.locator('[data-caution]')).toHaveCount(0);expect(await page.evaluate(()=>typeof window.modelPlanCockpit)).toBe('undefined');
});

test('C-14 duplicate alerts cue the highest severity regardless of delivery order',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0],window=account.windows[0],lamp=page.locator('[data-caution]');
 const warning={severity:'warning',source:row.id,subscriptionRef:account.subscriptionRef,windowId:window.id,remainingPercent:35},critical={...warning,severity:'critical',remainingPercent:20};data.details.alerts=[warning];
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await expect(lamp).toHaveClass(/\bflash\b/);await lamp.click();await expect(lamp).not.toHaveClass(/\bflash\b/);
 data.details.alerts=[critical,warning];expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).toHaveClass(/\bred\b/);await expect(lamp).toHaveClass(/\bflash\b/);
 await lamp.click();data.details.alerts=[warning,critical];expect(await receive(send('display',{data}))).toBe(true);await expect(lamp).not.toHaveClass(/\bflash\b/);
});
