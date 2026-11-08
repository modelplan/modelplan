// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// CKP-SHELL-25 (owner D37, ruled 11-08): v1 shows the plain plate, the CSS metal shell from before hull-r3,
// with the c01 canopy. The hull-r3 plate set is not part of v1, so nothing may switch the plain plate off.
for(const [tier,canvas] of [['tall',911],['compact',661]])for(const closed of [false,true])
test(`CKP-SHELL-25 ${tier}${closed?' closed':''}: the plain plate is drawn`,async({page})=>{
 await page.setViewportSize({width:636,height:canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier,profile:closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const plate=await page.evaluate(()=>{
  const s=document.querySelector('.ck-shell'),st=getComputedStyle(s),r=s.getBoundingClientRect();
  return {theme:document.documentElement.dataset.theme,background:st.backgroundImage,shadow:st.boxShadow,radius:st.borderTopLeftRadius,
   width:r.width,boosters:[...document.querySelectorAll('.ck-booster')].map(b=>{const c=getComputedStyle(b),q=b.getBoundingClientRect();return c.display!=='none'&&q.height>0;})};
 });
 expect(plate.theme).toBe('night');
 expect(plate.background).toContain('gradient');
 // Owner 11-08: no drop shadow; nothing is drawn around the hull (ckp-shell-25-transparent.spec.mjs).
 expect(plate.shadow).toBe('none');
 expect(plate.radius).not.toBe('0px');
 expect(plate.width).toBe(620);
 expect(plate.boosters).toEqual([true,true]);
});
