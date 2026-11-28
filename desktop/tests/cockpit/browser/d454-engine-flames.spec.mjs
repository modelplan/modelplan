// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D454 (owner 2026-11-26): the official bells hang the owner's blue flame set. D459 (owner 2026-11-26, amended): two
// layers per bell. The flame is the cockpit's own thrust, the same on every nozzle: docked = ember, the host igniting
// (launch burn after a detach, put-back flight, catch-zone approach) = full thrust, detached and parked = out (D468 replaces D459's short flame: a ~0.4 s fade, then nothing, no ember). The
// subscription's output is a soft glow in its own colour at the mouth, only while the cockpit is docked at rest (ember)
// and that subscription works; under a full flame or when out it is hidden. D450: nothing moves unless the page is active,
// open and not reduced.
test.use({deviceScaleFactor:2});
function data(){
 const d=visualFixture().data,vk={codex:'openai',claude:'claude',cursor:'cursor',gemini:null};
 for(const r of d.projection.rows)r.vendorKey=vk[r.id]??null;
 const ref=i=>d.projection.rows[i].accounts[0].subscriptionRef;
 // Two subscriptions with output (a fast one and a slow one: the rate no longer changes the flame), one idle.
 d.details.sessions[0]={...d.details.sessions[0],subscriptionRef:ref(0),rate:120};
 d.details.sessions[1]={...d.details.sessions[1],subscriptionRef:ref(1),rate:30};
 d.details.sessions[2]={...d.details.sessions[2],state:'idle'};
 return d;
}
async function open(page,{reduceMotion=false,active=true,attached=true}={}){
 await page.setViewportSize({width:636,height:1017});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell:{...shell,attached}}))).toBe(true);
 expect(await receive(send('visibility',{visible:active,occluded:!active,key:active}))).toBe(true);
 expect(await receive(send('display',{data:data()}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length===4);await page.waitForTimeout(200);
 return {
  shell:async value=>expect(await receive(send('shell',{...shell,...value}))).toBe(true),
  ignite:async on=>expect(await receive(send('ignition',{on}))).toBe(true),
  visibility:async on=>expect(await receive(send('visibility',{visible:on,occluded:!on,key:on}))).toBe(true),
  appearance:async value=>expect(await receive(send('appearance',{...appearance,...value}))).toBe(true),
 };
}
// Every nozzle (subscribed bells and empty sockets): its flame image, animation and the subscription glow.
const read=page=>page.evaluate(()=>({
 thrust:document.getElementById('cockpit').dataset.thrust,
 nozzles:[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty)')].map(b=>{const f=b.querySelector('.bz-flame'),s=b.querySelector('.bz-sheet');
  return {empty:b.classList.contains('bz-empty'),work:b.classList.contains('work'),
   flame:f?{image:getComputedStyle(f).backgroundImage,anim:getComputedStyle(f).animationName,w:f.getBoundingClientRect().width,z:Number(getComputedStyle(f).zIndex)}:null,
   glow:s?{shown:getComputedStyle(s).display!=='none'&&getComputedStyle(s,'::before').display!=='none',colour:getComputedStyle(s,'::before').backgroundImage,z:Number(getComputedStyle(s).zIndex)}:null};}),
}));
const kind=image=>/flame-full-strip/.test(image)?'full':/flame-short/.test(image)?'short':/flame-ember/.test(image)?'ember':'none';

test('D459 docked: ember on every nozzle, the working subscriptions glow in their own colour',async({page})=>{
 await open(page);
 const v=await read(page);
 expect(v.thrust).toBe('ember');
 expect(v.nozzles.length).toBeGreaterThanOrEqual(4);
 for(const n of v.nozzles){expect(n.flame).not.toBeNull();expect(kind(n.flame.image)).toBe('ember');expect(n.flame.anim).toBe('none');expect(n.flame.w).toBeGreaterThan(70);}
 const bells=v.nozzles.filter(n=>!n.empty);
 expect(bells.map(n=>n.work)).toEqual([true,true,false,false]);
 // Output is the glow, independent of the rate: both working bells glow, the idle ones have none.
 expect(bells.map(n=>n.glow?.shown??false)).toEqual([true,true,false,false]);
 expect(bells[0].glow.colour).not.toBe(bells[1].glow.colour);
 expect(bells[0].flame.z).toBeGreaterThan(bells[0].glow.z);
});

const gone=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty) .bz-flame')].every(f=>{const s=getComputedStyle(f);return s.visibility==='hidden'&&s.opacity==='0'&&f.getAnimations().length===0;}));

