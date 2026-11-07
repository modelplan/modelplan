// SPDX-License-Identifier: MIT
// CKP-STRIP-15 on the built page through its normal bridge, with synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,data) {
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(v){window.__events.push(typeof v==='string'?JSON.parse(v):v);}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}

test('a record line lights its engine column, and a click selects it and shows the session',async({page})=>{
 const {data}=visualFixture(),session=data.details.sessions[0];session.subscriptionRef=data.projection.rows[0].accounts[0].subscriptionRef;expect(session.subscriptionRef).toBeTruthy();
 await open(page,data);
 const line=page.locator(`.ck-tape .t-observed[data-session="${session.sessionRef}"]`),column=page.locator(`.ec[data-col="${session.subscriptionRef}"]`);
 await expect(line).not.toHaveAttribute('aria-disabled','true');
 await line.hover();await expect(column).toHaveClass(/\bxhl\b/);
 await page.mouse.move(0,0);await expect(column).not.toHaveClass(/\bxhl\b/);
 await line.click();
 expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1))).toMatchObject({action:'scopeSelect',key:session.subscriptionRef});
 await expect(page.locator('.mfd-page.pg-where .ws-list .ws').first()).toBeVisible();
});

test('a line without a subscription or fader offers no action',async({page})=>{
 const {data}=visualFixture();for(const s of data.details.sessions)s.subscriptionRef=null;
 await open(page,data);
 const line=page.locator('.ck-tape .t-observed').first();
 await expect(line).toHaveAttribute('aria-disabled','true');await expect(line).toHaveAttribute('tabindex','-1');
});

test('the deck lights the fader carrying a session',async({page})=>{
 const fixture=visualFixture();await open(page,fixture.data);
 const lit=await page.evaluate(async({data,publication})=>{
  const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
  const deck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication,liveSessions:data.details.sessions,resetEvents:null,history:null});
  deck.render(data,Date.parse('2026-10-20T14:05:00Z'));
  const ref=publication.faders.flatMap(f=>f.sessions??[])[0].ref;
  deck.highlightSession(ref);const on=document.querySelectorAll('.fd-ch.xhl').length;deck.highlightSession(null);
  return {known:deck.knowsSession(ref),on,off:document.querySelectorAll('.fd-ch.xhl').length,unknown:deck.knowsSession('not-a-session')};
 },fixture);
 expect(lit).toEqual({known:true,on:1,off:0,unknown:false});
});

test('with the wire publication, a record line lights the fader of its model',async({page})=>{
 const {data}=visualFixture(),session=data.details.sessions[0];session.subscriptionRef=null;session.model='model-b';
 const model=(id,name)=>({id,name,developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[model('model-a','Synthetic A'),model('model-b','Synthetic B')]};
 await open(page,data);
 const line=page.locator(`.ck-tape .t-observed[data-session="${session.sessionRef}"]`),fader=page.locator('.fd-ch:not(.empty)').first();
 await expect(fader.locator('.fd-strip')).toContainText('Synthetic B');
 await expect(line).not.toHaveAttribute('aria-disabled','true');
 await line.hover();await expect(fader).toHaveClass(/\bxhl\b/);
 await page.mouse.move(0,0);await expect(fader).not.toHaveClass(/\bxhl\b/);
});
