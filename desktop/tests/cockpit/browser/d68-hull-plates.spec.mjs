// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D68 / CKP-SHELL-16, -25 (owner 2026-11-08): the hull is the r3 plain plates as the opus-r7 study composes them,
// not a CSS plate. Below the c01 canopy one continuous plain wall runs to the aft plate; no crown plate, cone band,
// record panel or detail layer; no CSS plate, rim or booster. Numbers measured on the study in each shape.
for(const [tier,closed,wallTop,canvas] of [['tall',false,216,911],['tall',true,30,725],['compact',false,48,661],['compact',true,30,643]])
test(`D68 ${tier}${closed?' closed':''}: r3 plain wall from ${wallTop} px to the aft plate`,async({page})=>{
 const bad=[];page.on('response',r=>{if(r.status()>=400)bad.push(new URL(r.url()).pathname);});
 await page.setViewportSize({width:636,height:canvas});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier,profile:closed?'closed':'open'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(200);
 const v=await page.evaluate(()=>{const ck=document.querySelector('#cockpit').getBoundingClientRect(),sh=document.querySelector('.ck-shell'),c=getComputedStyle(sh);
  const el=s=>{const e=document.querySelector(s),q=getComputedStyle(e),r=e.getBoundingClientRect();return {display:q.display,bg:q.backgroundImage,top:Math.round(r.top-ck.top),bottom:Math.round(ck.bottom-r.bottom),left:Math.round(r.left-ck.left),width:Math.round(r.width)};};
  const after=getComputedStyle(sh,'::after');
  return {shellBg:c.backgroundImage,shellShadow:c.boxShadow,boosters:[...document.querySelectorAll('.ck-booster')].map(b=>getComputedStyle(b).display),
   wall:el('.ck-shell .hull-upper'),hidden:['.hull-crown','.hull-cone','.hull-lower','.hull-record'].map(s=>getComputedStyle(document.querySelector('.ck-shell '+s)).display),
   aft:after.backgroundImage,all:[...document.querySelectorAll('#cockpit *')].flatMap(e=>[getComputedStyle(e).backgroundImage,getComputedStyle(e,'::before').backgroundImage,getComputedStyle(e,'::after').backgroundImage]).join(' ')};});
 const plate=tier==='tall'?890:640;
 expect(v.shellBg).toBe('none');expect(v.shellShadow).toBe('none');expect(v.boosters).toEqual(['none','none']);
 expect(v.hidden).toEqual(['none','none','none','none']);
 expect(v.wall).toMatchObject({display:'block',top:wallTop,bottom:22,left:-8,width:636});
 expect(v.wall.bg).toContain(`/assets/hull/lower-${plate}-`);
 expect(v.aft).toContain(`/assets/hull/aft-${plate}-`);
 expect(v.all).not.toMatch(/detail|mouth|lower-skin/);
 expect(bad.filter(p=>p.startsWith('/assets/hull'))).toEqual([]);
});
