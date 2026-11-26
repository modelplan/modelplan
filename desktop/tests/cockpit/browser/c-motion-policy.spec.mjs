// SPDX-License-Identifier: MIT
// Motion policy audit (MOT-2.3-01/02/03/04/08, CKP-MOT-03) on the built page through its normal bridge.
// Every live animation or transition must be on this list. Reduce Motion and hidden windows stop the motion.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture,renderVisualDeck} from '../visual-fixture.mjs';

const ALLOWED_ANIMATIONS=new Set([
 'cockpit-caution-blink', // CKP-STRIP-06 new caution, 1 s x 3
 'strip-alert',           // the official strip's copy of the same lamp blink
 'cockpit-running-cursor', // CKP-STRIP-10 running-row cursor
 'cockpit-state-pulse',   // two finite lamp-dot pulses on a state change (no idle loop)
 'cockpit-porthole-flicker', // owner D39/D-H flame flicker; active, open and no Reduce Motion only
 'cockpit-light-breathe', // CKP-ENG-19 (D294) base working light, working subscriptions only; same gates
 'cockpit-bell-flare',    // CKP-SHELL-33 (D294) landing burn thrown out of the mouth, only while the host ignites
 'cockpit-bell-burn',     // the burn's stepped flutter, same gate
 'cockpit-flame-flip',    // D454/D459 official blue thrust flipbook, full thrust only; same gates
]);
// Selector fragment -> transitioned properties allowed on it (interaction feedback and fader glide).
// D405 (#1229): the lever and ghost glide along the tilted slot line; their row is mirrored in --fd-kx for the x half of the glide.
const ALLOWED_TRANSITIONS=[[/\bfd-cap\b/,['top','--fd-frame','--fd-kx']],[/\bfd-ghost\b/,['top','opacity','--fd-kx']],[/\bfd-peek\b/,['opacity']],// WP-10: the porthole switch's two art layers and the date keys cross-fade in 120 ms (spec R3, section 6 and 7).
 [/\bshutter-slider\b/,['opacity']],[/\brk\b/,['color']],[/\brk-cap\b/,['opacity']],
 // CKP-SHELL-33 (D178/D186): the launch-rack ignition glow fades on the base bells (120 ms in, 220 ms out); off under Reduce Motion.
 // D294: the burn's plume also retracts by transform; the working light yields by opacity.
 [/\bbz(-empty)?\b/,['opacity','transform']],[/\bbz-sheet\b/,['opacity']]];

