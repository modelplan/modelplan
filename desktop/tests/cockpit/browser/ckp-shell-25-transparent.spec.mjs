// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {firstPixel} from '../png-pixel.mjs';

// CKP-SHELL-25 (owner 11-08 review): around the hull everything is transparent; only the hull, the canopy and the
// base row are drawn. Pixels left and right of the hull and its side boosters (x 3..633) and in the reserve corners have alpha 0 on the page
// the native window shows (the window and web view are clear).
for(const [tier,canvas] of [['tall',911],['compact',661]])for(const closed of [false,true])
test(`CKP-SHELL-25 ${tier}${closed?' closed':''}: nothing is painted outside the hull silhouette`,async({page})=>{
 const root=closed?(tier==='tall'?691:609):(tier==='tall'?877:627),height=root+34;
 await page.setViewportSize({width:636,height});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell:{...shell,tier,profile:closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(200);
 const outside=[];
 for(const y of [20,Math.round(root*.3),Math.round(root*.6),root-20,root+4,height-3])for(const x of [0,1,634,635])outside.push([x,y]);
 for(const [x,y] of outside){
  const [,,,alpha]=firstPixel(await page.screenshot({clip:{x,y,width:1,height:1},omitBackground:true}));
  expect(alpha,`alpha at ${x},${y}`).toBe(0);
 }
});
