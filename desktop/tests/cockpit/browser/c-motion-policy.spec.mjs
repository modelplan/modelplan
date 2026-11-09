// SPDX-License-Identifier: MIT
// Motion policy audit (MOT-2.3-01/02/03/04/08, CKP-MOT-03) on the built page through its normal bridge.
// Replaces the old blanket `*{animation:none;transition:none}` switch: every animation or transition that is
// live in the rendered cockpit must be on this list, and none may run under Reduce Motion or while hidden.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture,renderVisualDeck} from '../visual-fixture.mjs';

const ALLOWED_ANIMATIONS=new Set([
 'cockpit-caution-blink', // CKP-STRIP-06 new caution, 1 s x 10
 'strip-alert',           // the official strip's copy of the same lamp blink
 'cockpit-running-cursor', // CKP-STRIP-10 running-row cursor
 'cockpit-state-pulse',   // two finite lamp-dot pulses on a state change (no idle loop)
 'cockpit-porthole-flicker', // owner D39/D-H flame flicker; active, open and no Reduce Motion only
 'cockpit-mouth-shimmer', // CKP-ENG-19 base mouth light, working subscriptions only; same gates
]);
// Selector fragment -> transitioned properties allowed on it (interaction feedback and fader glide).
const ALLOWED_TRANSITIONS=[[/\bfd-cap\b/,['top']],[/\bfd-ghost\b/,['top','opacity']],[/\bfd-peek\b/,['opacity']],[/\bshutter-(blind|thumb)\b/,['width','transform']]];

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
 for(const name of ['Subscription','Effort','Breakdown']){await page.getByRole('button',{name,exact:true}).click();states.push(await motions(page));}
 for(const list of states)expect(disallowed(list)).toEqual([]);
 const names=new Set(states.flat().map(m=>m.animation));
 expect(names.has('cockpit-running-cursor')).toBe(true);
 expect([...names].some(n=>n.includes('cockpit-caution-blink')||n.includes('strip-alert'))).toBe(true);
 // The fader cap transition (the CSS half of CKP-FAD-12; real caps need the publication path) is not switched off.
 expect(await page.evaluate(()=>document.body.classList.contains('reduced'))).toBe(false);
 expect(states[0].some(m=>/\bfd-cap\b/.test(m.element)&&m.transitions.includes('top'))).toBe(true);
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

test('MOT-2.3-08 a hidden or closed cockpit runs no animation',async({page})=>{
 const fx=visualFixture(),account=fx.data.projection.rows[0].accounts[0];account.windows[0].remainingPercent=20;
 const {send,receive}=await open(page,fx.data);
 expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);
 expect((await motions(page)).filter(m=>m.animation!=='none')).toEqual([]);
 expect(await running(page)).toEqual([]);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 expect((await motions(page)).filter(m=>m.animation!=='none')).toEqual([]);
});

test('MOT-2.3-08 a hidden cockpit starts no transition and cancels any in flight (visible positive control)',async({page})=>{
 const {send,receive}=await open(page,visualFixture().data);
 const shutter=list=>list.filter(m=>m.kind==='CSSTransition'&&/shutter-(blind|thumb)/.test(m.element)).map(m=>m.name).sort();
 // Positive control: the same shell change on a shown page runs the shutter transitions.
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 expect(shutter(await running(page))).toEqual(['transform','width']);
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
