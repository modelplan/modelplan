// SPDX-License-Identifier: MIT
// CKP-FAD-03 on the built page: the LCD's top edge carries the vendor strip, one segment per subscription of the model.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture,renderVisualDeck} from '../visual-fixture.mjs';

test('CKP-FAD-03 top-edge vendor strip splits into a segment per subscription',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const fx=visualFixture(),send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 fx.publication.faders[0].accounts=['study-codex','study-claude'];
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 await renderVisualDeck(page,fx,'en');
 const strips=await page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(strip=>{const box=strip.getBoundingClientRect(),band=strip.querySelector('.st-vend'),r=band.getBoundingClientRect();
  return {top:r.top-box.top,height:r.height,edge:r.width>=box.width-8,segments:[...band.children].map(b=>({colour:getComputedStyle(b).getPropertyValue('--v').trim(),paint:getComputedStyle(b).backgroundColor,width:b.getBoundingClientRect().width}))};}));
 expect(strips.map(s=>s.segments.map(x=>x.colour))).toEqual([['#6aa8ff','#ff9a6a'],['#ff9a6a'],['#8f7dff']]);
 for(const strip of strips){expect(strip.top).toBeLessThanOrEqual(3.5);expect(strip.height).toBeCloseTo(3,0);expect(strip.edge).toBe(true);}
 const [first,second]=strips[0].segments;
 expect(first.width).toBeCloseTo(second.width,0);
 expect(first.paint).toBe('rgb(106, 168, 255)');expect(second.paint).toBe('rgb(255, 154, 106)');
});
