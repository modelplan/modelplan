// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {commands,pageId,appearance,shell,sample} from '../fixture.mjs';

test('prototype faders use only supplied synthetic publication and clear their values',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 await page.evaluate(async()=>{
  const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
  const faders=Array.from({length:4},(_,i)=>({id:'synthetic-'+i,name:i===0?'<img src=x onerror="window.__step2xss=true"> FADER-CANARY':'Synthetic '+i,short:'S'+i,rec:'Med',e:[['Low',1,1,1],['Med',2,2,2],['High',3,3,3]],pinned:false,current:'High',currentFast:false,others:{},tier:null,accounts:['synthetic-account'],sessions:[]}));
  window.__step2Deck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication:{accounts:[{id:'synthetic-account',colour:'#6aa8ff'}],faders},liveSessions:[],resetEvents:null,history:null});
 });
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
 await expect(page.locator('.fd-strip').first()).toContainText('FADER-CANARY');
 await expect(page.locator('.fd-strip').first().locator('.st-eff em')).toHaveText('--');
 const travel=page.getByRole('slider').first();await travel.focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.fd-ch').first().locator('.fd-ghost')).toBeVisible();
 expect(await page.evaluate(()=>window.__step2xss)).toBeUndefined();
 expect(await page.locator('.private-content img').count()).toBe(0);
 await page.getByRole('button',{name:'Next fader bank (key ])'}).click();
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(1);
 await expect(page.locator('.fd-strip').first()).toContainText('Synthetic 3');
 await page.evaluate(()=>window.__step2Deck.clear());
 await expect(page.locator('.fd-ch.empty')).toHaveCount(3);
 await expect(page.locator('#cockpit')).not.toContainText('FADER-CANARY');
});


test('MFD scope selection emits only the current member through the bridge',async({page})=>{
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=sample();
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.getByRole('button',{name:'Plans',exact:true}).click();
 await page.locator('.mfd-page .sa-list .sa').first().click();
 const event=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));
 expect(event.action).toBe('scopeSelect');expect(event.key).toBe(data.projection.rows[0].accounts[0].subscriptionRef);
 await expect(page.getByRole('button',{name:'Codex',exact:true})).toHaveAttribute('aria-pressed','true');
});

test('fader effort uses only a matched observed session and says last observed',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 await page.evaluate(async()=>{
  const {mountPrototypeDeck}=await import('/src/prototype-deck.js');
  const model={id:'synthetic-model',name:'Synthetic model',short:'Synthetic',rec:'Med',e:[['low',1,1,1],['medium',2,2,2],['high',3,3,3]],current:'Max',currentFast:true,accounts:[],sessions:[{ref:'fake-session',sub:'unverified',account:'MUST-NOT-APPEAR'}]};
  window.__step2Deck=mountPrototypeDeck(document.querySelector('#cockpit'),undefined,{publication:{accounts:[],faders:[model]},liveSessions:[{sessionRef:'fake-session',effort:'high',fast:false,lastObservedAt:'2026-10-20T14:04:50Z'}],resetEvents:null,history:null});
 });
 await expect(page.locator('.fd-strip').first().locator('.st-eff em')).toHaveText('High');
 await expect(page.locator('.fd-indicator').first()).toHaveAttribute('aria-label',/Last observed/);
 await expect(page.locator('.fd-indicator').first()).not.toHaveAttribute('aria-label',/running|ended|MUST-NOT-APPEAR/i);
});
