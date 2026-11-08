// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-47 (owner build 13: "底部的喷口和火焰也要露出来"): the native window is the page canvas, root + 34 px
// (CockpitShellLayout: 877/691 tall, 627/609 short, open/closed; the WebKit zoom scales the canvas as one, so every
// Cockpit size and the auto-scaled Air fit keep these page sizes). In every profile the bells, their mouth light and
// the flame must end inside that canvas, so nothing under the hull is clipped by the window.
const profiles=[
 {tier:'tall',profile:'open',root:877},{tier:'tall',profile:'closed',root:691},
 {tier:'compact',profile:'open',root:627},{tier:'compact',profile:'closed',root:609},
];
for(const p of profiles)test(`G3-47 ${p.tier} ${p.profile}: bells and flames end inside the native window`,async({page})=>{
 const canvas=p.root+34;
 await page.setViewportSize({width:636,height:canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=visualFixture().data;
 // A working subscription, so the bell carries its mouth light and flame where the profile shows them.
 data.details.sessions[0]={...data.details.sessions[0],subscriptionRef:data.projection.rows[0].accounts[0].subscriptionRef,rate:400};
 expect(await receive(send('load',{appearance,shell:{...shell,tier:p.tier,profile:p.profile}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0);
 const v=await page.evaluate(()=>{
  const root=document.getElementById('cockpit').getBoundingClientRect(),base=document.querySelector('.ck-base').getBoundingClientRect();
  const painted=[...document.querySelectorAll('.ck-base .bz-line,.ck-base .bz-sheet,.ck-base .bz-plume')]
   .filter(e=>getComputedStyle(e).display!=='none').map(e=>e.getBoundingClientRect());
  return {rootTop:root.top,rootH:root.height,baseTop:base.top,baseBottom:base.bottom,bells:document.querySelectorAll('.ck-base .bz-line').length,
   bottom:Math.max(...painted.map(r=>r.bottom)),scroll:document.documentElement.scrollHeight,inner:innerHeight};
 });
 expect(v.bells).toBeGreaterThan(0);
 expect(v.baseTop).toBeCloseTo(v.rootTop+v.rootH,1);
 expect(v.baseBottom).toBeLessThanOrEqual(canvas+0.5);
 expect(v.bottom).toBeGreaterThan(v.baseTop);
 expect(v.bottom).toBeLessThanOrEqual(canvas+0.5);
 expect(v.scroll).toBeLessThanOrEqual(v.inner);
});
