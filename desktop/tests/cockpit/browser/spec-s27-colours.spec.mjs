// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

async function open(page){
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const colours=()=>page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['--metal-1','--metal-2','--metal-3','--gold-metal','--fire-metal'].map(k=>[k,s.getPropertyValue(k).trim().toLowerCase()]));});
 return {send,receive,colours};
}
test('S27 night page metal, gold and fire tokens',async({page})=>{
 const {colours}=await open(page);expect(await colours()).toEqual({'--metal-1':'#202124','--metal-2':'#1c1d1f','--metal-3':'#141517','--gold-metal':'#d4b994','--fire-metal':'#df604c'});
});
test('S27 day page metal endpoints await accepted-baseline disposition',async({page})=>{
 test.fixme(true,'S27 day spec conflicts with the accepted opus-r7 metal palette; owner disposition requested');
 const {send,receive,colours}=await open(page);expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);
 const day=await colours();expect(day['--gold-metal']).toBe('#90704d');expect(day['--fire-metal']).toBe('#bb342c');expect(day['--metal-1']).toBe('#e9eaec');expect(day['--metal-3']).toBe('#d7d9dc');
});
