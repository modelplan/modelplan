// SPDX-License-Identifier: MIT
// Cockpit recovery step 2 (G3-96, G3-116): a display whose render throws is refused, the built page stays loaded with
// the last rendered data on screen, and the next good display renders. The host's correlated health probe names its
// page: another page id is a mismatch, never an answer. Built page, normal bridge, real Go capture.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,capture,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page){
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  return {send,receive};
}
const engine=page=>page.evaluate(()=>document.querySelector('#cockpit .ck-engine, #cockpit [class*="engine"]')?.innerHTML??document.getElementById('cockpit').innerHTML);
test('a render that throws keeps the page and its last rendered data; the next display renders',async({page})=>{
  const {send,receive}=await open(page);
  expect(await receive(send('display',{data:capture()}))).toBe(true);
  const before=await engine(page);
  const next=capture();next.projection.rows[0].name={en:'Replaced',zh:'已替换'};
  // One DOM append inside the render throws, as a view bug would; the restore of the last data then succeeds.
  const refused=await page.evaluate(raw=>{
    const original=Element.prototype.append;let armed=true;
    Element.prototype.append=function(...nodes){if(armed){armed=false;throw Error('synthetic render failure');}return original.apply(this,nodes);};
    try{return {accepted:window.modelPlanCockpit.receive(raw),reject:window.modelPlanCockpit.reject()};}
    finally{Element.prototype.append=original;}
  },send('display',{data:next}));
  expect(refused).toEqual({accepted:false,reject:'display.render'});
  expect(await page.evaluate(()=>!!window.modelPlanCockpit)).toBe(true);
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
  expect(await engine(page)).toBe(before);
  expect(await page.evaluate(()=>document.body.innerText.includes('Replaced'))).toBe(false);
  const after=capture();after.projection.rows[0].name={en:'Recovered',zh:'已恢复'};
  expect(await receive(send('display',{data:after}))).toBe(true);
});
test('the correlated probe answers only for its own page',async({page})=>{
  await open(page);
  expect(await page.evaluate(id=>window.modelPlanCockpit.state(id),pageId)).toBe('ready');
  expect(await page.evaluate(id=>window.modelPlanCockpit.state(id.toUpperCase()),pageId)).toBe('ready');
  expect(await page.evaluate(()=>window.modelPlanCockpit.state('00000000-0000-4000-8000-00000000ffff'))).toBe('mismatch');
  expect(await page.evaluate(()=>window.modelPlanCockpit.state())).toBe('ready');
});
