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

test('G3-100 a session with no project reads "No project" while names are on, and "--" when names are off',async({page})=>{
 const {send,receive,data}=await open(page,true);
 const bare=structuredClone(data);bare.details.sessions[0].projectLabel=null;
 expect(await receive(send('display',{data:bare}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('No project');
 expect(await receive(send('appearance',{...appearance,showProjectNames:false}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('--');
 const unnamed=structuredClone(data);unnamed.details.sessions[0].projectLabel='Unnamed project';
 expect(await receive(send('appearance',{...appearance,showProjectNames:true}))).toBe(true);
 expect(await receive(send('display',{data:unnamed}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('Unnamed project');
});

test('glm-909-1 a project whose name the CLI hides reads "--", not "No project", while names are on',async({page})=>{
 const {send,receive,data}=await open(page,true);
 const hidden=structuredClone(data);hidden.details.sessions[0].projectLabel=null;hidden.details.sessions[0].projectState='hidden';
 expect(await receive(send('display',{data:hidden}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('--');
 const none=structuredClone(data);none.details.sessions[0].projectLabel=null;none.details.sessions[0].projectState='none';
 expect(await receive(send('display',{data:none}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('No project');
 const unnamed=structuredClone(data);unnamed.details.sessions[0].projectLabel='Unnamed project';unnamed.details.sessions[0].projectState='unnamed';
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 expect(await receive(send('display',{data:unnamed}))).toBe(true);
 await expect(page.locator('.t-proj').first()).toHaveText('未命名项目');
});
