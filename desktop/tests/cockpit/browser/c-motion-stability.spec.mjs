// SPDX-License-Identifier: MIT
// Motion rules on the built page through its normal bridge (MOT-2.3-09, MOT-2.3-13). The rendered page is the
// read-only seam. Sizes are read after the state settles; a state or theme change must leave the frame where it was.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture,renderVisualDeck} from '../visual-fixture.mjs';

const FRAME=['.ck-portrow','.ck-head','.ck-eng','.eng-keys','.eng-lcd','.ck-deck','.dk-fad','.dk-mfd','.mfd-screen','.ck-tape'];
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
const frame=page=>page.evaluate(selectors=>Object.fromEntries(selectors.map(s=>{const r=document.querySelector(s)?.getBoundingClientRect();return [s,r?[r.x,r.y,r.width,r.height]:null];})),FRAME);
const columns=page=>page.locator('.qcell').evaluateAll(list=>list.map(e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height];}));
const fixtureAt=remaining=>{const fx=visualFixture();for(const row of fx.data.projection.rows)row.accounts[0].windows[0].remainingPercent=remaining;return fx;};

test('MOT-2.3-09 state, input and appearance changes leave the frame and readings in place',async({page})=>{
 const fx=fixtureAt(75),{send,receive}=await open(page,fx.data);
 const base=await frame(page),cells=await columns(page);
 for(const [selector,rect] of Object.entries(base))expect(rect,selector).not.toBeNull();
 const held=async label=>{expect(await frame(page),label).toEqual(base);expect(await columns(page),label).toEqual(cells);};
 // A quota crossing every status lights the lamp and tints columns; no reading may move or resize for it.
 for(const remaining of [40,20,0,75]){expect(await receive(send('display',{data:fixtureAt(remaining).data}))).toBe(true);await held(`remaining ${remaining}`);}
 await page.locator('.qcell').first().hover();await held('hover on a reading');
 await page.locator('.eng-keys button').nth(1).hover();await held('hover on a key');
 await page.mouse.move(2,2);
 await page.keyboard.down('Alt');await held('help map down');await page.keyboard.up('Alt');await held('help map up');
 for(const name of ['Subscription','Models','Breakdown','Overview']){await page.getByRole('button',{name,exact:true}).click();await held(`page ${name}`);}
 for(const change of [{reduceMotion:true},{reduceTransparency:true},{theme:'day'},{locale:'zh-CN'}]){
  expect(await receive(send('appearance',{...appearance,...change}))).toBe(true);await held(JSON.stringify(change));
  expect(await receive(send('appearance',appearance))).toBe(true);await held('appearance restored');
 }
});

test('MOT-2.3-13 cockpit leg: no spring, bounce or liquid timing',async({page})=>{
 const fx=visualFixture();await open(page,fx.data);await renderVisualDeck(page,fx,'en');
 const timing=await page.evaluate(()=>{const found=[],walk=rules=>{for(const r of rules){if(r.cssRules)walk(r.cssRules);if(r.type===CSSRule.KEYFRAMES_RULE)found.push(...[...r.cssRules].map(k=>'keyframe '+r.name+' '+k.style.getPropertyValue('animation-timing-function')));
   if(r.style)for(const n of ['transition','transition-timing-function','animation','animation-timing-function']){const v=r.style.getPropertyValue(n);if(v)found.push(r.selectorText+' '+v);}}};
  for(const sheet of document.styleSheets)walk(sheet.cssRules);
  for(const e of document.querySelectorAll('#cockpit, #cockpit *')){const s=getComputedStyle(e);found.push('live '+s.transitionTimingFunction+' '+s.animationTimingFunction);}
  return found;});
 expect(timing.length).toBeGreaterThan(20);
 expect(timing.filter(t=>t.includes('cubic-bezier')).length).toBeGreaterThan(0);
 const overshoot=timing.filter(t=>[...t.matchAll(/cubic-bezier\(([^)]*)\)/g)].some(m=>{const [,y1,,y2]=m[1].split(',').map(Number);return y1<0||y1>1||y2<0||y2>1;}));
 expect(overshoot).toEqual([]);
 expect(timing.filter(t=>/\bspring\b|\bbounce\b|\blinear\(/.test(t))).toEqual([]);
});