test('D459 launch, parked, landing: full while the host ignites, out when parked (D468), ember once docked; the glow only docked',async({page})=>{
 const host=await open(page);
 const state=async()=>{const v=await read(page);return {thrust:v.thrust,flames:[...new Set(v.nozzles.map(n=>kind(n.flame.image)))],glow:v.nozzles.filter(n=>n.glow?.shown).length};};
 // Launch: the host detaches and ignites the launch burn.
 await host.shell({attached:false});await host.ignite(true);
 expect(await state()).toEqual({thrust:'full',flames:['full'],glow:0});
 const v=await read(page);
 expect(v.nozzles.every(n=>n.flame.anim.startsWith('cockpit-flame-flip'))).toBe(true);
 // The burn ends: parked detached.
 await host.ignite(false);
 expect((await state()).thrust).toBe('out');
 // D468: the fade is visible on the built page: opacity strictly between 0 and 1, decreasing, while the full-thrust flicker is gone.
 const fade=await page.evaluate(()=>{const f=[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty) .bz-flame')];
  const at=t=>f.map(n=>{n.getAnimations().forEach(a=>{a.pause();a.currentTime=t;});return Number(getComputedStyle(n).opacity);});
  const r={names:f.map(n=>getComputedStyle(n).animationName),a:at(100),b:at(300)};f.forEach(n=>n.getAnimations().forEach(a=>a.finish()));return r;});
 expect(fade.names.every(n=>n==='cockpit-flame-out')).toBe(true);
 fade.a.forEach((v,i)=>{expect(v).toBeGreaterThan(0.1);expect(v).toBeLessThan(1);expect(fade.b[i]).toBeGreaterThan(0);expect(fade.b[i]).toBeLessThan(v);});
 // D468: the flame fades (0.4 s) and stays out: hidden, no ember, no glow, nothing animating, however long it stays parked.
 await expect.poll(()=>gone(page),{timeout:5000}).toBe(true);
 await page.waitForTimeout(2000);
 expect(await gone(page)).toBe(true);
 expect((await state()).glow).toBe(0);
 // Put back: the flight home burns full thrust, then the latch docks it.
 await host.ignite(true);
 expect(await state()).toEqual({thrust:'full',flames:['full'],glow:0});
 await host.shell({attached:true});await host.ignite(false);
 expect(await state()).toEqual({thrust:'ember',flames:['ember'],glow:2});
});

test('D450 the flipbook stops under Reduce Motion and on a hidden cockpit, holding one still frame',async({page})=>{
 let host=await open(page,{reduceMotion:true});
 await host.ignite(true);
 let v=await read(page);
 expect(v.nozzles.every(n=>kind(n.flame.image)==='full'&&n.flame.anim==='none')).toBe(true);
 host=await open(page,{active:false});
 await host.ignite(true);
 v=await read(page);
 expect(v.nozzles.every(n=>kind(n.flame.image)==='full'&&n.flame.anim==='none')).toBe(true);
});