async function open(page,data) {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const motions=page=>page.evaluate(()=>{const out=[];for(const e of document.querySelectorAll('#cockpit, #cockpit *'))for(const pseudo of [null,'::before','::after']){
 const s=getComputedStyle(e,pseudo),name=typeof e.className==='string'?e.className:'';
 const props=s.transitionProperty.split(',').map(x=>x.trim()),durations=s.transitionDuration.split(',').map(x=>parseFloat(x));
 const live=props.filter((p,i)=>(durations[i]??durations[0])>0);
 if(live.length||s.animationName!=='none')out.push({element:e.tagName.toLowerCase()+(name?'.'+name.trim().split(/\s+/).join('.'):''),pseudo,animation:s.animationName,transitions:live});}
 return out;});
function disallowed(list){
 return list.filter(m=>(m.animation!=='none'&&!m.animation.split(',').every(n=>ALLOWED_ANIMATIONS.has(n.trim())))||
  m.transitions.some(p=>!ALLOWED_TRANSITIONS.some(([re,ok])=>re.test(m.element)&&ok.includes(p))));
}

test('MOT-2.3-01 only the allowed cockpit motions are live, and they run while the cockpit is shown',async({page})=>{
 const fx=visualFixture(),account=fx.data.projection.rows[0].accounts[0];account.windows[0].remainingPercent=20;
 await open(page,fx.data);await renderVisualDeck(page,fx,'en');
 const lamp=page.locator('[data-caution]');await expect(lamp).toHaveClass(/\bflash\b/);
 const states=[];states.push(await motions(page));
 await page.keyboard.down('Alt');states.push(await motions(page));await page.keyboard.up('Alt');
 for(const name of ['Plans','Models','Breakdown']){await page.getByRole('button',{name,exact:true}).click();states.push(await motions(page));}
 for(const list of states)expect(disallowed(list)).toEqual([]);
 const names=new Set(states.flat().map(m=>m.animation));
 expect(names.has('cockpit-running-cursor')).toBe(true);
 expect([...names].some(n=>n.includes('cockpit-caution-blink')||n.includes('strip-alert'))).toBe(true);
 // The fader cap transition (the CSS half of CKP-FAD-12; real caps need the publication path) is not switched off.
 expect(await page.evaluate(()=>document.body.classList.contains('reduced'))).toBe(false);
 expect(states[0].some(m=>/\bfd-cap\b/.test(m.element)&&(m.transitions.includes('top')||m.transitions.includes('--fd-frame')))).toBe(true);
});

for(const how of ['app setting','system setting'])test(`CKP-MOT-03 Reduce Motion (${how}) stops every cockpit animation`,async({page})=>{
 const fx=visualFixture(),account=fx.data.projection.rows[0].accounts[0];account.windows[0].remainingPercent=20;
 // The OS preference is in place when the cockpit opens; the app setting arrives over the bridge.
 if(how==='system setting')await page.emulateMedia({reducedMotion:'reduce'});
 const {send,receive}=await open(page,fx.data);
 if(how==='app setting')expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);
 await renderVisualDeck(page,fx,'en');
 expect(await page.evaluate(()=>document.body.classList.contains('reduced'))).toBe(true);
 const list=await motions(page);
 expect(list.filter(m=>m.animation!=='none')).toEqual([]);
 // Instant or a short fade only: no glide or position transition remains.
 expect(list.filter(m=>m.transitions.some(p=>p!=='opacity'))).toEqual([]);
 expect(disallowed(list)).toEqual([]);
});

// Effects really running on the page, including CSS transitions a computed-style scan cannot see.
const running=page=>page.evaluate(()=>document.getElementById('cockpit').getAnimations({subtree:true}).map(a=>({
 kind:a.constructor.name,name:a.transitionProperty??a.animationName,element:typeof a.effect.target?.className==='string'?a.effect.target.className:'',state:a.playState})));

test('inactive cockpit schedules no animation frames or fast timers',async({page})=>{
 await page.addInitScript(()=>{
  const calls={frameRequests:0,frameCallbacks:0,fastTimers:0,fastCallbacks:0};window.idleEnergyCalls=calls;
  const raf=window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame=(callback)=>{
   calls.frameRequests++;return raf(time=>{calls.frameCallbacks++;callback(time);});
  };
  for(const name of ['setTimeout','setInterval']){
   const timer=window[name].bind(window);
   window[name]=(callback,delay,...args)=>{
    if(!(Number(delay??0)<1000)||typeof callback!=='function')return timer(callback,delay,...args);
    calls.fastTimers++;
    return timer((...values)=>{calls.fastCallbacks++;callback(...values);},delay,...args);
   };
  }
 });
 const {data}=visualFixture();
 data.details=null;data.projection.rows=data.projection.rows.slice(0,1);
 const windows=data.projection.rows[0].accounts[0].windows;
 for(const w of windows)w.remainingPercent=75;
 const {send,receive}=await open(page,data);
 windows[0].remainingPercent=0;
 expect(await receive(send('display',{data}))).toBe(true);
 windows[1].remainingPercent=10;
 expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Plans',exact:true}).click();
 await page.locator('[data-caution]').click();
 const flash=await page.evaluate(message=>{
  const row=document.querySelector('.pg-alerts .mfd-alerts li.al-flash');
  const before=row&&getComputedStyle(row).animationName;
  const accepted=window.modelPlanCockpit.receive(message);
  const after=row&&getComputedStyle(row).animationName;
  return {before,accepted,after};
 },send('visibility',{visible:true,occluded:true,key:false}));
 expect(flash).toEqual({before:'cockpit-alert-row-flash',accepted:true,after:'none'});
 expect(await running(page)).toEqual([]);
 const before=await page.evaluate(()=>({...window.idleEnergyCalls}));
 await page.waitForTimeout(1100);
 expect(await page.evaluate(()=>window.idleEnergyCalls)).toEqual(before);
 expect(await running(page)).toEqual([]);
});

