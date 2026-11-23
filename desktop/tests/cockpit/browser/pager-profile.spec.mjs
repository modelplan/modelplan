// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';
import {watch} from '../walk-timing.mjs';
test('profile pager main-thread layout work',async({page})=>{
 await page.addInitScript(watch);
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};window.__profile={};for(const [proto,prop] of [[Element.prototype,'clientWidth'],[Element.prototype,'scrollWidth'],[HTMLElement.prototype,'offsetWidth']]){const d=Object.getOwnPropertyDescriptor(proto,prop);Object.defineProperty(proto,prop,{...d,get(){const start=performance.now(),v=d.get.call(this),p=window.__profile[prop]??={count:0,ms:0};p.count++;p.ms+=performance.now()-start;return v;}});}});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);const send=commands(),scenario=walkScenarios().find(s=>s.name==='many');
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('plugins',{plugins:scenario.plugins}),send('display',{data:scenario.data})])expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 await page.evaluate(()=>{window.__profile={};document.addEventListener('click',()=>{const start=performance.now();setTimeout(()=>{window.__profile.elapsed=performance.now()-start;},0);},{capture:true,once:true});});
 await page.locator('.eng-pg [data-bpage="1"]').click();await page.waitForFunction(()=>window.__profile.elapsed!==undefined);console.log('pager profile',JSON.stringify(await page.evaluate(()=>window.__profile)));
});
