// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D454 (owner 2026-11-26): the official bells hang the owner's blue flame set. working + high output -> full thrust flipbook,
// working + lower output -> short, idle subscription -> ember. D450: nothing moves unless the page is active, open and not reduced.
test.use({deviceScaleFactor:2});
function data(){
 const d=visualFixture().data,vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:null};
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 const ref=i=>d.projection.rows[i].accounts[0].subscriptionRef;
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:ref(0),rate:120};
 d.details.sessions[1]={...d.details.sessions[1],subscriptionRef:ref(1),rate:30};
 d.details.sessions[2]={...d.details.sessions[2],state:'idle'};
 return d;
}
async function open(page,{reduceMotion=false,active=true}={}){
 await page.setViewportSize({width:636,height:1020});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:active,occluded:!active,key:active}))).toBe(true);
 expect(await receive(send('display',{data:data()}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length===4);await page.waitForTimeout(200);
}
const flames=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz')].map(b=>{const f=b.querySelector('.bz-flame');
 return f?{cls:f.className,anim:getComputedStyle(f).animationName,image:getComputedStyle(f).backgroundImage,w:f.getBoundingClientRect().width}:null;}));

test('D454 each state hangs its own flame and only full thrust flips',async({page})=>{
 await open(page);
 const f=await flames(page);
 expect(f.map(x=>x&&x.cls.replace('bz-flame ',''))).toEqual(['f-full','f-short','f-ember','f-ember']);
 expect(f[0].image).toContain('flame-full-strip');expect(f[1].image).toContain('flame-short');expect(f[2].image).toContain('flame-ember');
 expect(f.map(x=>x.anim)).toEqual(['cockpit-flame-flip','none','none','none']);
 for(const x of f)expect(x.w).toBeGreaterThan(70);
 if(process.env.FLAME_SHOT){
  const r=await page.evaluate(()=>{const b=document.querySelector('.ck-base').getBoundingClientRect();return {y:b.top,h:b.height};});
  await page.screenshot({path:process.env.FLAME_SHOT,clip:{x:0,y:Math.max(0,r.y-30),width:636,height:156}});
 }
});

test('D450 the flipbook stops under Reduce Motion and on a hidden cockpit, holding one still frame',async({page})=>{
 await open(page,{reduceMotion:true});
 let f=await flames(page);
 expect(f[0].cls).toContain('f-full');expect(f.map(x=>x.anim)).toEqual(['none','none','none','none']);
 await open(page,{active:false});
 f=await flames(page);expect(f.map(x=>x.anim)).toEqual(['none','none','none','none']);
});
