// SPDX-License-Identifier: MIT
// Visual comparison evidence (owner D67): the real cockpit page at fixed states with the synthetic visual fixture,
// on a transparent background, plus the rects of its main blocks. CI uploads them with the WebKit test results
// (desktop/cockpit/.tmp/test-results/visual-capture/); the private comparison against the prototype reads them.
// Only the page's own rendering is written; no prototype or study image is in this repository.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';

const OUT=fileURLToPath(new URL('../../../cockpit/.tmp/test-results/visual-capture/',import.meta.url));
const SELECTORS=['.ck','.ck-shell','.ck-head','.ck-portrow','.ck-port','.ck-eng','.eng-keys','.ck-deck','.ck-tape','.ck-base',
 '.ck-base .bz','.ck-base .bz-empty','.ck-base .bz-line','.eng-keys .ek','.eng-keys .ek .bl','.ck-booster'];
// state: tier, profile, theme, viewport height (636 wide; the tall root is 905 plus the 34 px base row).
const STATES={'cockpit-tall-night':['tall','open','night',939],'cockpit-short-night':['compact','open','night',689],
 'cockpit-closed-night':['tall','closed','night',725]};

for(const [name,[tier,profile,theme,height]] of Object.entries(STATES))
test(`visual capture ${name}`,async({page})=>{
 await page.setViewportSize({width:636,height});await page.emulateMedia({reducedMotion:'reduce'});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),fixture=visualFixture();
 expect(await receive(send('load',{appearance:{...appearance,theme,reduceMotion:true},shell:{...shell,tier,profile}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fixture.data}))).toBe(true);
 await renderVisualDeck(page,fixture,'en');
 await page.waitForTimeout(600);
 await mkdir(OUT,{recursive:true});
 await page.screenshot({path:OUT+name+'.png',omitBackground:true,animations:'disabled'});
 const rects=await page.evaluate(selectors=>{
  const out={};
  for(const s of selectors){const found=[...document.querySelectorAll(s)].filter(e=>e.getClientRects().length);
   if(found.length)out[s]=found.slice(0,8).map(e=>{const r=e.getBoundingClientRect();return [Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height),e.className.toString().slice(0,80)];});}
  out.__meta={tabs:[...document.querySelectorAll('.eng-keys .ek')].map(e=>{const b=e.querySelector('.bl');return {text:e.innerText.trim().replace(/\s+/g,' ').slice(0,40),v:(b?b.style.getPropertyValue('--v')||getComputedStyle(b).getPropertyValue('--v'):'').trim()};}),
   bells:[...document.querySelectorAll('.ck-base .bz')].map(e=>e.className)};
  return out;
 },SELECTORS);
 expect(rects['.ck'],'the cockpit root is drawn').toBeTruthy();
 await writeFile(OUT+name+'.json',JSON.stringify({state:name,viewport:[636,height],rects},null,1));
});
