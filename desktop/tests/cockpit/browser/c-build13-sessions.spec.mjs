// SPDX-License-Identifier: MIT
// Owner build 13: a running Codex session the producer left unbound matched nothing, so the faders had no brand
// strip or lit effort, the model in use (Sol) had no fader, names were cut off and the record strip had no colour.
// The built page through its normal bridge; synthetic profile only (build13-fixture.mjs).
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const channels=page=>page.locator('.fd-ch:not(.empty)').evaluateAll(list=>list.map(ch=>({name:ch.querySelector('.st-name')?.textContent,
 clipped:(e=>e.scrollWidth>e.clientWidth+.5)(ch.querySelector('.st-name')),current:ch.querySelector('.eb.cur')?.dataset.l??null,
 strip:[...ch.querySelectorAll('.st-vend b')].map(b=>getComputedStyle(b).getPropertyValue('--v').trim())})));

test('B13 the model in use leads the faders with its short name, its brand strip and its current effort lit',async({page})=>{
 await open(page,build13Profile());
 const list=await channels(page);
 expect(list.map(c=>c.name)).toEqual(['Sol 6.1','Astra','Terra 6.1']);
 for(const c of list){expect(c.clipped).toBe(false);expect(c.strip).toEqual(['#6aa8ff']);}
 expect(list[0].current).toBe('High');
});

test('B13 the record strip lists the running Codex session in its subscription colour, by short model name',async({page})=>{
 await open(page,build13Profile());
 const rows=page.locator('.ck-tape .t-observed');
 await expect(rows).toHaveCount(1);
 await expect(rows.first().locator('.t-model')).toHaveText('Sol 6.1');
 expect(await rows.first().locator('.chip').evaluate(e=>getComputedStyle(e).getPropertyValue('--v').trim())).toBe('#6aa8ff');
});

test('B13 two subscriptions of the same tool leave an unbound session neutral',async({page})=>{
 const data=build13Profile(),row=data.projection.rows[0];
 row.accounts.push({...structuredClone(row.accounts[0]),subscriptionRef:'fedcba9876543210',accountLocator:'fedcba9876543210'});
 data.subscriptions.push({subscriptionRef:'fedcba9876543210',accounts:[{tool:'codex',account:structuredClone(row.accounts[1])}]});
 await open(page,data);
 expect(await page.locator('.ck-tape .t-observed .chip').evaluate(e=>getComputedStyle(e).getPropertyValue('--v').trim())).toBe('#c6ccd4');
 const list=await channels(page);expect(list[0].name).toBe('Sol 6.1');expect(list[0].strip).toEqual(['#6aa8ff','#6aa8ff']);
});

test('B13 the HUD and the Effort page use short names',async({page})=>{
 await open(page,build13Profile());
 const hud=await page.locator('.hud-list b').allTextContents();
 expect(hud).toContain('Sol 6.1');expect(hud).toContain('Terra 6.1');for(const name of hud)expect(name).not.toMatch(/^GPT-|^Claude /);
 await page.locator('[data-mfd="page:tune"]').click();
 const labels=await page.locator('.mfd-page text').allTextContents();
 expect(labels.join(' ')).toContain('Terra 6.1');expect(labels.join(' ')).not.toContain('GPT-6.1 Terra');
});
