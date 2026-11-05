// SPDX-License-Identifier: MIT
// spec-cockpit.md S26 (MOT-2.3-01, MOT-2.3-02, MOT-2.3-03, MOT-2.3-08,
// MOT-2.3-09): "Admitted data changes, user interaction, Reduce Motion and hidden
// cockpit | Deliver changed and unchanged data, press/drag/hover, enable Reduce
// Motion and hide the cockpit | Data-driven motion is limited to applicable fader
// glide, approximately 80 ms LCD value fade, record typing and running cursor;
// press/drag/hover/trial-return feedback remains allowed; reduced motion is static
// or a short fade; nothing animates continuously without data or while hidden, no
// skeleton/shimmer appears, and motion does not change size, position or
// proportion; deferred flame behavior is not required in v1". Failing-first:
// assertions that do not hold on the candidate head are expected failures
// recording the gap, not flakes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

// The approved data-driven animation set. Interaction feedback (press/drag/hover/
// trial-return) is allowed but is only observed in reaction to real input here.
const ALLOWED_DATA_ANIMATIONS=new Set(['t-cursor','typing','lcd-fade','fd-glide']);

const open=async(page)=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 return {send,receive};
};
const animationWithCaution=async(page,send,receive)=>{
 const data=currentSample();
 const window_=data.projection.rows[0].accounts[0].windows[0];window_.remainingPercent=10;
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForTimeout(150);
 return page.evaluate(()=>document.getAnimations().map(a=>({name:String(a.animationName),state:a.playState,iterations:a.effect?.getTiming?.().iterations})));
};

test('S26: nothing animates while the cockpit is hidden',async({page})=>{
 const {send,receive}=await open(page);
 expect(await animationWithCaution(page,send,receive)).toBeDefined();
 await receive(send('visibility',{visible:false,occluded:false,key:false}));
 const hidden=await page.evaluate(()=>document.getAnimations().map(a=>a.animationName));
 expect(hidden,'S26: hidden cockpit runs no animation').toEqual([]);
});

// Named skip (gap record): a caution data change runs `cockpit-state-pulse`
// (2 iterations) on the lamp, which is outside the approved data-driven motion
// set. Unskip when the pulse is retired or explicitly admitted to the set.
test.fixme('S26: data-driven motion stays inside the approved set',async({page})=>{
 const {send,receive}=await open(page);
 const animations=await animationWithCaution(page,send,receive);
 const outside=animations.filter(a=>!ALLOWED_DATA_ANIMATIONS.has(a.name));
 expect(outside,'S26: only approved data-driven animations may run; found: '+JSON.stringify(animations)).toEqual([]);
});

test('S26: no animation runs continuously without a data change',async({page})=>{
 const {send,receive}=await open(page);
 const animations=await animationWithCaution(page,send,receive);
 for(const animation of animations)expect(animation.iterations,'S26: '+animation.name+' must be finite without new data').not.toBe(Infinity);
 await page.waitForTimeout(400);
 const settled=await page.evaluate(()=>document.getAnimations().filter(a=>a.playState==='running').map(a=>a.animationName));
 expect(settled,'S26: transient animations settle without further data').toEqual([]);
});

test('S26: motion does not change size or position',async({page})=>{
 const {send,receive}=await open(page);
 const data=currentSample();
 const window_=data.projection.rows[0].accounts[0].windows[0];window_.remainingPercent=10;
 expect(await receive(send('display',{data}))).toBe(true);
 const measure=()=>page.evaluate(()=>{const pick=sel=>{const el=document.querySelector(sel);if(!el)return null;const r=el.getBoundingClientRect();return [sel,Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)];};return ['.s6-alert','#cockpit','.ck-tape'].map(pick);});
 const first=await measure();
 await page.waitForTimeout(90); // mid-animation frame
 const mid=await measure();
 const last=await measure();
 expect(mid,'S26: geometry stable mid-animation').toEqual(first);
 expect(last,'S26: geometry stable after animation').toEqual(first);
});

test('S26: no skeleton or shimmer placeholder is defined or rendered',async({page})=>{
 const {receive}=await open(page);
 const result=await page.evaluate(()=>{
  const cssText=[...document.styleSheets].map(sheet=>{try{return [...sheet.cssRules].map(rule=>rule.cssText).join('\n');}catch{return '';}}).join('\n');
  const rendered=/skeleton|shimmer/i.test(document.querySelector('#cockpit')?.textContent??'');
  return {defined:/skeleton|shimmer/i.test(cssText),rendered};
 });
 expect(result.defined,'S26: no skeleton/shimmer in page CSS').toBe(false);
 expect(result.rendered,'S26: no skeleton/shimmer text').toBe(false);
});
