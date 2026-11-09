// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {firstPixel} from '../png-pixel.mjs';

// Owner 11-08 review against the opus-r7 study. Real CLI vendor keys: codex -> openai, claude, cursor; Gemini CLI has none.
function data(){
 const d=visualFixture().data,vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:null};
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:d.projection.rows[0].accounts[0].subscriptionRef,rate:120};
 // Only the Codex session runs here, so one bell works and three show the idle look.
 d.details.sessions[1]={...d.details.sessions[1],state:'idle'};
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

// D70 (owner 2026-11-08), CKP-ENG-16/17, CKP-SHELL-15: subscribed bells are the study's bells exactly: the silver
// bell under the shared gunmetal transfer (measured on opus-r7: saturate(.12) brightness(.78)), idle and working
// alike. A working subscription is shown only by the light from its bell mouth in the quota-status colour; an idle
// bell's mouth stays dark. Supersedes the D68 darkened idle bells.
test('G3-47 subscribed bells match the study; only the working bell lights its mouth',async({page})=>{
 await open(page);
 const bells=await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz')].map(b=>{const l=b.querySelector('.bz-line'),r=l.getBoundingClientRect(),c=getComputedStyle(l);
  return {cls:b.className,filter:c.filter,image:c.backgroundImage,x:r.left+r.width/2,top:r.top,h:r.height,sheet:!!b.querySelector('.bz-sheet')};}));
 expect(bells.map(b=>b.cls)).toEqual(['bz work','bz idle','bz idle','bz idle']);
 for(const b of bells){expect(b.filter).toBe('saturate(0.12) brightness(0.78)');expect(b.image).toContain('assets/bells/bell-silver-2x.png');}
 expect(bells.map(b=>b.sheet)).toEqual([true,false,false,false]);
 // Hover keeps the study's finish: the column light and the name show it, not a brighter bell.
 await page.locator('.ck-base .bz').nth(1).hover();
 expect(await page.locator('.ck-base .bz').nth(1).locator('.bz-line').evaluate(l=>getComputedStyle(l).filter)).toBe('saturate(0.12) brightness(0.78)');
 await page.mouse.move(5,5);
 const mouth=async b=>firstPixel(await page.screenshot({clip:{x:Math.round(b.x),y:Math.round(b.top+b.h*0.62),width:1,height:1},omitBackground:true}));
 const lit=await mouth(bells[0]);
 expect(lum(lit),`working mouth ${JSON.stringify(lit)}`).toBeGreaterThan(80);expect(lit[0]).toBeGreaterThan(lit[2]+40);
 for(const b of bells.slice(1)){const dark=await mouth(b);expect(lum(dark),`idle mouth ${JSON.stringify(dark)}`).toBeLessThan(60);}
});

// D70: only an empty slot (no subscription) is darker: the study's night/black bell, quietly dimmed, with no light.
test('G3-47 an empty slot shows the darker night bell',async({page})=>{
 await page.setViewportSize({width:636,height:911});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const d=data();d.projection.rows=d.projection.rows.slice(0,2);d.subscriptions=d.subscriptions.slice(0,2);if(d.details)d.details.subscriptions=d.details.subscriptions.slice(0,2);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:d}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz-empty').length>0);
 const empty=await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-empty')].map(b=>{const c=getComputedStyle(b.querySelector('.bz-line'));return {filter:c.filter,image:c.backgroundImage,sheet:!!b.querySelector('.bz-sheet')};}));
 for(const e of empty){expect(e.filter).toBe('brightness(0.9)');expect(e.image).toContain('assets/bells/bell-night-');expect(e.sheet).toBe(false);}
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
