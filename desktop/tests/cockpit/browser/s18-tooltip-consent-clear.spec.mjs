// SPDX-License-Identifier: MIT
// Sampling 11-21 S18 (#1020, ADR 0005 consent clear). A quota cell's tooltip (an unknown reset: the subscription
// name and its remaining quota) is appended to the cockpit root, outside the engine table. Clearing consent while it
// was open replaced the table but left the tooltip, with the private text, in the DOM at the `cleared`
// acknowledgement. Invariant: at `cleared` nothing private remains anywhere in the cockpit. Built page through its
// normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-18T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString(),NAME='S18-PRIVATE-SUBSCRIPTION';
test('S18 a consent clear removes an open quota tooltip before it is acknowledged',async({page})=>{
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){const message=JSON.parse(raw);
  window.__events.push({...message,cockpitAtClear:message.type==='cleared'?document.getElementById('cockpit').textContent:null,hintsAtClear:message.type==='cleared'?document.querySelectorAll('.eng-hint,.hc-card,.ec-next').length:null});}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=(raw,method='receive')=>page.evaluate(({raw,method})=>window.modelPlanCockpit[method](raw),{raw,method});
 const data=visualFixture().data,row=data.projection.rows[0],a=row.accounts[0];
 row.name={en:NAME,zh:NAME};Object.assign(a,{valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
 for(const w of a.windows)Object.assign(w,{current:true,validUntil:iso(600),resetsAt:iso(200)});
 a.windows[0].resetsAt=null;
 data.projection.rows=[row];data.subscriptions=[{subscriptionRef:a.subscriptionRef,accounts:[{tool:row.id,account:structuredClone(a)}]}];
 expect(await receive(send('load',{appearance:{...appearance,locale:'en'},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.locator('.eng-cols > .ec[data-col]').first().locator('.qcell[data-row="first"]').hover();
 const tip=page.locator('.hc-card');// the shared hover card carries the name (D474 §7.1)
 await expect(tip).toBeVisible({timeout:2000});await expect(tip).toContainText(NAME);
 // The pointer stays on the cell: only the clear may take the tooltip away.
 expect(await receive(send('clear',{generation:'43',viewRevision:'4'}),'clear')).toBe(true);
 const ack=await page.evaluate(()=>window.__events.filter(e=>e.type==='cleared').at(-1));
 expect(ack.generation).toBe('43');
 expect(ack.hintsAtClear).toBe(0);
 expect(ack.cockpitAtClear).not.toContain(NAME);
 expect(await page.evaluate(()=>document.documentElement.innerHTML)).not.toContain(NAME);
});
