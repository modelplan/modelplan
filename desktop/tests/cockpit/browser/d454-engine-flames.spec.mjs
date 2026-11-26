// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D454 (owner 2026-11-26): the official bells hang the owner's blue flame set. D459 (owner 2026-11-26, amended): two
// layers per bell. The flame is the cockpit's own thrust, the same on every nozzle: docked = ember, the host igniting
// (launch burn after a detach, put-back flight, catch-zone approach) = full thrust, detached and parked = short. The
// subscription's output is a soft glow in its own colour at the mouth, only while the cockpit is docked at rest (ember)
// and that subscription works; under a short or full flame it is hidden. D450: nothing moves unless the page is active,
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

test('D459 launch, parked, landing: full while the host ignites, short when parked, ember once docked; the glow only docked',async({page})=>{
 const host=await open(page);
 const state=async()=>{const v=await read(page);return {thrust:v.thrust,flames:[...new Set(v.nozzles.map(n=>kind(n.flame.image)))],glow:v.nozzles.filter(n=>n.glow?.shown).length};};
 // Launch: the host detaches and ignites the launch burn.
 await host.shell({attached:false});await host.ignite(true);
 expect(await state()).toEqual({thrust:'full',flames:['full'],glow:0});
 const v=await read(page);
 expect(v.nozzles.every(n=>n.flame.anim==='cockpit-flame-flip')).toBe(true);
 // The burn ends: parked detached.
 await host.ignite(false);
 expect(await state()).toEqual({thrust:'short',flames:['short'],glow:0});
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

test('D459 a page opened detached starts on the short parked flame',async({page})=>{
 await open(page,{attached:false});
 const v=await read(page);
 expect(v.thrust).toBe('short');
 expect(v.nozzles.every(n=>kind(n.flame.image)==='short'&&!n.glow?.shown)).toBe(true);
});
