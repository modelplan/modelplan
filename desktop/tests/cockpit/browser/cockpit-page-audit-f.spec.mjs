// SPDX-License-Identifier: MIT
// Audit F (11-11, cockpit web page logic): the deck's held state across deliveries and bank pages, through the normal
// bridge with synthetic data. Pure-logic parts are in unit/cockpit-page-audit-f.test.mjs.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const model=(id,developerId)=>({id,name:'Synthetic '+id,developerId,recommended:'medium',efforts:[{effort:'low',label:'Low',star:false,ability:30,cost:1,time:null},{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]});
const session=(ref,source,model,effort)=>({sessionRef:ref,source,subscriptionRef:null,model,effort,projectLabel:null,lastObservedAt:new Date().toISOString(),state:'running',rate:null});
// As c-fader-banks.spec.mjs: faders used, also-used, lineup-1, lineup-2, more-1, more-2, more-3 (banks 3, 3, 1).
function fixture(){
 const data=visualFixture().data;
 const publication=[model('used','openai'),model('lineup-1','openai'),model('lineup-2','anthropic')];
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:true,models:publication};
 data.details.publishedModels=[...publication,model('more-1','openai'),model('xai-1','xai'),model('more-2','openai'),model('also-used','anthropic'),model('more-3','openai')];
 data.details.sessions=[session('00000000000000a1','codex','used','medium'),session('00000000000000a2','claude','also-used','medium')];
 return data;
}
async function open(page,data){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const display=async data=>expect(await receive(send('display',{data}))).toBe(true);
 await display(data);return display;
}
const fader=(page,name)=>page.locator('.fd-ch:not(.empty)').filter({has:page.locator(`.fd-strip[aria-label^="Synthetic ${name}:"]`)});
const screen=page=>page.locator('.mfd-page.pg-compare');

test('audit F 1 (CKP-FAD-09): an open trial stays on its model when a session update reorders the faders',async({page})=>{
 const display=await open(page,fixture());
 await fader(page,'lineup-1').locator('.fd-strip').click();
 await screen(page).locator('.cmp-lad [data-mfd="try:Low"]').click();
 await expect(page.locator('.mfd-title')).toHaveText('Compare · Synthetic lineup-1');
 // lineup-2 starts a session: it moves ahead of lineup-1 and takes lineup-1's old position.
 const data=fixture();data.details.sessions.push(session('00000000000000a3','claude','lineup-2','medium'));
 await display(data);
 await expect(page.locator('.mfd-title')).toHaveText('Compare · Synthetic lineup-1');
 await expect(page.locator('.fd-ch.trying')).toHaveCount(0); // lineup-1 is on bank 2 now; nothing on bank 1 is in a trial
 await expect(fader(page,'lineup-2')).not.toHaveClass(/\btrying\b/);
 await page.locator('[data-bank="1"]').click();
 await expect(fader(page,'lineup-1')).toHaveClass(/\btrying\b/);
});

test('audit F 2 (CKP-MFD-19): the comparison measures against the session effort reported now',async({page})=>{
 const display=await open(page,fixture());
 await fader(page,'used').locator('.fd-strip').click();
 const current=screen(page).locator('th[data-role="current"] b');
 await expect(current).toHaveText('Med');
 const data=fixture();data.details.sessions[0].effort='low';await display(data);
 await expect(current).toHaveText('Low');
 // No new trial of the old effort appeared; the card opened from the LCD still tries nothing.
 await expect(screen(page).locator('th[data-role="trial"]')).toHaveAttribute('data-light','off');
 // The session ends: current is unreported, the table shows dashes.
 const ended=fixture();ended.details.sessions=ended.details.sessions.slice(1);await display(ended);
 await expect(current).toHaveText('--');
});

test('audit F 5 (CKP-MFD-22): the comparison website link names the published model',async({page})=>{
 await open(page,fixture());
 await fader(page,'used').locator('.fd-strip').click();
 await expect(screen(page).locator('.cmp-header-links a').first()).toHaveAttribute('href',/\/effort\?model=used$/);
});

test('audit F 7 (CKP-FAD-17): an empty slot never keeps a trial\'s ghost cap',async({page})=>{
 await open(page,fixture());
 await fader(page,'also-used').locator('.fd-strip').click();
 await screen(page).locator('.cmp-lad [data-mfd="try:Low"]').click();
 const ghost=page.locator('.fd-ch[data-slot="1"] .fd-ghost');
 expect(await ghost.evaluate(e=>e.hidden)).toBe(false);
 await page.keyboard.press(']');await page.keyboard.press(']');
 await expect(page.locator('.bank-lcd')).toHaveText('Bank 3/3');
 await expect(page.locator('.fd-ch[data-slot="1"]')).toHaveClass(/\bempty\b/);
 expect(await ghost.evaluate(e=>e.hidden)).toBe(true);
 await page.keyboard.press('Escape');
 expect(await ghost.evaluate(e=>e.hidden)).toBe(true);
});