test('MOT-2.3-08 a hidden or closed cockpit runs no animation',async({page})=>{
 const fx=visualFixture(),account=fx.data.projection.rows[0].accounts[0];account.windows[0].remainingPercent=20;
 const {send,receive}=await open(page,fx.data);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 expect((await motions(page)).filter(m=>m.animation!=='none')).toEqual([]);
 expect(await running(page)).toEqual([]);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 // CKP-PORT-09 (amended G3-108, 250 ms): the porthole's own one-shot close runs first. Its end settles the closed
 // shell by itself: the test runs that one motion to its end and checks the shell within the same task, so no
 // rendering update (whose cadence a loaded headless runner does not keep, macrev2-923-1) can be what settles it.
 // g3-108-shutter-motion.spec.mjs covers the same close running out on real frames.
 const settled=await page.evaluate(async()=>{
  const c=document.getElementById('cockpit'),runs=document.querySelector('.ck-portrow').getAnimations().filter(a=>a.animationName==='cockpit-shutter');
  const during={shell:c.dataset.shell,motion:c.dataset.shutterMotion,runs:runs.length};
  for(const a of runs)a.finish();
  await Promise.all(runs.map(a=>a.finished));await null;
  return {during,after:{shell:c.dataset.shell,motion:c.dataset.shutterMotion??null}};
 });
 expect(settled.during,'the porthole closes as its own motion').toEqual({shell:'closing',motion:'closing',runs:1});
 expect(settled.after,'the end of that motion closes the shell').toEqual({shell:'closed',motion:null});
 // MOT-2.3-08: closed, nothing runs.
 expect((await motions(page)).filter(m=>m.animation!=='none')).toEqual([]);
 expect((await running(page)).filter(m=>m.kind==='CSSAnimation')).toEqual([]);
});

test('MOT-2.3-08 a hidden cockpit starts no transition and cancels any in flight (visible positive control)',async({page})=>{
 const {send,receive}=await open(page,visualFixture().data);
 const shutter=list=>list.filter(m=>m.kind==='CSSTransition'&&/shutter-slider/.test(m.element)).map(m=>m.name).sort();
 // Positive control: the same shell change on a shown page runs the shutter transitions.
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 expect(shutter(await running(page))).toEqual(['opacity','opacity']);
 // Hiding mid-flight cancels them at once.
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 expect(await running(page)).toEqual([]);
 // Shell and data changes while hidden start nothing; the state still lands.
 expect(await receive(send('shell',{...shell,profile:'open'}))).toBe(true);
 expect(await running(page)).toEqual([]);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 expect(await running(page)).toEqual([]);
 expect(await page.locator('#cockpit').getAttribute('data-shell')).toBe('open');
});

test('MOT-2.3-08 the landing burn runs only on a shown cockpit: ignition while hidden starts no animation',async({page})=>{
 const {send,receive}=await open(page,visualFixture().data);
 const burn=async()=>(await running(page)).filter(m=>m.kind==='CSSAnimation'&&/cockpit-bell-(flare|burn)/.test(m.name));
 // Positive control: ignition on a shown cockpit runs the burn.
 expect(await receive(send('ignition',{on:true}))).toBe(true);
 expect((await burn()).length).toBeGreaterThan(0);
 expect(await receive(send('ignition',{on:false}))).toBe(true);
 // Hidden: the host may still ignite, but nothing runs, and nothing starts when the ignition flips while hidden.
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 expect(await receive(send('ignition',{on:true}))).toBe(true);
 expect(await page.locator('#cockpit').getAttribute('data-ignite')).toBe('true');
 expect(await burn()).toEqual([]);
 expect((await motions(page)).filter(m=>/cockpit-bell-(flare|burn)/.test(m.animation))).toEqual([]);
});

