// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';

test('cockpit rendering and navigation emit no inline-style CSP violations',async({page})=>{
 const violations=[];
 page.on('console',m=>{if(m.type()==='error'&&m.text().includes('Refused to apply a stylesheet'))violations.push(m.text());});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),scenario=walkScenarios().find(x=>x.name==='many');
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('plugins',{plugins:scenario.plugins}),send('display',{data:scenario.data})])
  expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 for(let i=0;i<await page.locator('.mfd-pk .pk').count();i++)await page.locator('.mfd-pk .pk').nth(i).click();
 const strip=page.locator('.fd-ch:not(.empty) .fd-strip').first();if(await strip.count())await strip.click();
 const next=page.locator('.eng-pg [data-bpage="1"]');if(await next.count())await next.click();
 await page.waitForTimeout(100);expect(violations).toEqual([]);
});
