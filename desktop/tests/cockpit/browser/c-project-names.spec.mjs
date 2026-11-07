// SPDX-License-Identifier: MIT
// Settings "Project names" (SET-9-19) on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,showProjectNames) {
 const {data}=visualFixture();
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-10-20T14:06:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,showProjectNames},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}
// Every project label in the fixture, anywhere in the page including accessibility text.
const NAMES=/modelPlans|desktop/;
const everything=page=>page.locator('#cockpit').evaluate(root=>root.textContent+[...root.querySelectorAll('[aria-label],[title],[data-tip]')].map(e=>[e.getAttribute('aria-label'),e.getAttribute('title'),e.dataset.tip].join(' ')).join(' '));

test('SET-9-19 on: the tape shows project names',async({page})=>{
 await open(page,true);
 await expect(page.locator('.t-proj').first()).toHaveText('modelPlans');
 expect(await everything(page)).toMatch(NAMES);
});

test('SET-9-19 off at open: no project name reaches any surface, label or tooltip',async({page})=>{
 await open(page,false);
 await expect(page.locator('.t-proj').first()).toHaveText('--');
 expect(await everything(page)).not.toMatch(NAMES);
});

test('SET-9-19 changing the setting takes effect at once, and a later delivery stays hidden',async({page})=>{
 const {send,receive,data}=await open(page,true);
 expect(await receive(send('appearance',{...appearance,showProjectNames:false}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('--');
 expect(await everything(page)).not.toMatch(NAMES);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('--');
 expect(await everything(page)).not.toMatch(NAMES);
 expect(await receive(send('appearance',{...appearance,showProjectNames:true}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('modelPlans');
});

test('SET-9-19 the bridge refuses an appearance without the setting',async({page})=>{
 const {send,receive}=await open(page,true);const {showProjectNames,...older}=appearance;
 expect(await receive(send('appearance',older))).toBe(false);
});
