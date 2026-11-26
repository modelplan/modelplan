// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D454 (owner 2026-11-26): the official bells hang the owner's blue flame set. working + high output -> full thrust flipbook,
// working + lower output -> short, idle subscription -> ember. D450: nothing moves unless the page is active, open and not reduced.
test.use({deviceScaleFactor:2});
function data(full=false){
 const d=visualFixture().data,vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:null};
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 const ref=i=>d.projection.rows[i].accounts[0].subscriptionRef;
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:ref(0),rate:120};
 d.details.sessions[1]={...d.details.sessions[1],subscriptionRef:ref(1),rate:full?120:30};
 d.details.sessions[2]={...d.details.sessions[2],state:full?'running':'idle',...(full?{subscriptionRef:ref(2),rate:90}:{})};
 if(full)d.details.sessions[3]={...d.details.sessions[0],sessionRef:'0000000000000004',subscriptionRef:ref(3),rate:100};
 return d;
}
async function open(page,{reduceMotion=false,active=true,full=false}={}){
 await page.setViewportSize({width:636,height:1020});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:active,occluded:!active,key:active}))).toBe(true);
 expect(await receive(send('display',{data:data(full)}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length===4);await page.waitForTimeout(200);
}
const flames=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz')].map(b=>{const f=b.querySelector('.bz-flame');
 return f?{cls:f.className,anim:getComputedStyle(f).animationName,image:getComputedStyle(f).backgroundImage,w:f.getBoundingClientRect().width}:null;}));

test('D454 each state hangs its own flame and only full thrust flips',async({page})=>{
 await open(page);
 const f=await flames(page);
 expect(f.map(x=>x&&x.cls.replace('bz-flame ',''))).toEqual(['f-full','f-short','f-ember','f-ember']);
 expect(f[0].image).toContain('flame-full-strip');expect(f[1].image).toContain('flame-short');expect(f[2].image).toContain('flame-ember');
 expect(f.map(x=>x.anim)).toEqual(['cockpit-flame-flip, cockpit-flame-breathe, cockpit-flame-flicker','none','none','none']);
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

const timing=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-flame.f-full')].map(f=>{const s=getComputedStyle(f);
 return {dur:s.animationDuration,delay:s.animationDelay,names:s.animationName,props:f.getAnimations().flatMap(a=>a.effect.getKeyframes().flatMap(k=>Object.keys(k))).filter(k=>!['offset','easing','composite','computedOffset'].includes(k)).sort().filter((k,i,a)=>a.indexOf(k)===i),
  fp:f.parentElement.style.getPropertyValue('--fp'),fb:f.parentElement.style.getPropertyValue('--fb'),fl:f.parentElement.style.getPropertyValue('--fl')};}));

test('D454 per-nozzle dynamics: each full-thrust flame has its own subtle timing, and only transform-class properties and opacity move',async({page})=>{
 await open(page,{full:true});
 const t=await timing(page);
 expect(t.length).toBe(4);
 for(const k of ['dur','delay'])expect(new Set(t.map(x=>x[k])).size,k).toBe(t.length);
 for(const k of ['fp','fb','fl'])expect(new Set(t.map(x=>x[k])).size,k).toBe(t.length);
 for(const x of t){
  const fps=1/parseFloat(x.fp)*4;expect(fps).toBeGreaterThan(8.3);expect(fps).toBeLessThan(9.7);
  const fb=parseFloat(x.fb);expect(fb).toBeGreaterThanOrEqual(1.2);expect(fb).toBeLessThanOrEqual(1.8);
  expect(x.props.filter(p=>!['backgroundPositionX','scale','opacity'].includes(p))).toEqual([]);
 }
 const lo=await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-flame.f-full')].map(f=>({s:getComputedStyle(f).scale,o:+getComputedStyle(f).opacity})));
 for(const x of lo){expect(parseFloat(x.s.split(' ')[1])).toBeGreaterThan(.97);expect(parseFloat(x.s.split(' ')[1])).toBeLessThan(1.03);expect(x.o).toBeGreaterThanOrEqual(.94);expect(x.o).toBeLessThanOrEqual(1);}
 if(process.env.FLAME_FRAMES){const r=await page.evaluate(()=>{const b=document.querySelector('.ck-base').getBoundingClientRect();return {y:b.top,h:b.height};});
  for(let i=0;i<30;i++){await page.evaluate(t=>document.getAnimations().forEach(a=>{a.pause();a.currentTime=t;}),i*100);await page.screenshot({path:process.env.FLAME_FRAMES+'/f'+String(i).padStart(2,'0')+'.png',clip:{x:0,y:Math.max(0,r.y-10),width:636,height:150}});}}
 // Deterministic: a reload gives the same per-bell timings.
 await open(page,{full:true});
 expect(await timing(page)).toEqual(t);
});

test('D454 per-nozzle dynamics are off under Reduce Motion and on a hidden cockpit',async({page})=>{
 await open(page,{full:true,reduceMotion:true});
 expect((await timing(page)).map(x=>x.names)).toEqual(['none','none','none','none']);
 await open(page,{full:true,active:false});
 expect((await timing(page)).map(x=>x.names)).toEqual(['none','none','none','none']);
});
