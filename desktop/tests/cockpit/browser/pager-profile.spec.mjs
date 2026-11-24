// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {walkScenarios} from '../walk-fixtures.mjs';

test('pager switches a populated engine page within 150 ms',async({page})=>{
 await page.addInitScript(()=>{
  window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};
  const text=Object.getOwnPropertyDescriptor(Node.prototype,'textContent'),width=Object.getOwnPropertyDescriptor(Element.prototype,'scrollWidth');
  let active=false,dirty=false;window.__pagerProfile={cycles:0,elapsed:null};
  Object.defineProperty(Node.prototype,'textContent',{...text,set(value){if(active&&this instanceof Element&&this.closest('.u11-engine-table'))dirty=true;return text.set.call(this,value);}});
  Object.defineProperty(Element.prototype,'scrollWidth',{...width,get(){if(active&&dirty&&this.closest('.u11-engine-table')){window.__pagerProfile.cycles++;dirty=false;}return width.get.call(this);}});
  document.addEventListener('click',e=>{if(e.target.closest('[data-bpage]')){active=true;dirty=false;window.__pagerProfile.start=performance.now();}},true);
  document.addEventListener('click',e=>{if(active){window.__pagerProfile.elapsed=performance.now()-window.__pagerProfile.start;active=false;}},false);
 });
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),scenario=walkScenarios().find(s=>s.name==='many');
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('plugins',{plugins:scenario.plugins}),send('display',{data:scenario.data})])
  expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw)).toBe(true);
 const box=await page.locator('.eng-pg [data-bpage="1"]').boundingBox();expect(box).not.toBeNull();
 await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
 const profile=await page.evaluate(()=>window.__pagerProfile);console.log('pager profile',JSON.stringify(profile));
 await expect(page.locator('.eng-pgn')).toHaveAttribute('data-page','1');
 expect(profile.elapsed).not.toBeNull();expect(profile.elapsed).toBeLessThan(150);
 // Count text-write/width-read alternations: each can force a synchronous layout.
 expect(profile.cycles).toBeLessThan(5);
});
