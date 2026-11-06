// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';

test('CKP-STRIP-03 strip content and engine share sixteen-pixel side insets',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands();expect(await page.evaluate(raw=>window.modelPlanCockpit.receive(raw),send('load',{appearance,shell}))).toBe(true);
 const geometry=await page.evaluate(()=>{const rect=s=>{const r=document.querySelector(s).getBoundingClientRect();return {left:r.left,right:r.right};};return {root:rect('#cockpit'),strip:rect('.ck-head'),engine:rect('.ck-eng')};});
 for(const area of [geometry.strip,geometry.engine]){expect(Math.abs(area.left-geometry.root.left-16)).toBeLessThanOrEqual(1);expect(Math.abs(geometry.root.right-area.right-16)).toBeLessThanOrEqual(1);}
});