// macrev2-1292-3: the fade runs once per full->out transition. After it has finished, nothing may bring the flame back.
async function parkedAfterFade(page){
 const host=await open(page);
 await host.shell({attached:false});await host.ignite(true);await host.ignite(false);
 await expect.poll(()=>gone(page),{timeout:5000}).toBe(true);
 await expect.poll(()=>page.evaluate(()=>document.getElementById('cockpit').dataset.fade)).toBe('false');
 return host;
}
test('D468 after the fade, hiding then showing the window keeps the flame out',async({page})=>{
 const host=await parkedAfterFade(page);
 await host.visibility(false);await host.visibility(true);await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
 expect(await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-flame')].map(f=>getComputedStyle(f).animationName))).toEqual(expect.not.arrayContaining(['cockpit-flame-out']));
});
test('D468 after the fade, Reduce Motion on then off keeps the flame out',async({page})=>{
 const host=await parkedAfterFade(page);
 await host.appearance({reduceMotion:true});await host.appearance({reduceMotion:false});await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
 await page.emulateMedia({reducedMotion:'reduce'});await page.emulateMedia({reducedMotion:'no-preference'});await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
});
test('D468 the burn ends under Reduce Motion, then motion returns: the flame stays out (no relight)',async({page})=>{
 const host=await open(page);
 await host.shell({attached:false});await host.ignite(true);
 await host.appearance({reduceMotion:true});
 await host.ignite(false);
 expect(await gone(page)).toBe(true);
 await host.appearance({reduceMotion:false});
 // Sampled at once: a relit flame would be running cockpit-flame-out here.
 expect((await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-flame')].map(f=>getComputedStyle(f).animationName+f.getAnimations().length))).every(x=>x==='none0')).toBe(true);
 await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
});
test('D468 the burn ends under OS reduced motion, then it returns: the flame stays out',async({page})=>{
 const host=await open(page);
 await host.shell({attached:false});await host.ignite(true);
 await page.emulateMedia({reducedMotion:'reduce'});
 await host.ignite(false);
 expect(await gone(page)).toBe(true);
 await page.emulateMedia({reducedMotion:'no-preference'});
 expect((await page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz-flame')].map(f=>getComputedStyle(f).animationName+f.getAnimations().length))).every(x=>x==='none0')).toBe(true);
 await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
});
test('D468 after the fade, a shell re-sync keeps the flame out',async({page})=>{
 const host=await parkedAfterFade(page);
 await host.shell({attached:false});await host.shell({attached:false,scope:'all'});await page.waitForTimeout(600);
 expect(await gone(page)).toBe(true);
 expect(await page.evaluate(()=>getComputedStyle(document.querySelector('.ck-base .bz-flame')).animationName)).toBe('none');
});

test('D468 under Reduce Motion the flame is out at once after the burn: no fade, no animation',async({page})=>{
 const host=await open(page,{reduceMotion:true});
 await host.shell({attached:false});await host.ignite(true);await host.ignite(false);
 expect((await read(page)).thrust).toBe('out');
 expect((await timing(page)).every(x=>x.names==='none')).toBe(true);
 expect(await gone(page)).toBe(true);
});

test('D468 a page opened detached has its flame out: no short flame, no ember, no glow',async({page})=>{
 await open(page,{attached:false});
 const v=await read(page);
 expect(v.thrust).toBe('out');
 expect(v.nozzles.every(n=>!n.glow?.shown&&n.flame.anim==='none')).toBe(true);
 expect(await gone(page)).toBe(true);
});

const timing=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base :is(.bz,.bz-empty) .bz-flame')].map(f=>{const s=getComputedStyle(f),p=f.parentElement.style;
 const ks=f.getAnimations().map(a=>a.effect.getKeyframes().map(k=>[k.scale,k.opacity].filter(Boolean).join('|')));
 return {names:s.animationName,dur:s.animationDuration,delay:s.animationDelay,ks,
  props:[...new Set(f.getAnimations().flatMap(a=>a.effect.getKeyframes().flatMap(k=>Object.keys(k))).filter(k=>!['offset','easing','composite','computedOffset'].includes(k)))].sort(),
  fp:p.getPropertyValue('--fp'),fb:p.getPropertyValue('--fb'),fl:p.getPropertyValue('--fl')};}));

test('D454 per-nozzle dynamics: full thrust gives each nozzle its own subtle timing, moving only background frame, scale and opacity',async({page})=>{
 const host=await open(page);await host.ignite(true);
 const t=await timing(page);
 expect(t.length).toBeGreaterThanOrEqual(4);
 for(const x of t)expect(x.names).toBe('cockpit-flame-flip, cockpit-flame-breathe, cockpit-flame-flicker');
 for(const k of ['dur','delay','fp','fb','fl'])expect(new Set(t.map(x=>x[k])).size,k).toBeGreaterThan(Math.min(t.length,4)-1);
 for(const x of t){
  const fps=4/parseFloat(x.fp);expect(fps).toBeGreaterThan(6.9);expect(fps).toBeLessThan(11.1);
  expect(parseFloat(x.fb)).toBeGreaterThanOrEqual(1.1);expect(parseFloat(x.fb)).toBeLessThanOrEqual(1.9);
  expect(x.props.filter(p=>!['backgroundPositionX','scale','opacity'].includes(p))).toEqual([]);
  // Amplitude from the keyframe definitions (not live values, which depend on the animation phase).
  expect(x.ks.flat()).toEqual(expect.arrayContaining(['1 0.9','1 1.1','1']));
 }
 if(process.env.FLAME_FRAMES){const r=await page.evaluate(()=>{const b=document.querySelector('.ck-base').getBoundingClientRect();return {y:b.top};});
  for(let i=0;i<30;i++){await page.evaluate(t=>document.getAnimations().forEach(a=>{a.pause();a.currentTime=t;}),i*100);
   await page.screenshot({path:process.env.FLAME_FRAMES+'/f'+String(i).padStart(2,'0')+'.png',clip:{x:0,y:Math.max(0,r.y-10),width:636,height:150}});}}
 // Deterministic: a reload gives the same per-nozzle timings.
 const host2=await open(page);await host2.ignite(true);
 expect(await timing(page)).toEqual(t);
});

test('D454/D468 ember and a parked (out) flame stay static; per-nozzle dynamics are off under Reduce Motion and when hidden',async({page})=>{
 let host=await open(page);
 expect((await timing(page)).every(x=>x.names==='none')).toBe(true);
 await host.shell({attached:false});
 expect((await timing(page)).every(x=>x.names==='none')).toBe(true);
 host=await open(page,{reduceMotion:true});await host.ignite(true);
 expect((await timing(page)).every(x=>x.names==='none')).toBe(true);
 host=await open(page,{active:false});await host.ignite(true);
 expect((await timing(page)).every(x=>x.names==='none')).toBe(true);
});
