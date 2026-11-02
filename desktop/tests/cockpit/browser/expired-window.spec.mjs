// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {commands,pageId,appearance,shell,sample} from '../fixture.mjs';

for(const withDetails of [false,true]){
 test(`expired 5h reading cannot raise a current alarm (${withDetails?'details':'no details'})`,async({page})=>{
  await page.clock.setFixedTime(new Date('2026-10-29T12:00:00Z'));
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=sample();
  const row=data.projection.rows[0],account=row.accounts[0],seed=account.windows[0];data.projection.rows=[row];
  account.valueState='current';account.windows=[
   {...seed,id:'expired-five-hour',role:'session',durationSeconds:18000,label:{en:'5h',zh:'5小时'},remainingPercent:0,current:false,observedAt:'2026-10-29T11:00:00Z',resetsAt:'2026-10-29T11:59:59Z',validUntil:'2026-10-29T11:59:59Z'},
   {...seed,id:'current-weekly',role:'weekly',durationSeconds:604800,label:{en:'Weekly',zh:'每周'},remainingPercent:80,current:true,observedAt:'2026-10-29T11:00:00Z',resetsAt:'2026-11-05T12:00:00Z',validUntil:'2026-10-29T13:00:00Z'}
  ];
  if(withDetails)data.details={version:1,sources:['quota-thresholds'],subscriptions:[],sessions:[],sessionCoverage:'unavailable',resetEvents:[],alerts:[]};
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data}))).toBe(true);
  const first=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="first"]'),weekly=page.locator('.eng-cols .ec').first().locator('.qcell[data-row="second"]');
  await expect(first).not.toHaveClass(/lv-low/);await expect(first.locator('.qvalue')).not.toHaveText('0');
  await expect(weekly.locator('.qvalue')).toHaveText('80');await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red|amber/);
  await expect(page.locator('.mfd-page .al-red')).toHaveCount(0);
  expect(await receive(send('shell',{...shell,scope:account.subscriptionRef}))).toBe(true);
  await page.getByRole('button',{name:'Subscription',exact:true}).click();
  const windows=page.locator('.mfd-page .sp-w');await expect(windows.filter({hasText:'Weekly'})).toContainText('80%');
  await expect(windows.filter({hasText:'5h'})).not.toContainText('0%');
  // A genuine current zero remains critical; after its deadline the same
  // previously current producer observation and alert must stop alarming.
  expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);
  await page.getByRole('button',{name:'Overview',exact:true}).click();
  account.windows[0].current=true;account.windows[0].resetsAt='2026-10-29T13:00:00Z';account.windows[0].validUntil='2026-10-29T13:00:00Z';
  if(withDetails)data.details.alerts=[{source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[0].id,severity:'critical',remainingPercent:0}];
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(first).toHaveClass(/lv-low/);await expect(first.locator('.qvalue')).toHaveText('0');
  await expect(page.locator('.s6-alert')).toHaveClass(/lit/);await expect(page.locator('.s6-alert')).toHaveClass(/red/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(1);
  account.windows[0].validUntil='2026-10-29T12:00:00Z';
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(first).not.toHaveClass(/lv-low/);await expect(weekly.locator('.qvalue')).toHaveText('80');
  await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red|amber/);await expect(page.locator('.mfd-page .al-red')).toHaveCount(0);
 });
}
