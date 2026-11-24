// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-47 (owner 2026-11-08, D51): the base bells and their flames are drawn in the 46 px reserve under the root,
// one bell per visible subscription under its engine column; a subscription with a running session of its own
// burns. G3-131 (D294): height fixed 10 px, width = column x 0.7 clamped to 81-101 px.
async function open(page,{tier='tall',reduceMotion=false}={}){
 await page.setViewportSize({width:636,height:tier==='tall'?951:681});
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
   sheet:s?{anim:getComputedStyle(s,'::before').animationName+'|'+getComputedStyle(s,'::after').animationName,bottom:q.bottom,top:q.top,opacity:Number(st.opacity),colour:getComputedStyle(s,'::before').backgroundImage}:null,plumes:b.querySelectorAll('.bz-plume').length};});
 const b=base?.getBoundingClientRect();
 return {rootBottom:box.bottom,base:b?{top:b.top,height:b.height}:null,cols,bells,empty:document.querySelectorAll('.ck-base .bz-empty').length,bays:document.querySelectorAll('.ck-eng .eng-cols .ec-bay').length};
});

for(const tier of ['tall','compact'])test(`G3-47 ${tier}: one bell per column in the reserve, the running subscription burns`,async({page})=>{
 await open(page,{tier});const v=await read(page);
 expect(v.base).toEqual({top:v.rootBottom,height:46});
 expect(v.bells.length).toBe(v.cols.length);expect(v.cols.length).toBeGreaterThan(0);
 expect(v.empty).toBe(v.bays);
 for(const [i,b] of v.bells.entries()){
  expect(Math.abs(b.x-v.cols[i].x)).toBeLessThan(0.6);
  const w=Math.min(101,Math.max(81,v.cols[i].w*.7));
  expect(b.w).toBeCloseTo(w,0);expect(b.h).toBeCloseTo(10,1);expect(b.w/b.h).toBeLessThanOrEqual(81/10*1.25+.05);
  expect(b.top).toBeGreaterThanOrEqual(v.rootBottom-0.5);
  expect(b.image).toContain('assets/bells/bell-silver-2x.png');
 }
 expect(v.bells.map(b=>b.cls)).toEqual(v.bells.map((_,i)=>i<2?'bz work':'bz idle'));
 expect(v.bells[0].label).toMatch(/working now · 120 t\/s/);
 // D294: no flame or plume element; the working light is the sheet (mouth wash + cone) breathing on its pseudo-elements.
 expect(v.bells[0].sheet.anim).toBe('cockpit-light-breathe|cockpit-light-breathe');
 expect(v.bells.every(b=>b.plumes===0)).toBe(true);
 expect(v.bells[0].sheet.opacity).toBe(1);
 expect(v.bells[1].sheet).not.toBeNull();expect(v.bells.slice(2).every(b=>b.sheet===null)).toBe(true);
});

test('G3-47 the working light breathing stops under Reduce Motion, while hidden and with the shutter closed',async({page})=>{
 const {send,receive}=await open(page,{reduceMotion:true});
 expect((await read(page)).bells[0].sheet.anim).toBe('none|none');
 expect(await receive(send('appearance',{...appearance,reduceMotion:false}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0].sheet.anim).toBe('cockpit-light-breathe|cockpit-light-breathe');
 expect(await receive(send('visibility',{visible:false,occluded:true,key:false}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0]?.sheet?.anim??'none|none').toBe('none|none');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 await expect.poll(async()=>(await read(page)).bells[0]?.sheet?.anim??'none|none').toBe('none|none');
});

test('G3-47 hovering a bell lights its column and shows its name (CKP-ENG-20)',async({page})=>{
 await open(page);
 const bell=page.locator('.ck-base .bz').first();await bell.hover();
 await expect(bell.locator('.bz-tip')).toBeVisible();await expect(bell.locator('.bz-tip')).toContainText('working now');
 expect(await page.locator('.ck-eng .ec.xhl').count()).toBe(1);
 await page.mouse.move(5,5);expect(await page.locator('.ck-eng .ec.xhl').count()).toBe(0);
});

test('G3-47 a session whose ref names no subscription lights no bell',async({page})=>{
 await page.setViewportSize({width:636,height:951});
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

// G3-131 (D294): the size rule at 2, 3, 4 and 6 columns: height 10 px, width = column x 0.7 inside 81-101 px.
for(const [cols,wide] of [[2,266],[3,177],[4,133],[6,89]])test(`G3-131 bell size at ${cols} columns (column ${wide} px)`,async({page})=>{
 await open(page);
 const got=await page.evaluate(([cw])=>[...document.querySelectorAll('.ck-base .bz')].slice(0,1).map(b=>{b.style.setProperty('--cw',cw+'px');const r=b.querySelector('.bz-line').getBoundingClientRect();return [r.width,r.height];}),[wide]);
 for(const [w,h] of got){expect(w).toBeCloseTo(Math.min(101,Math.max(81,wide*.7)),1);expect(h).toBeCloseTo(10,1);}
});

// G3-131 (D294): the landing burn lights every bell amber, the working light steps aside (the shimmer-opacity bug: no
// animation may hold it lit), and everything returns when the host puts the ignition out; Reduce Motion has no burn motion.
test('G3-131 ignition hides the working light and burns on every bell',async({page})=>{
 await open(page);
 const state=()=>page.evaluate(()=>({ember:[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty)')].map(b=>Number(getComputedStyle(b,'::before').opacity)),
  plume:[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty)')].map(b=>Number(getComputedStyle(b,'::after').opacity)),sheet:Number(getComputedStyle(document.querySelector('.ck-base .bz-sheet')).opacity)}));
 expect((await state()).sheet).toBe(1);
 await page.evaluate(()=>{document.getElementById('cockpit').dataset.ignite='true';});
 await expect.poll(async()=>(await state()).sheet).toBe(0);
 const lit=await state();
 expect(lit.plume.every(o=>o>.5)).toBe(true);expect(lit.ember.every(o=>o>.3)).toBe(true);
 await page.evaluate(()=>{delete document.getElementById('cockpit').dataset.ignite;});
 await expect.poll(async()=>(await state()).sheet,{timeout:3000}).toBe(1);
 await expect.poll(async()=>Math.max(...(await state()).plume),{timeout:3000}).toBeLessThan(.05);
});
test('G3-131 Reduce Motion leaves the burn without animation or transition',async({page})=>{
 await open(page,{reduceMotion:true});
 await page.evaluate(()=>{document.getElementById('cockpit').dataset.ignite='true';});
 const m=await page.evaluate(()=>{const s=getComputedStyle(document.querySelector('.ck-base .bz'),'::after');return {a:s.animationName,t:s.transitionDuration};});
 expect(m.a).toBe('none');expect(m.t).toBe('0s');
});
