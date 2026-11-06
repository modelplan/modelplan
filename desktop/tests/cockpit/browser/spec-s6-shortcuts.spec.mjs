// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('S6 engine key digits are visible and exposed in tooltip, accessible name and Option help',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const first=page.locator('.eng-keys .ek[data-sub]').first(),all=page.locator('.ek[data-all]');
 await expect(first.locator('.ki')).toHaveText('1');await expect(first.locator('.ki')).toBeVisible();await expect(first).toHaveAttribute('aria-label',/Shortcut key 1/);await expect(first).toHaveAttribute('title',/Shortcut key 1/);await expect(all).toHaveAttribute('aria-label','All · Shortcut key 0');await expect(all).toHaveAttribute('title','Shortcut key 0');
 await page.keyboard.down('Alt');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toBeVisible();expect(await page.locator('#help-map [data-target=".eng-krow"]').evaluate(e=>{const r=e.getBoundingClientRect();return r.left>=0&&r.top>=0&&r.right<=innerWidth&&r.bottom<=innerHeight;})).toBe(true);await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('0 = All');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('1–6');await page.keyboard.up('Alt');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(first).toHaveAttribute('aria-label',/快捷键 1/);await expect(first).toHaveAttribute('title',/快捷键 1/);await expect(all).toHaveAttribute('aria-label','全部 · 快捷键 0');await expect(all).toHaveAttribute('title','快捷键 0');
 await page.setViewportSize({width:636,height:640});expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);await page.keyboard.down('Alt');await expect(page.locator('#help-map [data-target=".eng-krow"]')).toBeVisible();expect(await page.locator('#help-map [data-target=".eng-krow"]').evaluate(e=>{const r=e.getBoundingClientRect();return r.left>=0&&r.top>=0&&r.right<=innerWidth&&r.bottom<=innerHeight;})).toBe(true);await expect(page.locator('#help-map [data-target=".eng-krow"]')).toContainText('快捷键');await page.keyboard.up('Alt');
});

test('C-06 digit shortcuts select admitted visible subscriptions and All',async({page})=>{
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage:m=>window.__messages.push(JSON.parse(m))}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const first=page.locator('.eng-keys .ek[data-sub]').first(),all=page.locator('.ek[data-all]');
 await all.focus();await page.keyboard.press('1');await expect(first).toHaveAttribute('aria-pressed','true');
 await page.keyboard.press('0');await expect(all).toHaveAttribute('aria-pressed','true');
 const actions=await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'&&m.action==='scopeSelect'));
 expect(actions.map(a=>a.key)).toEqual([currentSample().projection.rows[0].accounts[0].subscriptionRef,'all']);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 await page.keyboard.press('1');expect(await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'&&m.action==='scopeSelect').length)).toBe(2);
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await page.keyboard.press('1');expect(await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'&&m.action==='scopeSelect').length)).toBe(2);
});

test('C-06 digits follow the current engine page',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample();
 for(let i=0;i<3;i++){const row=structuredClone(data.projection.rows[1]);row.id=`synthetic${i}`;row.name={en:`Synthetic ${i}`,zh:`模拟 ${i}`};data.projection.rows.push(row);}
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await page.locator('.eng-led[data-page="1"]').click();const first=page.locator('.eng-keys .ek[data-sub]').first();await first.focus();await page.keyboard.press('1');await expect(first).toHaveAttribute('aria-pressed','true');
});

test('C-06 Option help omits shortcut caption when the engine row is hidden',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const row=page.locator('.eng-krow'),caption=page.locator('#help-map [data-target=".eng-krow"]');await expect(row).toBeVisible();
 await page.keyboard.down('Alt');await expect(caption).toBeVisible();await page.keyboard.up('Alt');
 await row.evaluate(e=>e.style.display='none');await page.keyboard.down('Alt');await expect(caption).toHaveCount(0);await page.keyboard.up('Alt');
});
