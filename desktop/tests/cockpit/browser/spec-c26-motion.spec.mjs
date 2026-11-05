// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

for(const reduceMotion of [false,true])test(`C-26 data refresh preserves module geometry, reduced motion ${reduceMotion}`,async({page})=>{
 await page.emulateMedia({reducedMotion:reduceMotion?'reduce':'no-preference'});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample();
 for(const raw of [send('load',{appearance:{...appearance,reduceMotion},shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const selectors=['.ck-portrow','.ck-eng','.ck-deck','.ck-tape'];
 const boxes=()=>page.evaluate(selectors=>selectors.map(s=>{const r=document.querySelector(s).getBoundingClientRect();return [r.x,r.y,r.width,r.height];}),selectors);
 const before=await boxes();await page.locator('.ck-deck').evaluate(e=>e.style.transform='translateX(2px)');expect(await boxes()).not.toEqual(before);await page.locator('.ck-deck').evaluate(e=>e.style.removeProperty('transform'));expect(await boxes()).toEqual(before);data.projection.rows[0].accounts[0].windows[0].remainingPercent=42;
 expect(await receive(send('display',{data}))).toBe(true);const during=await boxes();
 expect(during).toEqual(before);
 if(reduceMotion)expect(await page.evaluate(()=>document.getAnimations().length)).toBe(0);
});
