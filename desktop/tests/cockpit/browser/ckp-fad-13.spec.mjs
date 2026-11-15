// SPDX-License-Identifier: MIT
// CKP-FAD-13 on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';

for(const [tier,height] of [['compact',640],['tall',890]]){
 test(`faders keep detents 20 pt apart at ${height}`,async({page})=>{
  await page.setViewportSize({width:636,height});
  await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),fixture=visualFixture();
  expect(await receive(send('load',{appearance,shell:{...shell,tier},redBelow:25}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:fixture.data}))).toBe(true);
  await renderVisualDeck(page,fixture,'en');
  const measured=await page.evaluate(()=>{
   const channel=document.querySelector('.fd-ch:not(.empty)'),strip=channel.querySelector('.fd-strip');
   const tops=[...channel.querySelectorAll('.fd-tick')].map(tick=>tick.getBoundingClientRect().top).sort((a,b)=>a-b);
   return {gaps:tops.slice(1).map((top,i)=>top-tops[i]),clipped:strip.scrollHeight>strip.clientHeight+1,lcd:strip.getBoundingClientRect().height};
  });
  expect(measured.gaps.length).toBeGreaterThan(0);
  const levels=await page.evaluate(()=>document.querySelectorAll('.sc-l').length);
  const travel=await page.evaluate(()=>{const t=document.querySelector('.fd-ch:not(.empty) .fd-travel').getBoundingClientRect().height;return t-16;});
  expect(travel/(levels-1)).toBeGreaterThanOrEqual(20);
  expect(Math.min(...measured.gaps)).toBeGreaterThanOrEqual(19.5);
  expect(measured.clipped).toBe(false);
  if(tier==='tall')expect(measured.lcd).toBeGreaterThan(90);
 });
}
