// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {readFileSync} from 'node:fs';
import {commands,pageId,appearance,shell,sample} from '../fixture.mjs';
const details=()=>JSON.parse(readFileSync(new URL('../fixtures/cockpit-details-v1.json',import.meta.url)));

test('last-seen strip withholds unbound speed and clears private values',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=sample();
 const d=details();data.details=d;d.sessionCoverage='local-last-seen';d.sessions[0].subscriptionRef=null;d.sessions[0].projectLabel='<img onerror=alert(1)> CANARY';
 expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);
 const tape=page.locator('.ck-tape');await expect(tape).toHaveAttribute('aria-label',/last observed/i);
 await expect(tape.locator('.t-proj').first()).toHaveText('<img onerror=alert(1)> CANARY');
 await expect(tape.locator('.t-live').first()).toHaveText('--');await expect(tape.locator('img')).toHaveCount(0);
 await expect(tape).not.toContainText(d.sessions[0].sessionRef);await expect(tape).not.toContainText(/ended|running/i);
 data.details.sessions=Array.from({length:6},(_,i)=>({...d.sessions[0],sessionRef:String(i+1).padStart(16,'0')}));expect(await receive(send('display',{data}))).toBe(true);await expect(tape.locator('.t-overflow')).toContainText('2 more observed');
 const bad=structuredClone(data);bad.details.sessions[0].lastObservedAt='bad';expect(await receive(send('display',{data:bad}))).toBe(false);
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(tape).not.toContainText('CANARY');await expect(tape).toHaveAttribute('data-sessions-available','false');
});

test('today speed appears only for one verified source-wide current binding',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=sample();
 const d=details();data.details=d;d.sessionCoverage='local-last-seen';const ref=d.subscriptions[0].subscriptionRef;
 data.projection.rows[0].accounts[0].subscriptionRef=ref;data.subscriptions[0].subscriptionRef=ref;
 d.sessions[0].subscriptionRef=ref;d.sessions[0].source=d.subscriptions[0].today[0].source;d.subscriptions[0].today[0].bindingBasis='source-wide-current-binding';d.subscriptions[0].today[0].generationTps=0;d.subscriptions[0].today[0].observedOutputTokens=0;d.subscriptions[0].resetCounts[0].count=0;d.subscriptions[0].credits.balance=0;
 expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.qtokens').first()).toHaveText('0');await expect(page.locator('.qaverage').first()).toContainText('0');await expect(page.locator('.qrv-c').first()).toContainText('0');await expect(page.locator('.qrv-p').first()).toContainText('0');await expect(page.locator('.t-live').first()).toContainText('0');await expect(page.locator('.t-live').first()).toHaveAttribute('aria-label',/Today average 0/);
 d.sessions[0].subscriptionRef=null;expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.t-live').first()).toHaveText('--');
 d.sessionCoverage='recording-off';expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.ck-tape')).toHaveAttribute('aria-label','Session recording off');await expect(page.locator('.ck-tape .t-observed')).toHaveCount(0);
});
