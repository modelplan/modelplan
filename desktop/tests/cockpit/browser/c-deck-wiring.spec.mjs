// SPDX-License-Identifier: MIT
// Public-screen wiring of facts the producer already admits, through the built page and its normal bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,data) {
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const until='2030-01-01T00:00:00Z';
function oneSubscription(){
 const data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions=data.details.subscriptions.slice(0,1);
 const row=data.projection.rows[0],account=row.accounts[0],seed=account.windows[0];
 const general={...seed,id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main',label:{en:'5h',zh:'5小时'},remainingPercent:60,current:true,validUntil:until,resetsAt:'2026-11-04T14:00:00Z'};
 const scoped={...seed,id:'weekly:604800:main:main:1',role:'weekly',durationSeconds:604800,limitKey:'main',poolKey:'main',modelScope:{models:['opus']},label:{en:'Opus weekly',zh:'Opus 每周'},remainingPercent:10,current:true,validUntil:until,resetsAt:'2026-11-08T00:00:00Z'};
 delete general.modelScope;account.windows=[general,scoped];
 return {data,row,account};
}

// Prototype: mfd-pages/plans.js:31-35,115 (scoped 专项 lines under their subscription; proposed CKP-MFD-29).
test('CKP-MFD-10 scoped extra windows list under their subscription and never become the plan-wide tightest',async({page})=>{
 const {data}=oneSubscription();
 await open(page,data);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 const item=page.locator('.sa-list .sa').first();
 await expect(item.locator('.v')).toHaveText('60%');
 const extra=page.locator('.sa-list .sa-x');await expect(extra).toHaveCount(1);
 await expect(extra.locator('b')).toHaveText('Opus weekly');await expect(extra.locator('.v')).toHaveText('10%');
 await item.click();
 await expect(page.locator('.sp-w.x')).toHaveCount(1);
 await expect(page.locator('.sp-w:not(.x) .lbl')).toHaveText(['5h']);
});

// Prototype: mfd-pages/where.js:25-39 (时间 list, running first); public v1 shows the bounded last-seen part only.
test('CKP-MFD-23 the time list shows admitted last-seen sessions without claiming an end or tokens',async({page})=>{
 const {data,account}=oneSubscription();
 data.details.sessionCoverage='local-last-seen';
 data.details.sessions=[
  {sessionRef:'00000000000000a1',source:'Codex',subscriptionRef:account.subscriptionRef,model:'Sol 6.1',effort:'High',projectLabel:'alpha',lastObservedAt:'2026-11-04T11:59:00Z',state:'running',rate:41},
  {sessionRef:'00000000000000a2',source:'Claude',subscriptionRef:null,model:'Opus 5.5',effort:null,projectLabel:null,lastObservedAt:'2026-11-03T09:30:00Z',state:'idle',rate:null},
  {sessionRef:'00000000000000a3',source:'Claude',subscriptionRef:null,model:'Opus 5.5',effort:null,projectLabel:null,lastObservedAt:'2026-10-01T09:30:00Z',state:'idle',rate:null},
 ];
 const {send,receive}=await open(page,data);
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await page.locator('.mfd-ok [data-opt="where"] [data-choice="time"]').click();
 await page.locator('.mfd-ok [data-opt="time"] [data-choice="7d"]').click();
 const rows=page.locator('.ws-list .ws');await expect(rows).toHaveCount(2);
 await expect(page.locator('.ws-list .ws-h')).toHaveText(['Running 1','Last seen 1']);
 // glm-608-2: the rows have no action, so they do not offer one to the keyboard.
 await expect(page.locator('.ws-list .ws').first()).toHaveAttribute('aria-disabled','true');await expect(page.locator('.ws-list .ws').first()).toHaveAttribute('tabindex','-1');
 await expect(page.locator('.ws-list')).not.toContainText('Ended');
 await expect(rows.first()).toHaveClass(/\brun\b/);await expect(rows.first().locator('.ws-p')).toHaveText('alpha');
 await expect(rows.nth(1).locator('.ws-tk')).toHaveText('--');
 // An unbound session belongs to All only; a subscription scope shows its bound session.
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.sa-list .sa').first().click();
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await expect(page.locator('.ws-list .ws')).toHaveCount(1);
 // Recording off: the list is unavailable, not an empty period.
 data.details.sessionCoverage='recording-off';data.details.sessions=[];
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.mfd-page .mp-empty')).toHaveText('Data unavailable');
});
