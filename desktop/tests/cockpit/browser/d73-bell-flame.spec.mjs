// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// Owner D73 (2026-11-08): a working subscription also gets a flame from its bell, on top of the mouth glow. The
// reference is the study's task 66 plume (bells.css @ 9f881788) at about half its height and faint (owner 10-26:
// "一半都够了 ... 隐约有一点就好了"): it starts 3.5 px into the mouth, spans the inner mouth (bell width x 0.9033),
// is min((34 - 3.5) / 2, len x 0.8) px long, is masked by the released mouth-plume-mask.png, and is coloured by the
// subscription's quota state (--fuel) like the glow. It steps with the study's timing (--fd, steps(1,end),
// alternate), is still under Reduce Motion, and stops while hidden or with the shutter closed. Idle bells and
// empty slots have no flame.
async function open(page,{reduceMotion=false}={}){
 await page.setViewportSize({width:636,height:911});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=visualFixture().data;
 data.details.sessions[0]={...data.details.sessions[0],subscriptionRef:data.projection.rows[0].accounts[0].subscriptionRef,rate:120};
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell:{...shell,tier:'tall'}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0);
 return {send,receive};
}
const read=page=>page.evaluate(()=>[...document.querySelectorAll('.ck-base .bz,.ck-base .bz-empty')].map(b=>{
 const l=b.querySelector('.bz-line').getBoundingClientRect(),p=b.querySelector('.bz-plume');
 if(!p)return {cls:b.className,plume:null};
 const s=getComputedStyle(p),before=getComputedStyle(p,'::before'),r=p.getBoundingClientRect(),a=p.getAnimations()[0]?.effect?.getTiming();
 return {cls:b.className,bell:{top:l.top,w:l.width},fd:b.style.getPropertyValue('--fd'),fuel:getComputedStyle(b).getPropertyValue('--fuel').trim(),
  plume:{top:r.top,h:p.offsetHeight,w:p.offsetWidth,display:s.display,opacity:Number(s.opacity),mask:before.maskImage||before.webkitMaskImage,paint:before.backgroundImage,
   anim:s.animationName,timing:s.animationTimingFunction,direction:s.animationDirection,iterations:s.animationIterationCount,duration:s.animationDuration,live:a?1:0}};
}));

test('D73 a working bell has a faint half-height flame on top of its mouth glow; idle and empty bells have none',async({page})=>{
 await open(page);const bells=await read(page);
 const work=bells.filter(b=>b.cls.includes('work')),rest=bells.filter(b=>!b.cls.includes('work'));
 expect(work.length).toBe(1);expect(rest.length).toBeGreaterThan(1);
 expect(rest.every(b=>b.plume===null)).toBe(true);
 const {bell,plume,fd}=work[0];
 expect(plume.display).toBe('block');
 expect(plume.top-bell.top).toBeCloseTo(3.5,0);
 expect(plume.w).toBeCloseTo(bell.w*.9033,0);
 // 120 t/s -> len 24: half of the study's min(30.5, 38.4) = 15.25.
 expect(plume.h).toBeCloseTo((34-3.5)/2,0);
 expect(plume.mask).toContain('assets/bells/mouth-plume-mask.png');
 expect(plume.paint).toMatch(/gradient/);
 expect(work[0].fuel).not.toBe('');
 expect(plume.anim).toBe('cockpit-bell-plume');
 // steps(1,end): WebKit serializes it as steps(1).
 expect(plume.timing).toMatch(/^steps\(1(, end)?\)$/);expect([plume.direction,plume.iterations]).toEqual(['alternate','infinite']);
 expect(parseFloat(plume.duration)).toBeCloseTo(parseFloat(fd),3);
});

test('D73 the flame is still under Reduce Motion and stops while hidden or with the shutter closed',async({page})=>{
 const {send,receive}=await open(page,{reduceMotion:true});
 const still=(await read(page)).find(b=>b.cls.includes('work')).plume;
 expect(still.anim).toBe('none');expect(still.display).toBe('block');expect(still.opacity).toBeGreaterThan(0);
 expect(await receive(send('appearance',{...appearance,reduceMotion:false}))).toBe(true);
 const anim=async()=>(await read(page)).find(b=>b.cls.includes('work'))?.plume?.anim??'none';
 await expect.poll(anim).toBe('cockpit-bell-plume');
 await page.emulateMedia({reducedMotion:'reduce'});await expect.poll(anim).toBe('none');
 await page.emulateMedia({reducedMotion:'no-preference'});await expect.poll(anim).toBe('cockpit-bell-plume');
 expect(await receive(send('visibility',{visible:false,occluded:true,key:false}))).toBe(true);
 await expect.poll(anim).toBe('none');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await expect.poll(anim).toBe('cockpit-bell-plume');
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 await expect.poll(anim).toBe('none');
});
