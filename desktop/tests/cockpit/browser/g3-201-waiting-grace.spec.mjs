// SPDX-License-Identifier: MIT
// G3-201 / CKP-SHELL-33 on the built page through its normal bridge (synthetic data only): the waiting and cleared lines never
// show in the first 0.7 s the page is shown; a display that lands sooner replaces them unseen; the grace counts from the
// show, not from the page load (prewarmed page); an empty answer is not delayed; Reduce Motion shows the line without a fade.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker,sample} from '../fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function load(page,app=appearance){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:app,shell,redBelow:25}))).toBe(true);
 return {send,receive};
}
const visibility=(c,visible)=>c.receive(c.send('visibility',{visible,occluded:false,key:visible}));
const line=page=>page.locator('.ck-eng .ec-empty');
const opacity=async page=>Number(await line(page).first().evaluate(e=>getComputedStyle(e).opacity));
const anim=page=>line(page).first().evaluate(e=>getComputedStyle(e).animationName);

test('a quick first display never shows the waiting line, even after the hidden page ran for longer than the grace (prewarm)',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);
 await page.waitForTimeout(1000); // the prewarmed page stays hidden longer than the grace
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
});
test('a slow first display shows the waiting line after the grace, counted from the show',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);await page.waitForTimeout(900);
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 await page.waitForTimeout(400);expect(await opacity(page)).toBe(0);
 await expect.poll(()=>opacity(page),{timeout:2000}).toBe(1);
});
test('a cleared page waits the same grace after it is shown again, and a quick display replaces it unseen',async({page})=>{
 const c=await load(page),gen=g=>({generation:String(g),viewRevision:String(g-38)});
 expect(await visibility(c,true)).toBe(true);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(42)))).toBe(true);
 expect(await opacity(page)).toBe(0);
 expect(await c.receive(c.send('display',{...gen(42),data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(43)))).toBe(true);
 await expect.poll(()=>opacity(page),{timeout:2000}).toBe(1);
});
for(const how of ['app setting','system'])
test(`Reduce Motion (${how}): the line appears after the grace without a fade, and a quick display still suppresses it`,async({page})=>{
 if(how==='system')await page.emulateMedia({reducedMotion:'reduce'});
 const c=await load(page,{...appearance,reduceMotion:how==='app setting'});
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 await expect.poll(()=>opacity(page),{timeout:2000}).toBe(1);
 expect(await anim(page)).toBe('none');
});
