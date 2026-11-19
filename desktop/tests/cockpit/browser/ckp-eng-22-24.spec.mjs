// SPDX-License-Identifier: MIT
// CKP-ENG-22 a stale column shows its reading age, never a fixed 0h · CKP-ENG-24 the empty bay's add opens the
// Settings Subscriptions pane. The built page through its normal bridge, synthetic data only.
// CKP-ENG-50 the six cell states · CKP-ENG-53 range row drop order · CKP-ENG-54 column wash · CKP-ENG-55 footer
// (shown page only, failing reads, right-aligned beside the pager) · CKP-ENG-56 one add affordance (#793 folded in) ·
// CKP-ENG-57 empty table · CKP-ENG-01/03 paging with 7+ subscriptions keeps the reserve row inside the table.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-18T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
async function open(page,data,locale='en') {
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
// n subscriptions cloned from the visual fixture's first one, every reading current and three minutes old.
function fixture(n) {
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0'),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref,accountLocator:ref,valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
  for(const w of a.windows)Object.assign(w,{current:true,validUntil:iso(600),resetsAt:iso(200)});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref,today:[{...detail.today[0],source:row.id}]});
 }
 const account=i=>data.projection.rows[i].accounts[0];
 const sync=()=>{for(const [i,s] of data.subscriptions.entries())s.accounts[0].account=structuredClone(account(i));};
 return {data,account,sync};
}

const stale=(page,i)=>page.locator('.eng-cols > .ec[data-col]').nth(i).innerText();
for(const [locale,age] of [['en','2h ago'],['zh-CN','2h前']])
 test(`CKP-ENG-22 a stale column shows its reading age once (${locale})`,async({page})=>{
  const {data,account,sync}=fixture(2);Object.assign(account(1),{valueState:'retained',observedAt:iso(-125)});sync();
  await open(page,data,locale);
  const text=await stale(page,1);expect(text.split(age).length-1).toBe(1);expect(text).not.toMatch(/\b0h\b|0h前/);
  expect(await stale(page,0)).not.toContain(age);
 });
test('CKP-ENG-22 a stale column with no reading time shows no age, never 0h',async({page})=>{
 const {data,account,sync}=fixture(2);Object.assign(account(1),{valueState:'retained',observedAt:null});sync();
 await open(page,data);
 expect(await stale(page,1)).not.toMatch(/\b0h\b|ago/);
});
test('CKP-ENG-24 the empty bay add-subscription opens Settings on the Subscriptions pane',async({page})=>{
 const {data}=fixture(2);
 await open(page,data);
 await page.evaluate(()=>{window.sent.length=0;});
 await page.locator('.ec-add').first().click();
 expect(await page.evaluate(()=>window.sent.filter(m=>m.type==='action').map(m=>m.action))).toEqual(['openSettingsSubscriptions']);
});

// macrevb-1020-1: the footer describes only the DISPLAYED columns, also while a subscription is selected and the pager moves.
test('CKP-ENG-55 a selected subscription does not keep a paged-out reading in the footer',async({page})=>{
 const {data,account,sync}=fixture(7);
 account(6).observedAt=iso(-125);account(6).valueState='retained';account(6).lastFailure={at:iso(-1),code:'network'};sync();
 await open(page,data);
 await page.locator('.ek[data-sub]').first().click();
 await expect(page.locator('.eng-upd-t'),'selected, own reading').toHaveText('Updated 3 min ago');
 await page.evaluate(()=>{window.sent.length=0;});await page.locator('.eng-upd-r').click();
 const own=await page.evaluate(()=>window.sent.filter(m=>m.action==='refreshMember').map(m=>m.key));expect(own,'on screen: its own key').toHaveLength(1);expect(own[0]).not.toBe('all');
 await page.locator('.eng-pk[data-bpage="1"]').click();
 await expect(page.locator('.eng-upd-t'),'page 2 is on screen: its reading, its failure').toHaveText('Updated 2 h ago · no new data');
 await expect(page.locator('.eng-upd')).toHaveAttribute('data-failing','true');
 // Retry's label and target follow what is on screen: the selected account is paged out, so it is not what refreshes.
 await expect(page.locator('.eng-upd-r')).toHaveText('Retry');
 await expect(page.locator('.eng-upd-r')).toHaveAttribute('aria-label',/all/i);
 await page.evaluate(()=>{window.sent.length=0;});await page.locator('.eng-upd-r').click();
 expect(await page.evaluate(()=>window.sent.filter(m=>m.action==='refreshMember').map(m=>m.key))).toEqual(['all']);
 await page.locator('.eng-pk[data-bpage="-1"]').click();
 await expect(page.locator('.eng-upd-t')).toHaveText('Updated 3 min ago');
 await expect(page.locator('.eng-upd')).toHaveAttribute('data-failing','false');
});

// macrevb-1020-3: the age rides the first populated quota cell, so a weekly-only (or Other-only) stale column still has it.
test('CKP-ENG-22 a stale weekly-only subscription shows its reading age on its weekly cell',async({page})=>{
 const {data,account,sync}=fixture(2);
 Object.assign(account(1),{valueState:'retained',observedAt:iso(-125)});account(1).windows=account(1).windows.filter(w=>w.role==='weekly');sync();
 await open(page,data);
 const col=page.locator('.eng-cols > .ec[data-col]').nth(1);
 await expect(col.locator('.qcell[data-row="first"] .qtxt')).toHaveCount(0);
 await expect(col.locator('.qcell[data-row="second"] .qtxt')).toHaveText(/2h ago/);
 expect((await col.innerText()).split('2h ago').length-1).toBe(1);
});
