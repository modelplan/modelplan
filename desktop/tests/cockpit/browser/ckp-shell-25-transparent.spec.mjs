// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {firstPixel} from '../png-pixel.mjs';

// CKP-SHELL-25 (owner 11-08 review): around the hull everything is transparent; only the hull, the canopy and the
// base row are drawn. Pixels beside the canopy, above it, and in the base reserve outside the bells have alpha 0 on the page
// the native window shows (the window and web view are clear).
for(const [tier,canvas] of [['tall',939],['compact',669]])for(const closed of [false,true])
test(`CKP-SHELL-25 ${tier}${closed?' closed':''}: nothing is painted outside the hull silhouette`,async({page})=>{
 const root=closed?(tier==='tall'?691:609):(tier==='tall'?905:635),height=root+34;
 await page.setViewportSize({width:636,height});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier,profile:closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(200);
 const outside=[];
 // D68 r3 silhouette (measured): the canopy narrows toward the top, the walls fill the width from the canopy foot to
 // the aft plate, and the base reserve is clear except for the bells.
 const wallTop=closed?30:(tier==='tall'?244:56);
 for(const x of [0,1,634,635]){outside.push([x,2],[x,root+3],[x,height-3]);if(wallTop>=48)outside.push([x,Math.round(wallTop/2)]);}
 for(const [x,y] of outside){
  const [,,,alpha]=firstPixel(await page.screenshot({clip:{x,y,width:1,height:1},omitBackground:true}));
  expect(alpha,`alpha at ${x},${y}`).toBe(0);
 }
});
