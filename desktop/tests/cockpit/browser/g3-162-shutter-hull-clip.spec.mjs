// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {mkdirSync} from 'node:fs';

// G3-162 (owner, internal build 2): while the shutter moved, the porthole showed half-retracted outside the hull.
// Samples the motion at several points (paused animation) and checks the canopy's visible bounds.
const OUT=process.env.SHUTTER_SHOTS;
async function mount(page){
 await page.setViewportSize({width:636,height:939});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:false},shell:{...shell,tier:'tall'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(100);
 return {send,receive};
}
const seek=(page,t)=>page.evaluate(t=>{const a=document.querySelector('.ck-portrow').getAnimations().find(a=>a.animationName==='cockpit-shutter');a.pause();a.currentTime=t;return new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));},t);
// Visible bounds of the canopy row: its rect cut by the computed clip-path inset (percent of the row's own box).
const visible=page=>page.evaluate(()=>{
 const el=document.querySelector('.ck-portrow'),r=el.getBoundingClientRect(),shell=document.querySelector('.ck-shell').getBoundingClientRect(),head=document.querySelector('.ck-head').getBoundingClientRect();
 const m=/inset\((.*)\)/.exec(getComputedStyle(el).clipPath),v=(m?m[1].split(/\s+/):['0px','0px','0px','0px']);
 const px=(x,n)=>x.endsWith('%')?parseFloat(x)/100*n:parseFloat(x);
 const [t,rt,b,l]=[px(v[0],r.height),px(v[1]??v[0],r.width),px(v[2]??v[0],r.height),px(v[3]??v[1]??v[0],r.width)];
 return {top:r.top+t,bottom:r.bottom-b,left:r.left+l,right:r.right-rt,rowTop:r.top,shellLeft:shell.left,shellRight:shell.right,headTop:head.top};
});
for(const dir of ['closing','opening'])
test(`G3-162 ${dir}: no part of the canopy shows outside the hull silhouette at any point of the motion`,async({page})=>{
 const {send,receive}=await mount(page);
 if(dir==='opening'){await receive(send('shell',{...shell,tier:'tall',profile:'closed'}));await page.waitForFunction(()=>document.querySelector('#cockpit').dataset.shell==='closed');}
 await receive(send('shell',{...shell,tier:'tall',profile:dir==='closing'?'closed':'open'}));
 for(const t of [20,60,125,190,240]){
  await seek(page,t);const v=await visible(page);
  expect(v.left,`${dir} ${t} ms: left`).toBeGreaterThanOrEqual(v.shellLeft);
  expect(v.right,`${dir} ${t} ms: right`).toBeLessThanOrEqual(v.shellRight);
  expect(v.top,`${dir} ${t} ms: nothing above the canopy row (the hull top)`).toBeGreaterThanOrEqual(v.rowTop);
  expect(v.bottom,`${dir} ${t} ms: nothing below the strip's top`).toBeLessThanOrEqual(v.headTop+1);
 }
});

test('G3-162 shots',async({page})=>{
 test.skip(!OUT);
 mkdirSync(OUT,{recursive:true});
 const {send,receive}=await mount(page);
 await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-open.png`,clip:{x:0,y:0,width:636,height:420}});
 await receive(send('shell',{...shell,tier:'tall',profile:'closed'}));
 for(const t of [60,125,190]){await seek(page,t);await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-close-${t}ms.png`,clip:{x:0,y:0,width:636,height:420}});}
 await page.evaluate(()=>{for(const a of document.getAnimations())a.finish();});await page.waitForTimeout(300);
 await receive(send('shell',{...shell,tier:'tall',profile:'open'}));
 for(const t of [60,125,190]){await seek(page,t);await page.screenshot({path:`${OUT}/${process.env.SHUTTER_TAG}-open-${t}ms.png`,clip:{x:0,y:0,width:636,height:420}});}
});
