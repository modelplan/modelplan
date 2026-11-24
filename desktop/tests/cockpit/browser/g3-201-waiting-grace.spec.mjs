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
const visibility=(c,visible,gen={})=>c.receive(c.send('visibility',{...gen,visible,occluded:false,key:visible}));
const line=page=>page.locator('.ck-eng .ec-empty');
// Headless WebKit only advances CSS animations when frames are produced, so every observation delivers frames first
// (macrevb-1205-3): without them a slow reveal reads opacity 0 and an old CSS-clock grace looks fine while hidden.
const frames=(page,ms=0)=>page.evaluate(ms=>new Promise(done=>{const end=performance.now()+ms;const step=()=>performance.now()>=end?requestAnimationFrame(()=>requestAnimationFrame(done)):requestAnimationFrame(step);step();}),ms);
const opacity=async page=>{await frames(page);return Number(await line(page).first().evaluate(e=>getComputedStyle(e).opacity));};
const anim=page=>line(page).first().evaluate(e=>getComputedStyle(e).animationName);
const revealed=page=>expect.poll(async()=>{await frames(page,100);return opacity(page);},{timeout:4000}).toBe(1);
const empty=()=>{const d=sample();d.projection.rows=[];d.subscriptions=[];return d;};

test('a quick first display never shows the waiting line, even after the hidden page ran frames for longer than the grace (prewarm)',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);
 await frames(page,1000); // the prewarmed page paints frames for longer than the grace while hidden
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
});
test('a slow first display shows the waiting line after the grace, counted from the show',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);await frames(page,900);
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 await frames(page,250);expect(await opacity(page)).toBe(0);
 await revealed(page);
});
test('a cleared page hidden and shown again waits the same grace, a quick display replaces it unseen, and an empty answer shows at once',async({page})=>{
 const c=await load(page),gen=g=>({generation:String(g),viewRevision:String(g-38)});
 expect(await visibility(c,true)).toBe(true);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(42)))).toBe(true);
 expect(await visibility(c,false,gen(42))).toBe(true);await frames(page,1000);
 expect(await visibility(c,true,gen(42))).toBe(true);
 expect(await opacity(page)).toBe(0);
 expect(await c.receive(c.send('display',{...gen(42),data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(43)))).toBe(true);
 expect(await visibility(c,false,gen(43))).toBe(true);await frames(page,1000);
 expect(await visibility(c,true,gen(43))).toBe(true);
 expect(await c.receive(c.send('display',{...gen(43),data:empty()}))).toBe(true);
 await expect(page.locator('.ec-empty-open')).toBeVisible();
 expect(await opacity(page)).toBe(1);
 expect(await c.receive(c.send('clear',gen(44)))).toBe(true);
 await revealed(page);
});
for(const how of ['app setting','system'])
test(`Reduce Motion (${how}): the line appears after the grace without a fade, and a quick display still suppresses it`,async({page})=>{
 if(how==='system')await page.emulateMedia({reducedMotion:'reduce'});
 const c=await load(page,{...appearance,reduceMotion:how==='app setting'});
 expect(await visibility(c,true)).toBe(true);
 expect(await opacity(page)).toBe(0);
 await revealed(page);
 expect(await anim(page)).toBe('none');
});
