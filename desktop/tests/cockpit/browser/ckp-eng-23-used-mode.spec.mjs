// SPDX-License-Identifier: MIT
// CKP-ENG-23 / SET-9-10 (C04, D130): the engine table follows the Settings remaining / used choice, text and bars, with
// colours keyed to what is remaining. Built page, normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,loadExtra={}) {
 const {data}=visualFixture();
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-10-20T14:06:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25,...loadExtra}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// Per cell: shown number, lit segments, status level and the colour the bar and number are painted with.
const cells=page=>page.locator('.u11-engine-table .qcell').evaluateAll(list=>list.map(c=>({
 value:c.querySelector('.qvalue')?.textContent??null,lit:c.querySelectorAll('.qbar i.on').length,
 level:[...c.classList].find(x=>x.startsWith('lv-')),fill:c.style.getPropertyValue('--qf'),num:c.style.getPropertyValue('--qn'),aria:c.getAttribute('aria-label')??''})));

test('default and explicit false show remaining',async({page})=>{
 const {send,receive}=await open(page);
 const left=await cells(page);expect(left.length).toBeGreaterThan(0);
 for(const c of left)if(c.value!==null&&c.value!=='--')expect(c.aria).toMatch(/% left|剩 \d+%/);
 expect(await receive(send('appearance',{...appearance,redBelow:25,showUsedPercent:false}))).toBe(true);
 expect(await cells(page)).toEqual(left);
});

test('used mode flips the text and the bars live; colours stay keyed to remaining',async({page})=>{
 const {send,receive}=await open(page,{showUsedPercent:false});
 const left=await cells(page);
 expect(await receive(send('appearance',{...appearance,redBelow:25,showUsedPercent:true}))).toBe(true);
 const used=await cells(page);expect(used.length).toBe(left.length);
 let compared=0;
 for(const [i,l] of left.entries()){
  const u=used[i];expect(u.level).toBe(l.level);expect(u.fill).toBe(l.fill);expect(u.num).toBe(l.num);
  if(l.value===null||l.value==='--'){expect(u.value).toBe(l.value);continue;}
  compared++;
  expect(Number(u.value)).toBe(100-Number(l.value));
  expect(u.aria).toMatch(/% used|已用 \d+%/);
  const seg=Math.round((100-Number(l.value))/10);
  expect(u.lit).toBe(100-Number(l.value)<=0?0:Math.min(10,Math.max(1,seg)));
 }
 expect(compared).toBeGreaterThan(0);
 expect(await receive(send('appearance',{...appearance,redBelow:25,showUsedPercent:false}))).toBe(true);
 expect(await cells(page)).toEqual(left);
});

test('used mode at open',async({page})=>{
 const {send,receive}=await open(page,{showUsedPercent:true});
 const used=await cells(page);
 expect(used.some(c=>/% used|已用 \d+%/.test(c.aria))).toBe(true);
 expect(await receive(send('appearance',{...appearance,redBelow:25}))).toBe(true);
 for(const c of await cells(page))if(c.value!==null&&c.value!=='--')expect(c.aria).toMatch(/% left|剩 \d+%/);
});

test('bridge validation: boolean only, optional, no unknown keys',async({page})=>{
 const {send,receive}=await open(page);
 for(const bad of ['yes',1,null,{}])expect(await receive(send('appearance',{...appearance,redBelow:25,showUsedPercent:bad}))).toBe(false);
 expect(await receive(send('appearance',{...appearance,redBelow:25,unknownKey:true}))).toBe(false);
 expect(await receive(send('appearance',{...appearance,showUsedPercent:true}))).toBe(true);
 expect(await receive(send('appearance',{...appearance,redBelow:25,showUsedPercent:false}))).toBe(true);
 // Inside the appearance object the key list stays strict.
 expect(await receive(send('appearance',{...appearance,redBelow:25,appearance:{showUsedPercent:true}}))).toBe(false);
});

test('bridge validation at load rejects non-boolean',async({page})=>{
 const {data}=visualFixture();void data;
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25,showUsedPercent:'true'}))).toBe(false);
 expect(await receive(send('load',{appearance,shell,redBelow:25,showUsedPercent:false}))).toBe(true);
});
