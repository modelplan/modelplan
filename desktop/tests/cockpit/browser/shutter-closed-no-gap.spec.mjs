// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {decodeRgba,interiorGaps} from '../png-alpha.mjs';

// Owner test build 6 (2026-11-27): with the shutter closed, a thin light line showed between the cap's dark rim and the
// title bar. The 1 px sat inside the silhouette where neither the owner's cap art (D451/D452, placed 1 px higher) nor
// the header plate painted. The walkthrough missed it because the CI desktop is black; the window capture keeps its
// alpha, so the same scan runs here on a transparent screenshot at the 1x and the 2x scale, closed and open.
// Page zoom: 0.956 is the native Auto fit that showed the owner's gap (window 608 px for the 636 px page), 0.85 the
// MacBook Air fit; WebKit's page zoom is the root's zoom, as in g3-65.
for(const [scale,zoom] of [[1,1],[2,1],[1,.956],[2,.956],[2,.85],[1,.85]])for(const closed of [true,false]){
 test.describe(`${closed?'closed':'open'} shell at ${scale}x, zoom ${zoom}`,()=>{
  test.use({deviceScaleFactor:scale});
  test('the silhouette has no transparent hairline between its rim and the strip/body',async({page})=>{
   const canvas=951;
   await page.setViewportSize({width:Math.ceil(636*zoom),height:Math.ceil(canvas*zoom)});
   await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
   const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
   expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier:'tall',profile:closed?'closed':'open'}}))).toBe(true);
   expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
   expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
   await page.evaluate(z=>{document.documentElement.style.zoom=String(z);},zoom);
   await page.waitForTimeout(200);
   const image=decodeRgba(await page.screenshot({omitBackground:true,clip:{x:0,y:0,width:Math.ceil(636*zoom),height:Math.ceil(canvas*zoom)}}));
   // The open canopy's glass is legitimately clear; scan open down to the strip (head row), closed all the way down.
   const edge=await page.evaluate(()=>{const h=document.querySelector('.ck-head').getBoundingClientRect(),t=document.querySelector('.ck-tape').getBoundingClientRect();return {head:h.top,strip:h.bottom,tape:t.top};});
   const px=v=>Math.floor(v*zoom*scale);
   // Closed: from the cap's top edge down to the record tape. Open: the strip's own rows (the canopy glass is clear).
   const gaps=interiorGaps(image,closed?{lastRow:px(edge.tape)}:{firstRow:px(edge.head),lastRow:px(edge.strip)});
   expect(gaps,'rows in the silhouette that are transparent across >= 20 % of its width').toEqual([]);
  });
 });
}
