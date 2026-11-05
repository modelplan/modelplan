// SPDX-License-Identifier: MIT
// spec-cockpit.md C-04 (was S4): "Tall, compact and constrained displays | Open or
// force a closed profile | Silhouette fits and shutter/forced state is clear
// without clipped controls". T1 (specs/scenario-tests.tsv) marks this ABSENT.
// Failing-first: assertions that do not hold on the candidate head are expected
// failures recording the gap, not flakes. On the captured head the constrained
// heights clip controls (3 buttons at 520 pt compact, open and even forced
// closed), which is exactly the gap this scenario describes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const open=async(page,height,tier,profile='open',forcedClosed=false)=>{
 await page.setViewportSize({width:636,height});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier,profile,forcedClosed},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 return {send,receive};
};
const fit=page=>page.evaluate(()=>{
 const cockpit=document.querySelector('#cockpit').getBoundingClientRect();
 const clipped=[...document.querySelectorAll('#cockpit button')].filter(b=>{const r=b.getBoundingClientRect();return r.width>0&&(r.bottom>cockpit.bottom+1||r.right>cockpit.right+1||r.top<cockpit.top-1);}).map(b=>(b.getAttribute('aria-label')??b.textContent.trim()).slice(0,20));
 return {layout:document.querySelector('#cockpit').getAttribute('data-layout'),shell:document.querySelector('#cockpit').getAttribute('data-shell'),cockpitHeight:Math.round(cockpit.height),viewportHeight:window.innerHeight,clipped,
  reason:document.querySelector('#s6-closed-reason')?.textContent??null,
  shutterDisabled:document.querySelector('[data-shutter]')?.disabled??null};
});

test('C-04: the tall profile fits an 890 pt display without clipping',async({page})=>{
 await open(page,890,'tall');
 const state=await fit(page);
 expect(state.layout,'C-04: tall layout').toBe('890');
 expect(state.clipped,'C-04: no clipped controls: '+JSON.stringify(state.clipped)).toEqual([]);
 expect(state.cockpitHeight,'C-04: silhouette fits').toBeLessThanOrEqual(state.viewportHeight);
});

test('C-04: the compact profile fits a 640 pt display without clipping',async({page})=>{
 await open(page,640,'compact');
 const state=await fit(page);
 expect(state.layout,'C-04: compact layout').toBe('640');
 expect(state.clipped,'C-04: no clipped controls: '+JSON.stringify(state.clipped)).toEqual([]);
 expect(state.cockpitHeight,'C-04: silhouette fits').toBeLessThanOrEqual(state.viewportHeight);
});

test('C-04: a constrained 520 pt display keeps every control unclipped',async({page})=>{
 await open(page,520,'compact');
 const state=await fit(page);
 expect(state.clipped,'C-04: constrained display must not clip controls; clipped: '+JSON.stringify(state.clipped)).toEqual([]);
});

test('C-04: the forced-closed profile states its reason and leaves nothing clipped',async({page})=>{
 const {receive,send}=await open(page,520,'compact');
 expect(await receive(send('shell',{...shell,tier:'compact',profile:'closed',forcedClosed:true})),'C-04: forced close accepted').toBe(true);
 const state=await fit(page);
 expect(state.shell,'C-04: forced-closed state is clear').toBe('closed');
 expect(state.reason,'C-04: the forced state explains itself').toContain('Not enough window height');
 expect(state.shutterDisabled,'C-04: the shutter is disabled while forced closed').toBe(true);
 expect(state.clipped,'C-04: forced-closed still must not clip controls; clipped: '+JSON.stringify(state.clipped)).toEqual([]);
});
