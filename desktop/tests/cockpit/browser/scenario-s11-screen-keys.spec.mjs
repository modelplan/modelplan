// SPDX-License-Identifier: MIT
// spec-cockpit.md S11: "Cockpit opened on usage | Select each of the four screen
// keys | Correct page and active indicator appear; comparison obeys its return
// rule". T1 (specs/scenario-tests.tsv) marks S11 ABSENT. The comparison view and
// its return rule are v1.1-deferred (D13, owner 2026-11-01), so this test locks
// the v1 half: each key shows exactly its page and exactly one active indicator.
// Failing-first: assertions that do not hold on the candidate head are expected
// failures recording the gap, not flakes.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const KEYS=[['Overview','pg-overview'],['Subscription','pg-sub'],['Effort','pg-tune'],['Breakdown','pg-where']];

const open=async(page)=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 return {send,receive};
};

test('S11: each screen key shows its page and lights exactly one active indicator',async({page})=>{
 const {receive,send}=await open(page);
 for(const [name,pageClass] of KEYS){
  await page.locator('.mfd-pk button',{hasText:name}).first().click();
  const state=await page.evaluate(()=>{
   const keyButtons=[...document.querySelectorAll('.mfd-pk button')];
   const lit=keyButtons.filter(b=>b.getAttribute('aria-pressed')==='true'||b.getAttribute('aria-current')==='true').map(b=>b.textContent.trim());
   const area=document.querySelector('.mfd-page:not([hidden])');
   return {lit,page:area?.className??null,text:area?.textContent.trim().slice(0,40)??''};
  });
  expect(state.lit,'S11: exactly one active indicator after choosing '+name).toEqual([name]);
  expect(state.page,'S11: '+name+' shows '+pageClass).toContain(pageClass);
 }
 // Returning to Overview works from any page (the v1 return path).
 await page.locator('.mfd-pk button',{hasText:'Breakdown'}).first().click();
 await page.locator('.mfd-pk button',{hasText:'Overview'}).first().click();
 expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);
 await expect(page.locator('.mfd-page.pg-overview')).toBeVisible();
});
