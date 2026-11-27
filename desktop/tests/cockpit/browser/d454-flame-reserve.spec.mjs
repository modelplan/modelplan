// SPDX-License-Identifier: MIT
import {readFileSync} from 'node:fs';
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D454 (owner 2026-11-26): the whole engine flame is visible, attached, detached and flying. The native window lays the
// page out on the open root plus the exhaust reserve (CockpitShellLayout.baseReserve, read here from the Swift source so
// the two never drift) and fits that whole canvas to the screen. The tallest flame, full thrust under the widest bell,
// must end inside the reserve, and nothing under the bell row may take the pointer (the native window passes clicks
// there through to what is beneath).
const swift=readFileSync(new URL('../../../native/ModelPlanCockpitWeb/Sources/ModelPlanCockpitWeb/CockpitShellLayout.swift',import.meta.url),'utf8');
const RESERVE=Number(/static let baseReserve: CGFloat = (\d+(?:\.\d+)?)/.exec(swift)?.[1]);
const BELL_ROW=Number(/static let bellRow: CGFloat = (\d+(?:\.\d+)?)/.exec(swift)?.[1]);
const ROOT=905;
function data(){
 const d=visualFixture().data;
 const ref=i=>d.projection.rows[i].accounts[0].subscriptionRef;
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:ref(0),rate:120};
 return d;
}
async function open(page){
 await page.setViewportSize({width:636,height:ROOT+RESERVE});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:data()}))).toBe(true);
 // D459: full thrust is the cockpit's own burn while the host ignites (the tallest flame).
 expect(await receive(send('ignition',{on:true}))).toBe(true);
 await page.waitForFunction(()=>document.getElementById('cockpit').dataset.thrust==='full'&&document.querySelectorAll('.ck-base .bz-flame').length>0);await page.waitForTimeout(100);
}
const measure=page=>page.evaluate(()=>{
 const root=document.getElementById('cockpit').getBoundingClientRect();
 return {rootBottom:root.bottom,flames:[...document.querySelectorAll('.ck-base .bz-flame')].map(f=>{const r=f.getBoundingClientRect();return {cls:f.className,bottom:r.bottom,w:r.width,pe:getComputedStyle(f).pointerEvents};})};
});

test('D454 the reserve holds the whole flame, at the widest bell too',async({page})=>{
 expect(RESERVE).toBeGreaterThan(BELL_ROW);expect(BELL_ROW).toBe(46);
 await open(page);
 let v=await measure(page);
 expect(v.rootBottom).toBeCloseTo(ROOT,0);
 expect(v.flames.length).toBeGreaterThanOrEqual(4);
 for(const f of v.flames){expect(f.bottom,f.cls).toBeLessThanOrEqual(v.rootBottom+RESERVE-1.5);expect(f.pe).toBe('none');}
 // The widest bell the CSS allows (101 px): its full-thrust flame is the tallest box the page can draw.
 await page.evaluate(()=>{for(const b of document.querySelectorAll('.ck-base :is(.bz,.bz-empty)'))b.style.setProperty('--cw','200px');});
 v=await measure(page);
 const widest=v.flames.filter(f=>f.w>=95);
 expect(widest.length).toBeGreaterThan(0);
 for(const f of widest){expect(f.w).toBeCloseTo(101*.95,0);expect(f.bottom,'the tallest flame ends inside the reserve').toBeLessThanOrEqual(v.rootBottom+RESERVE-1.5);}
});

test('D454 nothing under the bell row takes the pointer',async({page})=>{
 await open(page);
 const hits=await page.evaluate(({root,row,reserve})=>{
  const out=[];
  for(let y=root+row+1;y<root+reserve;y+=6)for(let x=2;x<636;x+=17){
   const e=document.elementFromPoint(x,y);
   if(e&&e!==document.body&&e!==document.documentElement&&e.closest('#cockpit'))out.push(`${x},${y}:${e.className}`);
  }
  return out;
 },{root:ROOT,row:BELL_ROW,reserve:RESERVE});
 expect(hits).toEqual([]);
});
