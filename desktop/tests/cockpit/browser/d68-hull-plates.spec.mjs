// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D68 / CKP-SHELL-16, -25 (owner 2026-11-08): the hull is the r3 plain plates as the opus-r7 study composes them,
// not a CSS plate. Below the c01 canopy the side walls are the study's upper wall, taper and lower wall (owner build 13); no crown plate,
// record panel or detail layer; no CSS plate, rim or booster. The wall tile is the study's canopy-h1 lower skin. Numbers measured on the study in each shape.
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
   wall:el('.ck-shell .hull-upper'),crown:{...el('.ck-shell .hull-crown'),height:Math.round(document.querySelector('.ck-shell .hull-crown').getBoundingClientRect().height),filter:getComputedStyle(document.querySelector('.ck-shell .hull-crown')).filter},hidden:['.hull-crown','.hull-cone','.hull-lower','.hull-record'].map(s=>getComputedStyle(document.querySelector('.ck-shell '+s)).display),
   aft:after.backgroundImage,headTop:Math.round(document.querySelector('.ck-head').getBoundingClientRect().top-ck.top),tapeGap:Math.round(ck.bottom-document.querySelector('.ck-tape').getBoundingClientRect().bottom),strip:getComputedStyle(document.querySelector('.ck-head'),'::before').clipPath,body:getComputedStyle(sh,'::before').clipPath,cap:(q=>q.backgroundImage+' '+q.backgroundColor)(getComputedStyle(document.querySelector('.s6-closed-cap'))),all:[...document.querySelectorAll('#cockpit *')].flatMap(e=>[getComputedStyle(e).backgroundImage,getComputedStyle(e,'::before').backgroundImage,getComputedStyle(e,'::after').backgroundImage]).join(' ')};});
 const plate=tier==='tall'?890:640;
 expect(v.shellBg).toBe('none');expect(v.shellShadow).toBe('none');expect(v.boosters).toEqual(['none','none']);
 // Closed (owner D72): the study's 16 px cap slab sits 14 px down, 620 wide, in the shared gunmetal tone; open, the
 // c01 canopy is the crown and no crown plate shows.
 if(closed){
  expect(v.crown).toMatchObject({display:'block',top:14,height:16,left:0,width:620,filter:'saturate(0.12) brightness(0.78)'});
  expect(v.crown.bg).toContain('/assets/hull/cap-slab.svg');
  // Nothing covers the slab: the page's closed-state section stays transparent (the study has no dark cap there).
  expect(v.cap).toBe('none rgba(0, 0, 0, 0)');
  // The dark body meets the slab's foot (30 px), as in the study: no transparent band between slab and strip.
  expect(v.body).toMatch(/^inset\(30px /);
  // The slab saves the study's 6 px (cap 16 + 2 px first row): the strip sits at 39 px and the record panel ends
  // 22 px above the bottom, on the aft plate's edge, not over it.
  expect([v.headTop,v.tapeGap]).toEqual([39,22]);
  expect(v.hidden.slice(1)).toEqual(['block','block','none']);
 }else expect(v.hidden).toEqual(['none','block','block','none']);
 // Owner build 13: the wall is the study's upper wall, taper and lower wall (b13-hull-taper.spec.mjs has their boxes).
 expect(v.wall).toMatchObject({display:'block',top:wallTop,left:-8,width:636});
 // Side walls (owner, after D68): the study paints the canopy-h1 lower-skin tile, the same bytes in every shape.
 expect(v.wall.bg).toContain('/assets/hull/lower-skin-890-');
 // Closed, the study's aft is its own closed plate (D72).
 expect(v.aft).toContain(closed?'/assets/hull/aft-closed-':`/assets/hull/aft-${plate}-`);
 // The strip panel's own outer 16 px wall paint is clipped so the hull rails run through, as the study does.
 expect(v.strip).toBe('inset(0px 16px)');
 expect(v.all).not.toMatch(/detail|mouth/);
 expect(bad.filter(p=>p.startsWith('/assets/hull'))).toEqual([]);
});
