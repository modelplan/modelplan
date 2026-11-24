// SPDX-License-Identifier: MIT
// G3-200 / CKP-FAD-53 / CKP-FAD-09 on the built page through its normal bridge (synthetic data only): with no live effort
// a model's current effort is the latest recorded session of the last seven days that reported one; the LCD opens the
// comparison without a trial, the fader then compares against it, and no other session's Fast flag is borrowed.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {readFileSync} from 'node:fs';
import {build13Profile} from '../build13-fixture.mjs';
const speedTiers=JSON.parse(readFileSync(new URL('../unit/client-speed-tiers.fixture.json',import.meta.url),'utf8')).data.speedTiers.map(({reviewedAt,...tier})=>tier);

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const DAY=864e5,ago=ms=>new Date(Date.now()-ms).toISOString().replace(/\.\d+Z$/,'Z');
const live=(ref,effort,fast,ms=20e3)=>({sessionRef:ref.padEnd(16,'0'),source:'codex',subscriptionRef:null,model:'sol-6.1',effort,fast,projectLabel:'p',lastObservedAt:ago(ms),state:'running',rate:null});
const recorded=(ref,effort,ms)=>({sessionRef:ref.padEnd(16,'0'),source:'codex',subscriptionRef:null,model:'sol-6.1',effort,projectLabel:'p',lastObservedAt:ago(ms)});
async function open(page,{liveSessions,recent}){
 await page.setViewportSize({width:636,height:890});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=build13Profile(),ids={'gpt-6.1-sol':'sol-6.1','gpt-6-astra':'astra-unlisted','gpt-6-luna':'luna','gpt-6.1-terra':'auto:openai:51617927bdb7d656'},fix=m=>({...m,id:ids[m.id]??m.id});
 data.details.publication={...data.details.publication,models:data.details.publication.models.map(fix),speedTiers:structuredClone(speedTiers)};
 data.details.publishedModels=data.details.publishedModels.map(fix);
 data.details.sessions=liveSessions;data.details.recentSessions=recent;
 expect(await receive(send('display',{data}))).toBe(true);
}
const sol=page=>page.locator('.fd-ch:not(.empty)').filter({has:page.locator('.st-name',{hasText:'Sol 6.1'})});

test('G3-200 recorded only: the card reads the latest reported effort; the LCD opens the comparison with no trial; the fader trials against it',async({page})=>{
 await open(page,{liveSessions:[],recent:[recorded('1','low',5*DAY),recorded('2','high',2*DAY),recorded('3',null,3600e3)]});
 const card=sol(page);
 await expect(card.locator('.cd-cur')).toHaveText('High');
 await card.locator('.fd-strip').click();
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
 await expect(page.locator('.fd-ch.trying')).toHaveCount(0);
 await card.locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(card.locator('.fd-strip')).toHaveAttribute('data-card','try');
 await expect(card.locator('.fd-strip')).toContainText('Try XHigh');
 await expect(card.locator('.fd-strip')).toContainText('Now High');
});
test('G3-200 a live session with no effort and Fast on does not lend its Fast flag to the recorded effort (macrevb-1204-1)',async({page})=>{
 await open(page,{liveSessions:[live('a',null,true)],recent:[recorded('2','high',2*DAY)]});
 const card=sol(page);
 await expect(card.locator('.cd-cur')).toHaveText('High');
 await expect(card.locator('.fd-indicator')).toHaveAttribute('data-fast-mode','off');
 await card.locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.mfd-vk button.vk-fast')).toHaveAttribute('aria-pressed','false');
});
test('G3-200 a live session that reports effort and Fast keeps precedence over the record',async({page})=>{
 await open(page,{liveSessions:[live('a','xhigh',true)],recent:[recorded('2','high',2*DAY)]});
 const card=sol(page);
 await expect(card.locator('.cd-cur')).toHaveText('XHigh');
 await expect(card.locator('.fd-indicator')).toHaveAttribute('data-fast-mode','on');
});
test('G3-200 a record older than seven days gives no effort',async({page})=>{
 await open(page,{liveSessions:[],recent:[recorded('2','high',8*DAY)]});
 await expect(sol(page).locator('.cd-cur')).toHaveCount(0);
});
