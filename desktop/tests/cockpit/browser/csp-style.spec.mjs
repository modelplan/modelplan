// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';
import {visualFixture} from '../visual-fixture.mjs';

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

for(const [theme,expected] of [['day',[44,48,52]],['night',[238,242,246]]])test(`Cursor subscription chip retains its ${theme} colour without inline-style CSP violations`,async({page})=>{
 const violations=[];
 page.on('console',m=>{if(m.type()==='error'&&m.text().includes('Refused to apply a stylesheet'))violations.push(m.text());});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),data=visualFixture().data;
 for(const raw of [send('load',{appearance:{...appearance,theme},shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])
  expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 await page.locator('[data-mfd="page:sub"]').click();
 const row=page.locator('.sa-list .sa').filter({hasText:'Cursor'});await expect(row).toHaveCount(1);
 const rgb=await row.locator('.chip').evaluate(el=>{const value=getComputedStyle(el).backgroundColor;const srgb=/^color\(srgb ([\d.]+) ([\d.]+) ([\d.]+)\)$/.exec(value);if(srgb)return srgb.slice(1).map(x=>Math.round(Number(x)*255));const legacy=/^rgb\((\d+), (\d+), (\d+)\)$/.exec(value);return legacy?.slice(1).map(Number)??value;});
 expect(rgb).toEqual(expected);
 expect(violations).toEqual([]);
});
