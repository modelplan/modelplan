// SPDX-License-Identifier: MIT
// Owner decision D277 (2026-11-16) on the built page through its normal bridge, synthetic data only.
// CKP-ENG-26: no repeated "reset ?" on the engine table; the cell that will run out says "out ~40m" in its alert
// colour even when its reset time is unknown. CKP-ENG-27: the key carries the plan the reader knows, and one quiet line
// says when the readings were taken with a Refresh that posts one typed bridge action.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-16T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
async function open(page,data,locale='en') {
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const actions=page=>page.evaluate(()=>window.sent.filter(m=>m.type==='action').map(m=>({action:m.action,key:m.key})));
// Two subscriptions, every reading current, no reset time anywhere; the first member's 5h window runs out in 40 min.
function fixture({remaining=60,plan={en:'Pro 200',zh:'Pro 200'}}={}) {
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,2);
 const keep=new Set(data.projection.rows.flatMap(r=>r.accounts.map(a=>a.subscriptionRef)).filter(Boolean));
 data.subscriptions=data.subscriptions.filter(s=>keep.has(s.subscriptionRef));
 for(const r of data.projection.rows)for(const a of r.accounts){a.valueState='current';a.observedAt=iso(-3);a.plan.name=plan;
  for(const w of a.windows)Object.assign(w,{current:true,remainingPercent:90,validUntil:iso(30),resetsAt:null});}
 const row=data.projection.rows[0],account=row.accounts[0],w=account.windows[0];w.remainingPercent=remaining;
 data.details.forecasts=[{source:row.id,subscriptionRef:account.subscriptionRef,windowId:w.id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-2)}];
 return {data,row,account};
}

for(const [locale,unknown,out] of [['en','reset ?','out ~40m'],['zh-CN','重置未知','约40m用完']])
 test(`CKP-ENG-26 no repeated unknown reset; the cell that runs out says so (${locale})`,async({page})=>{
  await open(page,fixture().data,locale);
  const lines=page.locator('.ck-eng .qtxt');
  await expect(lines.filter({hasText:unknown})).toHaveCount(0);
  const warn=page.locator('.ck-eng .qcell .qtxt.warn');
  await expect(warn).toHaveCount(1);await expect(warn).toHaveText(out);await expect(warn).toBeVisible();
  // The hover still says the reset time is unknown.
  await expect(page.locator('.ck-eng .qcell').nth(1)).toHaveAccessibleName(new RegExp(unknown.replace('?','\\?')));
 });

test('CKP-ENG-26 at or below the red line the run-out text is red',async({page})=>{
 await open(page,fixture({remaining:20}).data);
 const crit=page.locator('.ck-eng .qcell .qtxt.crit');
 await expect(crit).toHaveText('out ~40m');
 const [ink,low]=await page.evaluate(()=>{const e=document.querySelector('.ck-eng .qtxt.crit'),probe=document.createElement('i');probe.style.color='var(--st-low)';e.parentElement.append(probe);const r=[getComputedStyle(e).color,getComputedStyle(probe).color];probe.remove();return r;});
 expect(ink).toBe(low);
});

for(const [locale,label,updated,refresh] of [['en','Synthetic Pro 200','Updated 3 min ago','Refresh'],['zh-CN','Synthetic Pro 200','3 分钟前更新','刷新']])
 test(`CKP-ENG-27 the key carries the plan and one quiet updated line has Refresh (${locale})`,async({page})=>{
  const {data,row}=fixture();row.name={en:'Synthetic',zh:'Synthetic'};
  await open(page,data,locale);
  const name=page.locator('.eng-keys .ek[data-sub] .ek-name').first();
  await expect(name).toHaveAttribute('data-full',label);await expect(name).toHaveText(label);
  const line=page.locator('.ck-eng .eng-upd');
  await expect(line).toHaveCount(1);await expect(line.locator('.eng-upd-t')).toHaveText(updated);
  await expect(line.locator('button.eng-upd-r')).toHaveText(refresh);
  // Quiet: no stale mark or badge anywhere on the table.
  await expect(page.locator('.ck-eng .grey, .ck-eng [data-state="stale"]')).toHaveCount(0);
  const [table,lcd,box]=await Promise.all([page.locator('.u11-engine-table').boundingBox(),page.locator('.eng-lcd').boundingBox(),line.boundingBox()]);
  expect(box.y,'under the table').toBeGreaterThanOrEqual(lcd.y+lcd.height-1);
  expect(box.y+box.height,'inside the engine panel').toBeLessThanOrEqual(table.y+table.height+1);
 });

test('CKP-ENG-27 a plan the reader does not know leaves the name alone',async({page})=>{
 const {data,row}=fixture({plan:null});
 await open(page,data);
 await expect(page.locator('.eng-keys .ek[data-sub] .ek-name').first()).toHaveText(row.name.en);
});

test('CKP-ENG-27 Refresh asks native for all, or for the selected subscription; a scripted click asks for nothing',async({page})=>{
 const {data,account}=fixture();
 await open(page,data);
 const button=page.locator('.ck-eng button.eng-upd-r');
 await button.evaluate(b=>b.click());
 expect((await actions(page)).filter(a=>a.action!=='cautionAck'),'a scripted click asks for nothing (the lamp acknowledgement is the host\'s own report, not a request)').toEqual([]);
 await button.click();
 expect((await actions(page)).at(-1)).toEqual({action:'refreshMember',key:'all'});
 await page.keyboard.press('1');
 await expect(page.locator('.ck-eng button.eng-upd-r')).toHaveAccessibleName(/again/);
 await page.locator('.ck-eng button.eng-upd-r').click();
 expect((await actions(page)).at(-1)).toEqual({action:'refreshMember',key:account.subscriptionRef});
});
