// SPDX-License-Identifier: MIT
// G3-110 (owner, build 14e): a subscription scope shows that subscription's models on the fader banks, as the opus-r7
// study's faders() does (core.js scopePools); All keeps the D123 set. The caps glide on the switch (CKP-FAD-12).
// The built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId,rec='medium')=>({id,name:'Synthetic '+id,developerId,recommended:rec,efforts:[{effort:'low',label:'Low',star:rec==='low',ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:rec==='medium',ability:40,cost:2,time:null},{effort:'high',label:'High',star:rec==='high',ability:50,cost:3,time:null}]});
const CODEX='0000000000000001',CLAUDE='0000000000000002',CURSOR='0000000000000003';
function fixture(){
 const data=visualFixture().data;
 const publication=[model('gpt-a','openai'),model('claude-a','anthropic','high'),model('gpt-b','openai','low')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('claude-b','anthropic'),model('gemini-a','google'),model('gpt-c','openai'),model('gpt-d','openai')];
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'claude',subscriptionRef:null,model:'claude-a',effort:'high',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null}];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const names=page=>page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.map(e=>e.getAttribute('aria-label').split(':')[0]));
const allNames=async page=>{const out=[];const lcd=page.locator('.bank-lcd');const total=await lcd.count()?Number((await lcd.textContent()).match(/\/(\d+)/)[1]):1;
 for(let i=0;i<total;i++){out.push(...await names(page));if(i<total-1)await page.locator('[data-bank="1"]').click();}return out;};

test('G3-110 a subscription scope shows only that subscription\'s models; All keeps the D123 set',async({page})=>{
 const {send,receive}=await open(page,fixture());
 const all=await allNames(page);
 expect(all.slice(0,3)).toEqual(['Synthetic claude-a','Synthetic gpt-a','Synthetic gpt-b']);
 expect([...all].sort()).toEqual(['Synthetic claude-a','Synthetic claude-b','Synthetic gemini-a','Synthetic gpt-a','Synthetic gpt-b','Synthetic gpt-c','Synthetic gpt-d']);
 expect(await receive(send('shell',{...shell,scope:CODEX}))).toBe(true);
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/2');
 expect(await allNames(page)).toEqual(['Synthetic gpt-a','Synthetic gpt-b','Synthetic gpt-c','Synthetic gpt-d']);
 expect(await receive(send('shell',{...shell,scope:CLAUDE}))).toBe(true);
 await expect(page.locator('.bank-lcd')).toHaveCount(0);
 expect(await names(page)).toEqual(['Synthetic claude-a','Synthetic claude-b']);
 await expect(page.locator('.fd-ch.empty')).toHaveCount(1);
 // A subscription whose developer is not known here cannot be matched: the D123 set stays rather than an empty bank.
 expect(await receive(send('shell',{...shell,scope:CURSOR}))).toBe(true);
 expect(await allNames(page)).toEqual(all);
 expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);
 expect(await allNames(page)).toEqual(all);
});

test('G3-110 a scope switch starts at bank 1 and the same caps glide to the new models\' efforts (CKP-FAD-12)',async({page})=>{
 const {send,receive}=await open(page,fixture());
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/3');
 // Slot 1 holds claude-a at High under All; under Codex it holds gpt-a at Med: the cap element stays and its top glides.
 const cap=page.locator('.fd-ch').first().locator('.fd-cap');
 await cap.evaluate(e=>{e.dataset.g3110='kept';});
 const before=await cap.evaluate(e=>getComputedStyle(e).getPropertyValue('--k').trim());
 await page.locator('[data-bank="1"]').click();await page.locator('[data-bank="1"]').click();await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 expect(await receive(send('shell',{...shell,scope:CODEX}))).toBe(true);
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 1/2');
 await expect(page.locator('.fd-ch').first().locator('.fd-strip')).toHaveAttribute('aria-label',/^Synthetic gpt-a/);
 expect(await cap.getAttribute('data-g3110')).toBe('kept');
 const after=await cap.evaluate(e=>({k:getComputedStyle(e).getPropertyValue('--k').trim(),transition:getComputedStyle(e).transitionProperty+' '+getComputedStyle(e).transitionDuration}));
 expect(after.k).not.toBe(before);
 expect(after.transition).toContain('top');expect(after.transition).toContain('0.28s');
});

// macrevb-930-1: scope membership counts every bound session, not only the six a fader displays. gpt-a has six
// sessions on the Codex subscription and a seventh bound to Claude, so the Claude scope still holds gpt-a, also with
// Settings' "show all models" on.
test('G3-110 a model bound to the scoped subscription stays after six sessions on another subscription',async({page})=>{
 const data=fixture();
 data.details.sessions=Array.from({length:7},(_,i)=>({sessionRef:(160+i).toString(16).padStart(16,'0'),source:i===6?'claude':'codex',subscriptionRef:i===6?CLAUDE:CODEX,model:'gpt-a',effort:'medium',projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null}));
 const {send,receive}=await open(page,data);
 expect(await receive(send('shell',{...shell,scope:CLAUDE}))).toBe(true);
 expect([...await allNames(page)].sort()).toEqual(['Synthetic claude-a','Synthetic claude-b','Synthetic gpt-a']);
 expect(await receive(send('appearance',{...appearance,redBelow:25,showAllModels:true}))).toBe(true);
 expect([...await allNames(page)].sort()).toEqual(['Synthetic claude-a','Synthetic claude-b','Synthetic gpt-a']);
 // The Codex scope keeps gpt-a through its developer as before.
 expect(await receive(send('shell',{...shell,scope:CODEX}))).toBe(true);
 expect(await allNames(page)).toContain('Synthetic gpt-a');
});
