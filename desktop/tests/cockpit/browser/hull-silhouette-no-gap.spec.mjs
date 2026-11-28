// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {decodeRgba,interiorGaps,extents,outwardSteps} from '../png-alpha.mjs';

// Owner test build 6 (2026-11-27, items +j and the closed-cap line): with the shutter closed, a thin light line showed between the cap's dark rim and the
// title bar. The 1 px sat inside the silhouette where neither the owner's cap art (D451/D452, placed 1 px higher) nor
// the header plate painted. The walkthrough missed it because the CI desktop is black; the window capture keeps its
// alpha, so the same scan runs here on a transparent screenshot at the 1x and the 2x scale, closed and open.
// Page zoom: 0.956 is the native Auto fit that showed the owner's gap (window 608 px for the 636 px page), 0.85 the
// MacBook Air fit; WebKit's page zoom is the root's zoom, as in g3-65.
for(const [scale,zoom] of [[1,1],[2,1],[1,.956],[2,.956],[2,.96],[2,.9],[2,.85],[1,.85],[2,.8]])for(const closed of [true,false]){
 test.describe(`${closed?'closed':'open'} shell at ${scale}x, zoom ${zoom}`,()=>{
  test.use({deviceScaleFactor:scale});
  test('the whole silhouette has no transparent hairline and no unexpected outward step',async({page})=>{
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
   const edge=await page.evaluate(()=>{const r=n=>document.querySelector(n).getBoundingClientRect();return {shell:r('.ck-shell').bottom,canopy:r('.ck-head').top};});
   const px=v=>Math.floor(v*zoom*scale);
   // The whole outline, top rim to the aft plate (its last 4 px are the art's own soft bottom edge). The open canopy glass is
   // opaque in this fixture, so nothing inside the silhouette may be see-through.
   const gaps=interiorGaps(image,{lastRow:px(edge.shell-4)});
   expect(gaps,'rows in the silhouette that are transparent across >= 20 % of its width').toEqual([]);
   // Side profile: no outward step wider than 2 css px between adjacent rows. Approved shapes are left out of the range:
   // the canopy's rounded top (the first 40 css px, D74 canopy art) and the nozzle band below the aft plate (D459 flames). The
   // hull's own taper (8 px over 31 rows, B13 / owner hull A) and the 8 px canopy-to-body inset (D451/D452) move 1 px per row.
   const ext=extents(image);
   const steps=outwardSteps(ext,{from:px(closed?edge.canopy-30:40),to:px(edge.shell-4),max:Math.ceil(2*zoom*scale)});
   expect(steps,'outward steps in the side profile').toEqual([]);
   // Owner brief for the window art: the frame is never wider than the body below it.
   if(!closed){
    const frame=ext.slice(px(60),px(230)).filter(Boolean),body=ext.slice(px(560),px(870)).filter(Boolean);
    expect(Math.min(...frame.map(r=>r[0])),'frame left vs body left').toBeGreaterThanOrEqual(Math.min(...body.map(r=>r[0]))-1);
    expect(Math.max(...frame.map(r=>r[1])),'frame right vs body right').toBeLessThanOrEqual(Math.max(...body.map(r=>r[1]))+1);
   }
  });
 });
}
