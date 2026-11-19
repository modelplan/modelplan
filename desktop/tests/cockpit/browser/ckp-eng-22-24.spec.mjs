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
