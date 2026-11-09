// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-39 / CKP-SHELL-08, -10: the native window is root + 34 px. These tops are read from the opus-r7 study
// at both profiles, relative to the root; the tape must hold every record line at its own height.
const profiles=[
 {tier:'compact',canvas:669,root:635,canopy:56,head:65,eng:100,deck:329,tape:555,tapeH:58,lines:3},
 {tier:'tall',canvas:939,root:905,canopy:244,head:253,eng:288,deck:523,tape:789,tapeH:94,lines:5},
];
for(const p of profiles)test(`G3-39 ${p.tier} page registers to the native window and the study`,async({page})=>{
 await page.setViewportSize({width:636,height:p.canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier:p.tier}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const box=await page.evaluate(()=>{
  const r=document.querySelector('#cockpit').getBoundingClientRect(),top=s=>document.querySelector(s).getBoundingClientRect().top-r.top;
  const tape=document.querySelector('.ck-tape').getBoundingClientRect(),row=document.querySelector('.ck-portrow').getBoundingClientRect(),canopy=getComputedStyle(document.querySelector('.ck-portrow'),'::before');
  return {root:r.height,head:top('.ck-head'),eng:top('.ck-eng'),deck:top('.ck-deck'),tape:top('.ck-tape'),tapeH:tape.height,
   canopyTop:row.top+parseFloat(canopy.top)-r.top,canopyHeight:parseFloat(canopy.height),canopyWidth:parseFloat(canopy.width),
   overflow:[...document.querySelectorAll('.ck-tape .tl')].filter(e=>e.getBoundingClientRect().bottom>tape.bottom).length,lines:document.querySelectorAll('.ck-tape .tl').length};
 });
 expect(box).toEqual({root:p.root,head:p.head,eng:p.eng,deck:p.deck,tape:p.tape,tapeH:p.tapeH,canopyTop:0,canopyHeight:p.canopy,canopyWidth:636,overflow:0,lines:p.lines});
});
