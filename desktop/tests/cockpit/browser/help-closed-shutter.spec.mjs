// SPDX-License-Identifier: MIT
// macrev2-923-2: on the tall cockpit the closed window crops the porthole band (214 px); Option help must start below it.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';
for(const theme of ['day','night'])for(const profile of ['closed','open'])test(`Option help starts inside the visible window (${theme}, shutter ${profile})`,async({page})=>{
 await page.setViewportSize({width:1000,height:939});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier:'tall',profile}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 await page.waitForFunction(p=>document.querySelector('#cockpit')?.dataset.shell===p,profile);
 const crop=await page.evaluate(()=>{const c=document.querySelector('#cockpit');return c.dataset.shell==='closed'?parseFloat(getComputedStyle(c).marginTop):0;});
 if(profile==='closed')expect(crop).toBe(214);
 await page.keyboard.down('Alt');const map=page.locator('#help-map');await expect(map).toBeVisible();
 const rect=sel=>map.locator(sel).evaluate(e=>{const r=e.getBoundingClientRect();return {y:r.y,h:r.height};}),title=await rect('.help-map-title'),esc=await rect('.help-map-dismiss');
 expect(title.y).toBeGreaterThanOrEqual(crop);expect(esc.y).toBeGreaterThanOrEqual(crop);
 for(const box of await map.locator('.an').evaluateAll(a=>a.map(e=>{const r=e.getBoundingClientRect();return {y:r.y,bottom:r.bottom};})))expect(box.y).toBeGreaterThanOrEqual(crop);
 await page.keyboard.up('Alt');
});
