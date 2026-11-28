// SPDX-License-Identifier: MIT
// macrev2-1291-8 / -9. Invariant: after a consent clear (and an empty delivery) no element of the page keeps the subscription's
// name, its quota or its reset text in ANY attribute (title, aria-*, data-*) or text node: not on the alert lamp's tooltip, not in a
// hover card, the strip card, the 日历 page or the keys. Also: repeated deliveries leave a bounded number of document handlers.
// Built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-18T12:00:00Z'),iso=m=>new Date(NOW+m*60000).toISOString(),NAME='PRIV-1291-SUBSCRIPTION';
function fixture(){
 const data=visualFixture().data,row=data.projection.rows[0],a=row.accounts[0];
 row.name={en:NAME,zh:NAME};Object.assign(a,{valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
 for(const w of a.windows)Object.assign(w,{current:true,validUntil:iso(600),resetsAt:iso(3331),remainingPercent:13});// 13 % left, resets in 2d7h31
 data.projection.rows=[row];data.subscriptions=[{subscriptionRef:a.subscriptionRef,accounts:[{tool:row.id,account:structuredClone(a)}]}];
 data.details.peaks=[];return data;
}
async function open(page,range='today'){
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=(raw,m='receive')=>page.evaluate(({raw,m})=>window.modelPlanCockpit[m](raw),{raw,m});
 expect(await receive(send('load',{appearance:{...appearance,locale:'en'},shell:{...shell,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=fixture();expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}
// Every attribute value and text node, anywhere in the document, that carries the private facts.
const leaks=page=>page.evaluate(([name,quota,reset])=>{
 const bad=t=>t&&(t.includes(name)||t.includes(quota)||t.includes(reset)),out=[];
 for(const e of document.querySelectorAll('*')){for(const at of e.attributes)if(bad(at.value))out.push(`${e.tagName}.${e.className} [${at.name}]`);
  for(const n of e.childNodes)if(n.nodeType===3&&bad(n.textContent))out.push(`${e.tagName}.${e.className} text`);}
 return out;
},[NAME,'13%','2d7h']);

test('macrev2-1291-8 a consent clear leaves no subscription name, quota or reset text in any attribute or text node',async({page})=>{
 const {send,receive}=await open(page);
 // The alert lamp's tooltip, a hover card and the strip card carry the facts while delivered.
 await expect(page.locator('[data-caution]')).toHaveAttribute('title',new RegExp(NAME));
 await page.locator('.eng-cols > .ec[data-col]').first().locator('.qcell[data-row="first"]').hover();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:2000});
 await page.locator('.eng-cols > .ec[data-col]').first().locator('.ec-strip').hover();
 await expect(page.locator('.ec-next')).toBeVisible();
 expect((await leaks(page)).length,'the facts are on screen before the clear').toBeGreaterThan(0);
 expect(await receive(send('clear',{generation:'51',viewRevision:'5'}),'clear')).toBe(true);
 expect(await leaks(page),'right after the clear').toEqual([]);
 await expect(page.locator('[data-caution]')).not.toHaveAttribute('title',/.+/);
 await page.waitForTimeout(600);
 expect(await leaks(page),'and still absent later').toEqual([]);
});

test('macrev2-1291-8 an empty delivery clears them too',async({page})=>{
 const {send,receive,data}=await open(page);
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];data.details.sessions=[];data.details.forecasts=[];
 expect(await receive(send('display',{data}))).toBe(true);
 expect(await leaks(page)).toEqual([]);
});

// macrev2-1291-9: a rebuilt table must not leave its document handlers behind.
test('macrev2-1291-9 repeated deliveries keep the document pointer handlers bounded while the hover survives',async({page})=>{
 await page.addInitScript(()=>{window.__n=0;const add=document.addEventListener.bind(document);document.addEventListener=function(t,l,o){if(t==='pointermove')window.__n++;return add(t,l,o);};const rm=document.removeEventListener.bind(document);document.removeEventListener=function(t,l,o){if(t==='pointermove')window.__n--;return rm(t,l,o);};});
 const {send,receive,data}=await open(page);
 await page.locator('.eng-cols > .ec[data-col]').first().locator('.qcell[data-row="first"]').hover();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:2000});
 for(let i=0;i<9;i++)expect(await receive(send('display',{data}))).toBe(true);
 expect(await page.evaluate(()=>window.__n),'live pointermove handlers').toBeLessThanOrEqual(2);
 await expect(page.locator('.hc-card')).toHaveCount(1);
});
