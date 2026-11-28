// SPDX-License-Identifier: MIT
// macrevb-1290-10 (D474 §7.1 lamp tooltip, consent clear): the caution lamp's title carries the worst quota condition's
// sentence (subscription, quota, reset). A consent clear, and an empty delivery, take it away synchronously, so the host's
// `cleared` acknowledgement and any later hover find no subscription, quota or reset facts on the lamp. Built page, normal
// bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NAME='Synthetic Review Subscription';
const instant=Date.parse('2026-11-18T12:00:00Z');
const iso=minutes=>new Date(instant+minutes*60000).toISOString();
function alertData(){
 const data=visualFixture().data,row=data.projection.rows[0],a=row.accounts[0];
 row.name={en:NAME,zh:NAME};
 Object.assign(a,{valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
 for(const w of a.windows)Object.assign(w,{current:true,validUntil:iso(600),resetsAt:iso(3331),remainingPercent:13});
 data.projection.rows=[row];
 data.subscriptions=[{subscriptionRef:a.subscriptionRef,accounts:[{tool:row.id,account:structuredClone(a)}]}];
 data.details.peaks=[];
 return data;
}
function emptyData(){const data=visualFixture().data;data.projection.rows=[];data.subscriptions=[];data.details=null;return data;}
// Any subscription, quota or reset fact the lit lamp's title carried: the name, the percentage, the reset countdown.
const FACTS=new RegExp(`${NAME}|13\\s*%|\\d+d\\d+h|\\d+h\\d\\d|reset`,'i');

async function open(page){
 await page.addInitScript(facts=>{const re=new RegExp(facts,'i');window.__titleAtClear=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){
  const message=typeof raw==='string'?JSON.parse(raw):raw;
  if(message.type==='cleared'){const title=document.querySelector('[data-caution]')?.getAttribute('title')??null;window.__titleAtClear.push({title,leaked:re.test(title??'')});}
 }}}};},FACTS.source);
 await page.clock.setFixedTime(new Date(instant));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=(raw,method='receive')=>page.evaluate(([m,r])=>window.modelPlanCockpit[m](r),[method,raw]);
 expect(await receive(send('load',{appearance:{...appearance,locale:'en'},shell:{...shell,range:'today'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:alertData()}))).toBe(true);
 const lamp=page.locator('[data-caution]');
 // Before any clear the lit lamp still shows its normal two-line tooltip: the long sentence, then the list hint.
 await expect(lamp).toHaveClass(/\blit\b/);
 const before=await lamp.getAttribute('title');
 expect(before).toMatch(new RegExp(NAME));expect(before).toMatch(/13\s*%/);expect(before.split('\n')).toHaveLength(2);
 return {send,receive,lamp};
}
async function noFactsOnHover(page,lamp){
 await lamp.hover();
 const title=await lamp.getAttribute('title');
 expect(title,'no title survives on the lamp').toBeNull();
 expect(await lamp.getAttribute('aria-label')).not.toMatch(FACTS);
}

test('macrevb-1290-10 a consent clear removes the lamp title before the cleared acknowledgement',async({page})=>{
 const {send,receive,lamp}=await open(page);
 // The host's consent clear, through the page's dedicated clear entry (the same bounded message).
 expect(await receive(send('clear',{generation:'51',viewRevision:'5'}),'clear')).toBe(true);
 const atClear=await page.evaluate(()=>window.__titleAtClear);
 expect(atClear).toEqual([{title:null,leaked:false}]);
 await noFactsOnHover(page,lamp);
});

test('macrevb-1290-10 an empty delivery removes the lamp title through the same reset path',async({page})=>{
 const {send,receive,lamp}=await open(page);
 expect(await receive(send('display',{data:emptyData()}))).toBe(true);
 await expect(page.locator('.ck-eng .ec-empty')).toHaveCount(1);
 expect(await lamp.getAttribute('title')).toBeNull();
 await noFactsOnHover(page,lamp);
});
