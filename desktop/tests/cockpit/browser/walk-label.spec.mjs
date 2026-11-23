// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';
test('Claude Code label fits the six-column page',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),scenario=walkScenarios().find(s=>s.name==='many');
 for(const raw of [send('load',{appearance:{...appearance,locale:'zh-CN'},shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('plugins',{plugins:scenario.plugins}),send('display',{data:scenario.data})])expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','6');
 const label=page.locator('.eng-keys .ek-name').filter({hasText:'Claude Code'});await expect(label).toHaveCount(1);
 expect(await label.evaluate(e=>({text:e.textContent,client:e.clientWidth,scroll:e.scrollWidth}))).toMatchObject({text:'Claude Code'});
 expect(await label.evaluate(e=>e.scrollWidth<=e.clientWidth)).toBe(true);
 const sizes=await page.locator('.eng-keys .ek[data-sub] .ek-name').evaluateAll(els=>els.filter(e=>e.getClientRects().length).map(e=>parseFloat(getComputedStyle(e).fontSize)));
 expect(sizes.length).toBeGreaterThan(0);expect(sizes.every(size=>size>=10)).toBe(true);
 await expect(label.locator('..').locator('img.lamp')).toBeVisible();
});
