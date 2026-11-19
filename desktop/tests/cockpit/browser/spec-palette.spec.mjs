// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

test('THM-2.4-02 C-27 night palette values on the normal page',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme:'night'},shell}))).toBe(true);
 const colors=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['--metal-1','--metal-2','--metal-3','--gold-metal','--fire-metal'].map(k=>[k,s.getPropertyValue(k).trim()]));});
 expect(colors).toEqual({'--metal-1':'#202124','--metal-2':'#1c1d1f','--metal-3':'#141517','--gold-metal':'#d4b994','--fire-metal':'#df604c'});
});

test('THM-2.4-03 C-27 day accent tokens on the normal page',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme:'day'},shell}))).toBe(true);
 const colors=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['--gold-metal','--fire-metal'].map(k=>[k,s.getPropertyValue(k).trim()]));});
 expect(colors).toEqual({'--gold-metal':'#90704d','--fire-metal':'#bb342c'});
});
