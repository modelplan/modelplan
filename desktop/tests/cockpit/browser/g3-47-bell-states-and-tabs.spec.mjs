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

// CKP-ENG-16/17, CKP-SHELL-15: every subscribed bell takes the dark gunmetal transfer, close to the hull; only a
// working bell lights its mouth in the quota-status colour. Idle bells stay dark.
test('G3-47 idle bells are dark gunmetal; only the working bell lights its mouth',async({page})=>{
 await open(page);
 const bells=await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz')].map(b=>{const l=b.querySelector('.bz-line').getBoundingClientRect();
  return {cls:b.className,filter:getComputedStyle(b.querySelector('.bz-line')).filter,x:l.left+l.width/2,top:l.top,h:l.height,w:l.width};}));
 expect(bells.map(b=>b.cls)).toEqual(['bz work','bz idle','bz idle','bz idle']);
 for(const b of bells)expect(b.filter).toBe('saturate(0.12) brightness(0.78)');
 // The mouth sits in the lower part of the bell; sample its centre just above the rim.
 const mouth=async b=>firstPixel(await page.screenshot({clip:{x:Math.round(b.x),y:Math.round(b.top+b.h*0.62),width:1,height:1},omitBackground:true}));
 const working=await mouth(bells[0]);
 for(const b of bells.slice(1)){const idle=await mouth(b);expect(lum(idle),`idle mouth ${JSON.stringify(idle)}`).toBeLessThan(60);}
 // Weekly 40 % is the tightest window: amber (#eac17b) light, clearly brighter (study 60 % sheet) and warmer than an idle mouth.
 expect(lum(working),`working mouth ${JSON.stringify(working)}`).toBeGreaterThan(80);
 expect(working[0]).toBeGreaterThan(working[2]+40);
});

// COL-2.1-07: vendor colour is identity on the key strip, and the key shows its vendor mark (official edition).
test('G3-47 vendor keys keep their identity colour and mark',async({page})=>{
 const missing=[];page.on('response',r=>{if(r.status()>=400)missing.push(new URL(r.url()).pathname);});
 await open(page);
 const keys=await page.evaluate(()=>[...document.querySelectorAll('.eng-keys .ek[data-sub]')].map(k=>{const i=k.querySelector('img.lamp');
  return {name:k.querySelector('.ek-name')?.textContent,strip:getComputedStyle(k.querySelector('.bl')).backgroundColor,mark:i?{src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0}:null};}));
 expect(keys.map(k=>k.strip)).toEqual(['rgb(106, 168, 255)','rgb(255, 154, 106)','rgb(238, 242, 246)','rgb(198, 204, 212)']);
 expect(keys.slice(0,3).map(k=>k.mark?.loaded)).toEqual([true,true,true]);
 expect(keys[3].mark).toBeNull();
 expect(missing).toEqual([]);
});
