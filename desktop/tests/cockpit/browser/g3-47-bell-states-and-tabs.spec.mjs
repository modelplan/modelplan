// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {firstPixel} from '../png-pixel.mjs';
import {decode,stats} from '../png-region.mjs';

// Owner 11-08 review against the opus-r7 study. Real CLI vendor keys: codex -> openai, claude, cursor; Gemini CLI has none.
function data(){
 const d=visualFixture().data,vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:null};
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:d.projection.rows[0].accounts[0].subscriptionRef,rate:120};
 return d;
}
async function open(page){
 await page.setViewportSize({width:636,height:911});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:data()}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length===4);await page.waitForTimeout(200);
}
const lum=([r,g,b])=>0.2126*r+0.7152*g+0.0722*b;

// D68 (owner 2026-11-08), CKP-ENG-16/17: a bell that is not working has no sheen and sits at the tone of the r3 hull
// bottom; only a working bell is lit and lights its mouth. Same regions and limits as the coordinator's visual gate:
// the reference is the rendered r3 aft plate (x from 40 px inside the root to 40 px before its end, the root's last
// 20 to 4 px), the bell is its whole drawn box; luminance within 15, colour within 30, sheen (p97 - p50) at most 60.
// The aft plate must be the r3 art, so this can never pass against a CSS plate.
test('G3-47 idle bells match the r3 hull bottom; only the working bell is lit',async({page})=>{
 await open(page);
 const g=await page.evaluate(()=>{const ck=document.querySelector('#cockpit').getBoundingClientRect();
  return {ck:{x:ck.left,y:ck.top,w:ck.width,h:ck.height},aft:getComputedStyle(document.querySelector('.ck-shell'),'::after').backgroundImage,
   bells:[...document.querySelectorAll('.ck-base .bz')].map(b=>{const r=b.querySelector('.bz-line').getBoundingClientRect();return {cls:b.className,x:r.left,y:r.top,w:r.width,h:r.height};})};});
 expect(g.aft).toContain('/assets/hull/aft-890-');
 expect(g.bells.map(b=>b.cls)).toEqual(['bz work','bz idle','bz idle','bz idle']);
 const shot=async c=>stats(decode(await page.screenshot({clip:{x:Math.round(c.x),y:Math.round(c.y),width:Math.round(c.w),height:Math.round(c.h)},omitBackground:true})));
 const hull=await shot({x:g.ck.x+40,y:g.ck.y+g.ck.h-20,w:g.ck.w-80,h:16});
 const dist=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1],a[2]-b[2]);
 for(const b of g.bells.slice(1)){
  const bell=await shot(b),label=`idle bell L ${bell.mean.toFixed(0)} rgb ${bell.rgb.map(Math.round)} vs r3 bottom L ${hull.mean.toFixed(0)} rgb ${hull.rgb.map(Math.round)}`;
  expect(Math.abs(bell.mean-hull.mean),label).toBeLessThanOrEqual(15);
  expect(dist(bell.rgb,hull.rgb),label).toBeLessThanOrEqual(30);
  expect(bell.p97-bell.p50,`idle bell sheen p50 ${bell.p50.toFixed(0)} p97 ${bell.p97.toFixed(0)}`).toBeLessThanOrEqual(60);
 }
 const working=await shot(g.bells[0]);
 expect(working.mean,'the working bell keeps its lit gunmetal').toBeGreaterThan(hull.mean+20);
 // The mouth of the working bell glows in the status colour; idle mouths do not.
 const mouth=async b=>firstPixel(await page.screenshot({clip:{x:Math.round(b.x+b.w/2),y:Math.round(b.y+b.h*0.62),width:1,height:1},omitBackground:true}));
 const lit=await mouth(g.bells[0]);
 expect(lum(lit),`working mouth ${JSON.stringify(lit)}`).toBeGreaterThan(80);expect(lit[0]).toBeGreaterThan(lit[2]+40);
 for(const b of g.bells.slice(1)){const dark=await mouth(b);expect(lum(dark),`idle mouth ${JSON.stringify(dark)}`).toBeLessThan(lum(lit)-30);}
});

// COL-2.1-07: vendor colour is identity on the key strip, and the key shows its vendor mark (official edition).
test('G3-47 vendor keys keep their identity colour and mark',async({page})=>{
 const missing=[];page.on('response',r=>{if(r.status()>=400)missing.push(new URL(r.url()).pathname);});
 await open(page);
 const keys=await page.evaluate(()=>[...document.querySelectorAll('.eng-keys .ek[data-sub]')].map(k=>{const i=k.querySelector('img.lamp');
  const n=k.querySelector('.ek-name').getBoundingClientRect(),m=i?.getBoundingClientRect();
  return {name:k.querySelector('.ek-name')?.textContent,strip:getComputedStyle(k.querySelector('.bl')).backgroundColor,mark:i?{src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0,beside:m.right<=n.left&&Math.abs((m.top+m.height/2)-(n.top+n.height/2))<=1.5}:null};}));
 expect(keys.map(k=>k.strip)).toEqual(['rgb(106, 168, 255)','rgb(255, 154, 106)','rgb(238, 242, 246)','rgb(198, 204, 212)']);
 expect(keys.slice(0,3).map(k=>k.mark?.loaded)).toEqual([true,true,true]);
 // The mark sits beside the name on one centre line, as in the study.
 expect(keys.slice(0,3).map(k=>k.mark?.beside)).toEqual([true,true,true]);
 expect(keys[3].mark).toBeNull();
 expect(missing).toEqual([]);
});
