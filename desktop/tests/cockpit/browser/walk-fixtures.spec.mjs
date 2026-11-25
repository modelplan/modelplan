// SPDX-License-Identifier: MIT
// Check that each synthetic walk scenario is admitted by the real bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';

for(const scenario of walkScenarios())test(`walk fixture: ${scenario.name}`,async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:scenario.plugins}))).toBe(true);
 if(scenario.data)expect(await receive(send('display',{data:scenario.data}))).toBe(true);
 if(scenario.afterLoading){
  await expect(page.locator('.mfd-page')).toHaveAttribute('aria-busy','true');
  expect(await receive(send('display',{data:scenario.afterLoading}))).toBe(true);
  await expect(page.locator('.mfd-page')).not.toHaveAttribute('aria-busy','true');
 }
 if(scenario.name==='many')await expect(page.locator('.eng-pgn')).toBeVisible();
 if(scenario.name==='empty')await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(0);
 if(scenario.name==='one')await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);
 if(scenario.name==='zcode-readable')await expect(page.locator('.eng-keys .ek[data-sub]',{hasText:'ZCode'})).toHaveCount(1);
 if(scenario.name==='zcode-unreadable')await expect(page.locator('.eng-keys .ek[data-sub]',{hasText:'ZCode'})).toHaveCount(0);
});
