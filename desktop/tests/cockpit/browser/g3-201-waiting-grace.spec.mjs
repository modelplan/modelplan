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
// Frame speed must not decide the verdict (macrevb-1205-3): the grace is a CSS animation delay, so the line's animation is paused and
// set to a chosen time ("at") and the rendered opacity read there; "elapsed" is how far the animation has run since it started.
const frames=(page,ms=0)=>page.evaluate(ms=>new Promise(done=>{const end=performance.now()+ms;const step=()=>performance.now()>=end?requestAnimationFrame(()=>requestAnimationFrame(done)):requestAnimationFrame(step);step();}),ms);
const opacity=async page=>Number(await line(page).first().evaluate(e=>getComputedStyle(e).opacity));
const at=(page,ms)=>line(page).first().evaluate((e,ms)=>{const a=e.getAnimations()[0];if(!a)return -1;a.pause();a.currentTime=ms;return Number(getComputedStyle(e).opacity);},ms);
const elapsed=page=>line(page).first().evaluate(e=>{const a=e.getAnimations()[0];return a?Number(a.currentTime):-1;});
const graceThenShown=async page=>{expect(await at(page,100)).toBe(0);expect(await at(page,850)).toBe(1);};
const empty=()=>{const d=sample();d.projection.rows=[];d.subscriptions=[];return d;};

test('a quick first display never shows the waiting line, even after the hidden page ran frames for longer than the grace (prewarm)',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);
 await frames(page,1000); // the prewarmed page paints frames for longer than the grace while hidden
 expect(await visibility(c,true)).toBe(true);
 expect(await elapsed(page)).toBeLessThan(600); // counted from the show, not from the hidden frames
 expect(await at(page,100)).toBe(0);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
});
test('a slow first display shows the waiting line after the grace, counted from the show',async({page})=>{
 const c=await load(page);
 expect(await visibility(c,false)).toBe(true);await frames(page,900);
 expect(await visibility(c,true)).toBe(true);
 expect(await elapsed(page)).toBeLessThan(600);
 await graceThenShown(page);
});
test('a cleared page hidden and shown again waits the same grace, a quick display replaces it unseen, and an empty answer shows at once',async({page})=>{
 const c=await load(page),gen=g=>({generation:String(g),viewRevision:String(g-38)});
 expect(await visibility(c,true)).toBe(true);
 expect(await c.receive(c.send('display',{data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(42)))).toBe(true);
 expect(await visibility(c,false,gen(42))).toBe(true);await frames(page,1000);
 expect(await visibility(c,true,gen(42))).toBe(true);
 expect(await elapsed(page)).toBeLessThan(600);
 expect(await c.receive(c.send('display',{...gen(42),data:sample()}))).toBe(true);
 await expect(line(page)).toHaveCount(0);
 expect(await c.receive(c.send('clear',gen(43)))).toBe(true);
 expect(await visibility(c,false,gen(43))).toBe(true);await frames(page,1000);
 expect(await visibility(c,true,gen(43))).toBe(true);
 expect(await c.receive(c.send('display',{...gen(43),data:empty()}))).toBe(true);
 await expect(page.locator('.ec-empty-open')).toBeVisible();
 expect(await opacity(page)).toBe(1);
 // A clear on a page that is already shown has no show race: the line is visible at once and runs no animation (CKP-MOT: nothing runs behind a gate).
 expect(await c.receive(c.send('clear',gen(44)))).toBe(true);
 expect(await opacity(page)).toBe(1);
 expect(await line(page).first().evaluate(e=>e.getAnimations().length)).toBe(0);
 // Hidden and shown again, the cleared line waits the grace like the waiting line.
 expect(await visibility(c,false,gen(44))).toBe(true);
 expect(await visibility(c,true,gen(44))).toBe(true);
 await graceThenShown(page);
});
for(const how of ['app setting','system'])
test(`Reduce Motion (${how}): the line appears after the grace without a fade, and a quick display still suppresses it`,async({page})=>{
 if(how==='system')await page.emulateMedia({reducedMotion:'reduce'});
 const c=await load(page,{...appearance,reduceMotion:how==='app setting'});
 expect(await visibility(c,true)).toBe(true);
 await at(page,0);await graceThenShown(page);
 expect(await line(page).first().evaluate(e=>getComputedStyle(e).animationDuration)).toBe('0.001s');
});
