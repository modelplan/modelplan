// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-47 (owner 2026-11-08, D51): the base bells and their flames are drawn in the 34 px reserve under the root,
// one bell per visible subscription under its engine column; a subscription with a running session of its own
// burns. Sizes follow the base-bells notes: width min(120, column x 121/133), height width x 10/81.
async function open(page,{tier='tall',reduceMotion=false}={}){
 await page.setViewportSize({width:636,height:tier==='tall'?939:669});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=visualFixture().data;
 // The Codex session carries the first subscription's verified ref; the running Claude session has none and joins
 // Claude's only subscription (session-binding rule, #761); the idle session lights nothing.
 data.details.sessions[0]={...data.details.sessions[0],subscriptionRef:data.projection.rows[0].accounts[0].subscriptionRef,rate:120};
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell:{...shell,tier}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0);
 return {send,receive};
}
const read=page=>page.evaluate(()=>{
 const root=document.getElementById('cockpit'),box=root.getBoundingClientRect(),base=document.querySelector('.ck-base');
 const cols=[...document.querySelectorAll('.eng-keys .ek[data-sub]')].map(k=>{const c=[...document.querySelectorAll('.ck-eng .ec[data-col]')].find(e=>e.dataset.col===k.dataset.sub);const r=c.getBoundingClientRect();return {x:r.left+r.width/2,w:r.width};});
 const bells=[...document.querySelectorAll('.ck-base .bz')].map(b=>{const l=b.querySelector('.bz-line'),r=l.getBoundingClientRect(),s=b.querySelector('.bz-sheet'),st=s&&getComputedStyle(s),q=s?.getBoundingClientRect();
  return {cls:b.className,label:b.getAttribute('aria-label'),x:r.left+r.width/2,w:r.width,h:r.height,top:r.top,image:getComputedStyle(l).backgroundImage,
   sheet:s?{anim:st.animationName,mask:st.maskImage||st.webkitMaskImage,bottom:q.bottom,top:q.top,w:s.offsetWidth,h:s.offsetHeight,opacity:Number(st.opacity)}:null,plumes:b.querySelectorAll('.bz-plume').length};});
 const b=base?.getBoundingClientRect();
 return {rootBottom:box.bottom,base:b?{top:b.top,height:b.height}:null,cols,bells,empty:document.querySelectorAll('.ck-base .bz-empty').length,bays:document.querySelectorAll('.ck-eng .eng-cols .ec-bay').length};
});

for(const tier of ['tall','compact'])test(`G3-47 ${tier}: one bell per column in the reserve, the running subscription burns`,async({page})=>{
 await open(page,{tier});const v=await read(page);
 expect(v.base).toEqual({top:v.rootBottom,height:34});
 expect(v.bells.length).toBe(v.cols.length);expect(v.cols.length).toBeGreaterThan(0);
 expect(v.empty).toBe(v.bays);
 for(const [i,b] of v.bells.entries()){
  expect(Math.abs(b.x-v.cols[i].x)).toBeLessThan(0.6);
  const w=Math.min(120,v.cols[i].w*121/133);
  expect(b.w).toBeCloseTo(w,0);expect(b.h).toBeCloseTo(w*10/81,0);
  expect(b.top).toBeGreaterThanOrEqual(v.rootBottom-0.5);
  expect(b.image).toContain('assets/bells/bell-silver-2x.png');
 }
 expect(v.bells.map(b=>b.cls)).toEqual(v.bells.map((_,i)=>i<2?'bz work':'bz idle'));
 expect(v.bells[0].label).toMatch(/working now · 120 t\/s/);
 const sheet=v.bells[0].sheet;
 expect(sheet.anim).toBe('cockpit-mouth-shimmer');
 // CKP-ENG-17: the light fills the mouth and fades out within 5 px past the foot (visible about 3 px), no plume body.
 expect(sheet.bottom).toBeLessThanOrEqual(v.bells[0].top+v.bells[0].h+5.5);
 // D85 (owner chose the prototype glow): no flame or plume element, and the glow box is the study's: starts at bell width x
 // 0.05574, is bell width x 0.9033 x 1.08 wide, bell height - top + 5 px tall, at 60 % paint.
 expect(v.bells.every(b=>b.plumes===0)).toBe(true);
 {const bw=v.bells[0].w,top=bw*.05574;
  expect(sheet.top-v.bells[0].top).toBeCloseTo(top,0);expect(sheet.w).toBeCloseTo(bw*.9033*1.08,0);
  expect(sheet.h).toBeCloseTo(v.bells[0].h-top+5,0);expect(sheet.opacity).toBeGreaterThan(.55);expect(sheet.opacity).toBeLessThan(.65);}
 expect(v.bells[1].sheet).not.toBeNull();expect(v.bells.slice(2).every(b=>b.sheet===null)).toBe(true);
});

test('G3-47 the mouth shimmer stops under Reduce Motion, while hidden and with the shutter closed',async({page})=>{
 const {send,receive}=await open(page,{reduceMotion:true});
 expect((await read(page)).bells[0].sheet.anim).toBe('none');
 expect(await receive(send('appearance',{...appearance,reduceMotion:false}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0].sheet.anim).toBe('cockpit-mouth-shimmer');
 expect(await receive(send('visibility',{visible:false,occluded:true,key:false}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0]?.sheet?.anim??'none').toBe('none');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0]?.sheet?.anim??'none').toBe('none');
});

test('G3-47 hovering a bell lights its column and shows its name (CKP-ENG-20)',async({page})=>{
 await open(page);
 const bell=page.locator('.ck-base .bz').first();await bell.hover();
 await expect(bell.locator('.bz-tip')).toBeVisible();await expect(bell.locator('.bz-tip')).toContainText('working now');
 expect(await page.locator('.ck-eng .ec.xhl').count()).toBe(1);
 await page.mouse.move(5,5);expect(await page.locator('.ck-eng .ec.xhl').count()).toBe(0);
});

test('G3-47 a session whose ref names no subscription lights no bell',async({page})=>{
 await page.setViewportSize({width:636,height:939});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=visualFixture().data;
 data.details.sessions=data.details.sessions.map(s=>({...s,subscriptionRef:'ffffffffffffffff'}));
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0);
 expect(await page.locator('.ck-base .bz.work').count()).toBe(0);
 expect(await page.locator('.ck-base .bz-plume,.ck-base .bz-sheet').count()).toBe(0);
});
