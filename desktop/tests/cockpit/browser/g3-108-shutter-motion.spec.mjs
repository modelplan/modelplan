// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// G3-108 (owner, build 14e): opening or closing the porthole made the whole cockpit jump: the native window changed
// its frame in one frame and the page moved the body (strip 253 -> 25) in a later one. The page now keeps one canvas
// (the open root's) and the body at one place on it, open or closed, so the page's relayout can never move the body,
// whenever its message lands; the porthole itself closes (the glass slides down into the hull top) and opens.
// CKP-SHELL-07: closing keeps the open scale; CKP-PORT-09: the slab replaces the canopy; CKP-MOT-03: Reduce Motion
// draws the new shell at once.
const BODY=['.ck-head','.ck-eng','.ck-deck','.ck-tape','.ck-base'];
async function mount(page,tier,reduceMotion){
 await page.setViewportSize({width:636,height:tier==='tall'?939:669});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell:{...shell,tier}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 await page.waitForTimeout(100);
 return {send,receive};
}
const body=page=>page.evaluate(sel=>sel.map(s=>{const r=document.querySelector(s).getBoundingClientRect();return [s,Math.round(r.left),Math.round(r.top),Math.round(r.width),Math.round(r.height)].join(' ');}),BODY);
// Samples the strip's top on every animation frame for `ms`, starting in the same task as the shell message.
const sampleWhile=(page,raw,ms)=>page.evaluate(([raw,ms])=>new Promise(done=>{
 const tops=[],shells=[],moving=[],strip=()=>document.querySelector('.ck-head').getBoundingClientRect().top,ck=document.querySelector('#cockpit');
 window.modelPlanCockpit.receive(raw);const start=performance.now();
 const step=()=>{tops.push(strip());shells.push(ck.dataset.shell);moving.push(document.querySelector('.ck-portrow').getAnimations().some(a=>a.playState==='running'));
  if(performance.now()-start<ms)requestAnimationFrame(step);else done({tops,shells,moving});};
 step();}),[raw,ms]);

for(const [tier,strip,slab] of [['tall',253,228],['compact',65,40]])
test(`G3-108 ${tier}: the body stays put and the porthole itself closes and opens`,async({page})=>{
 const {send}=await mount(page,tier,false);
 const open=await body(page);
 expect(open[0].split(' ')[2]).toBe(String(strip));
 const closing=await sampleWhile(page,send('shell',{...shell,tier,profile:'closed'}),450);
 expect(new Set(closing.tops),'the strip never moves while the porthole closes').toEqual(new Set([strip]));
 expect(closing.shells[0],'the open layout stays (open-only motion stopped) while the glass slides into the hull').toBe('closing');
 expect(closing.moving.some(Boolean),'the porthole animates').toBe(true);
 expect(closing.shells.at(-1)).toBe('closed');
 expect(await body(page),'closed, the body is where it was open').toEqual(open);
 // The slab is the closed window's top edge (strip - 25) and reaches under the upper walls: no seam between them.
 const cut=await page.evaluate(()=>{const c=document.querySelector('.ck-shell .hull-crown').getBoundingClientRect(),w=document.querySelector('.ck-shell .hull-upper').getBoundingClientRect();return {slabTop:Math.round(c.top),overlap:c.bottom-w.top};});
 expect(cut.slabTop).toBe(slab);
 expect(cut.overlap,'the slab overlaps the walls').toBeGreaterThanOrEqual(1);
 const opening=await sampleWhile(page,send('shell',{...shell,tier,profile:'open'}),450);
 expect(new Set(opening.tops),'the strip never moves while the porthole opens').toEqual(new Set([strip]));
 expect(opening.shells[0],'the open shell is drawn at once, the glass rises out of the hull').toBe('open');
 expect(opening.moving.some(Boolean)).toBe(true);
 expect(await body(page)).toEqual(open);
});

test('G3-108 Reduce Motion: the shell changes at once, with no porthole motion and the same body place',async({page})=>{
 const {send}=await mount(page,'tall',true);
 const open=await body(page);
 const closing=await sampleWhile(page,send('shell',{...shell,profile:'closed'}),120);
 expect(closing.shells[0]).toBe('closed');
 expect(closing.moving.some(Boolean)).toBe(false);
 expect(await body(page)).toEqual(open);
});
