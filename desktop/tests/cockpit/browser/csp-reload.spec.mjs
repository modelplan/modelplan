// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';

test('reloading the cockpit does not block strip image requests',async({page})=>{
 const blocked=[];
 page.on('requestfailed',r=>{if(r.failure()?.errorText?.includes('Content Security Policy'))blocked.push(r.url());});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 const boot=async()=>{
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),data=walkScenarios().find(x=>x.name==='one').data;
  for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])
   expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 };
 await boot();await boot();await page.waitForTimeout(500);
 expect(blocked).toEqual([]);
 for(const [selector,pseudo,asset] of [
  ['[data-settings]','::before','gear-normal'],['[data-detach]','::before','detach-normal'],
  ['[data-caution]','::before','lamp-off-glow'],['[data-caution]','::after','lamp-off-body'],
 ])expect(await page.locator(selector).evaluate((el,pseudo)=>getComputedStyle(el,pseudo).backgroundImage,pseudo)).toContain(asset);
});