test('display pulse ends without a late lamp DOM mutation',async({page})=>{
 test.skip(process.env.COCKPIT_HEADED_MOTION!=='1','Natural WebKit animation events require headed rendering.');
 const fx=visualFixture(),{send,receive}=await open(page,fx.data);
 fx.data.projection.rows[0].accounts[0].windows[0].remainingPercent=19;
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 const result=await page.locator('.activity').evaluate(el=>new Promise((resolve,reject)=>{
  const changes=[];const observer=new MutationObserver(records=>changes.push(...records));observer.observe(el,{attributes:true,attributeOldValue:true});
  const timer=setTimeout(()=>reject(new Error('pulse did not finish')),5000);
  el.addEventListener('animationend',event=>{if(event.animationName!=='cockpit-state-pulse')return;clearTimeout(timer);setTimeout(()=>{changes.push(...observer.takeRecords());observer.disconnect();resolve(changes.map(r=>({name:r.attributeName,old:r.oldValue})));},0);},{once:true});
 }));
 expect(result).toEqual([]);
});

test('system Reduce Motion does not replay a completed display pulse',async({page})=>{
 test.skip(process.env.COCKPIT_HEADED_MOTION!=='1','Natural WebKit animation events require headed rendering.');
 const fx=visualFixture(),{send,receive}=await open(page,fx.data);
 await page.evaluate(()=>{window.__pulseStarts=0;document.querySelector('.activity').addEventListener('animationstart',e=>{if(e.animationName==='cockpit-state-pulse')window.__pulseStarts++;});});
 fx.data.projection.rows[0].accounts[0].windows[0].remainingPercent=19;
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 await page.locator('.activity').evaluate(el=>new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('pulse did not finish')),5000);el.addEventListener('animationend',e=>{if(e.animationName==='cockpit-state-pulse'){clearTimeout(timer);resolve();}},{once:true});}));
 expect(await page.evaluate(()=>window.__pulseStarts)).toBe(1);
 await page.emulateMedia({reducedMotion:'reduce'});await page.waitForFunction(()=>matchMedia('(prefers-reduced-motion: reduce)').matches);
 await page.emulateMedia({reducedMotion:'no-preference'});await page.waitForFunction(()=>!matchMedia('(prefers-reduced-motion: reduce)').matches);
 await page.waitForTimeout(200);expect(await page.evaluate(()=>window.__pulseStarts)).toBe(1);
 fx.data.projection.rows[0].accounts[0].windows[0].remainingPercent=18;
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 await expect.poll(()=>page.evaluate(()=>window.__pulseStarts)).toBe(2);
});


test('system Reduce Motion clears the display pulse before motion resumes',async({page})=>{
 await page.addInitScript(()=>{const original=window.matchMedia.bind(window);window.__motionQueries=[];window.matchMedia=query=>{const result=original(query);if(query==='(prefers-reduced-motion: reduce)')window.__motionQueries.push(result);return result;};});
 const fx=visualFixture(),{send,receive}=await open(page,fx.data);
 fx.data.projection.rows[0].accounts[0].windows[0].remainingPercent=19;
 expect(await receive(send('display',{data:fx.data}))).toBe(true);
 const lamp=page.locator('.activity');await expect(lamp).toHaveClass(/state-pulse/);
 await page.emulateMedia({reducedMotion:'reduce'});await page.evaluate(()=>window.__motionQueries.forEach(q=>{Object.defineProperty(q,'matches',{configurable:true,value:true});q.dispatchEvent(new Event('change'));}));await expect(lamp).not.toHaveClass(/state-pulse/);
 await page.emulateMedia({reducedMotion:'no-preference'});await expect(lamp).not.toHaveClass(/state-pulse/);
 fx.data.projection.rows[0].accounts[0].windows[0].remainingPercent=18;
 expect(await receive(send('display',{data:fx.data}))).toBe(true);await expect(lamp).toHaveClass(/state-pulse/);
});
