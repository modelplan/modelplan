// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

// D377 (owner 2026-11-21, option A): every plugin column (Calendar, Resources) hangs the same rocket nozzle under
// the hull as a subscription column: same art, same width rule (column x 0.7 clamped 81-101 px), 10 px high. A plugin
// nozzle is dark at rest (the working light belongs to subscriptions) and lights with the whole row on landing.
async function open(page,{tier='tall',reduceMotion=true}={}){
 await page.setViewportSize({width:636,height:tier==='tall'?951:681});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 const data=visualFixture().data;
 data.details.sessions[0]={...data.details.sessions[0],subscriptionRef:data.projection.rows[0].accounts[0].subscriptionRef,rate:120};
 expect(await receive(send('load',{appearance:{...appearance,reduceMotion},shell:{...shell,tier}}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:{version:1,entries:[],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.waitForFunction(()=>document.querySelectorAll('.ck-base .bz').length>0&&document.querySelectorAll('.eng-cols .pl-col').length>0);
 return {send,receive};
}
const read=page=>page.evaluate(()=>{
 const cols=[...document.querySelectorAll('.eng-cols > .ec')].map(c=>{const r=c.getBoundingClientRect();return {x:r.left+r.width/2,w:r.width,plugin:c.dataset.plugin??null};});
 const bells=[...document.querySelectorAll('.ck-base .bz')].map(b=>{const l=b.querySelector('.bz-line'),r=l.getBoundingClientRect();
  return {cls:b.className,label:b.getAttribute('aria-label'),x:r.left+r.width/2,w:r.width,h:r.height,image:getComputedStyle(l).backgroundImage,sheet:!!b.querySelector('.bz-sheet'),
   after:getComputedStyle(b,'::after').opacity};});
 return {cols,bells,plugins:document.querySelectorAll('.eng-cols .pl-col').length};
});

for(const tier of ['tall'])test(`D377 ${tier}: one nozzle per column, plugin columns included, same size and art`,async({page})=>{
 await open(page,{tier});const v=await read(page);
 expect(v.plugins).toBeGreaterThanOrEqual(1);
 expect(v.bells.length).toBe(v.cols.length);
 for(const [i,b] of v.bells.entries()){
  expect(Math.abs(b.x-v.cols[i].x)).toBeLessThan(0.6);
  expect(b.w).toBeCloseTo(Math.min(101,Math.max(81,v.cols[i].w*.7)),0);expect(b.h).toBeCloseTo(10,1);
  expect(b.image).toContain('assets/bells/bell-silver-2x.png');
 }
 const plugin=v.bells.filter((_,i)=>v.cols[i].plugin);
 expect(plugin.length).toBe(v.plugins);
 expect(plugin.every(b=>/\bplugin\b/.test(b.cls)&&!b.sheet&&!/\b(work|stale)\b/.test(b.cls))).toBe(true);
 expect(plugin.every(b=>/^Plugin · /.test(b.label))).toBe(true);
});

test('D377 a plugin nozzle stays dark at rest and lights with the whole row on landing',async({page})=>{
 await open(page);
 expect((await read(page)).bells.every(b=>Number(b.after)===0)).toBe(true);
 await page.evaluate(()=>{document.getElementById('cockpit').dataset.ignite='true';});
 await expect.poll(async()=>(await read(page)).bells.every(b=>Number(b.after)>0.5)).toBe(true);
 await page.evaluate(()=>{delete document.getElementById('cockpit').dataset.ignite;});
 await expect.poll(async()=>(await read(page)).bells.every(b=>Number(b.after)===0)).toBe(true);
});

// Evidence for the owner (D377): the hull bottom with the nozzle row, at rest and igniting, written beside the
// visual-capture shots (desktop/cockpit/.tmp/test-results/visual-capture/).
import {mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const OUT=fileURLToPath(new URL('../../../cockpit/.tmp/test-results/visual-capture/',import.meta.url));
for(const tier of ['tall'])test(`D377 capture ${tier}: hull bottom at rest and igniting`,async({page})=>{
 await open(page,{tier});await mkdir(OUT,{recursive:true});
 const height=951,clip={x:0,y:height-120,width:636,height:120};
 await page.screenshot({path:`${OUT}d377-nozzles-${tier}-rest.png`,clip,animations:'disabled'});
 await page.evaluate(()=>{document.getElementById('cockpit').dataset.ignite='true';});
 await page.waitForTimeout(400);
 await page.screenshot({path:`${OUT}d377-nozzles-${tier}-ignite.png`,clip,animations:'disabled'});
});
