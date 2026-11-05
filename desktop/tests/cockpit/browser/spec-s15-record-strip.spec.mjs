// SPDX-License-Identifier: MIT
// S15/S19: production page with synthetic cockpit details, including producer states.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.details.sessions[0].rate=58;data.details.sessions[2].state='idle';data.details.sessions[2].rate=99;data.details.sessions.reverse();
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 return {send,receive,data};
}

test('S15 live-session last-seen strip uses real producer states, locale, overflow and clearing',async({page})=>{
 const {send,receive,data}=await open(page),rows=page.locator('.ck-tape .t-observed');
 for(const tier of ['tall','compact']){
  expect(await receive(send('shell',{...shell,tier}))).toBe(true);
  for(const locale of ['en','zh-CN']){
   expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
   await expect(rows).toHaveCount(3);await expect(rows.nth(0).locator('.t-time')).toContainText(locale==='en'?'Running':'运行中');
   await expect(rows.nth(1).locator('.t-time')).toContainText(locale==='en'?'Running':'运行中');
   await expect(rows.nth(2).locator('.t-model')).toHaveText('GLM-5.3');await expect(rows.nth(2).locator('.t-time')).toHaveText(locale==='en'?'Last seen':'最近观察');
   await expect(rows.nth(2).locator('.t-live')).toHaveText('--');await expect(rows.nth(2)).not.toContainText(/ended|stopped|已结束/);
   for(const label of await rows.locator('.t-time').all()){const size=await label.evaluate(e=>({scroll:e.scrollWidth,client:e.clientWidth}));expect(size.scroll).toBeLessThanOrEqual(size.client);}
  }
 }
 const running=data.details.sessions.find(s=>s.state==='running'),idle=data.details.sessions.find(s=>s.state==='idle');
 data.details.sessions.push({...idle,sessionRef:'0000000000000004'},{...idle,sessionRef:'0000000000000005'},{...idle,sessionRef:'0000000000000006'},{...idle,sessionRef:'0000000000000007',state:'future-state'});
 expect(await receive(send('appearance',{...appearance,locale:'en'}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(2);await expect(page.locator('.ck-tape .t-overflow')).toHaveText('4 more sessions');
 data.details.sessions=Array.from({length:7},(_,i)=>({...running,sessionRef:(i+1).toString(16).padStart(16,'0')}));
 expect(await receive(send('shell',{...shell,tier:'tall'}))).toBe(true);expect(await receive(send('display',{data}))).toBe(true);
 await expect(rows).toHaveCount(4);await expect(page.locator('.ck-tape .t-overflow')).toContainText('3');
 data.details.sessionCoverage='unavailable';expect(await receive(send('display',{data}))).toBe(true);await expect(rows).toHaveCount(0);
 expect(await receive(send('clear',{generation:'42',viewRevision:'4'}))).toBe(true);await expect(page.locator('.ck-tape')).not.toContainText('GLM-5.3');
});

test('S15 compact strip keeps three rows and overflow visible within its inner bounds in both locales',async({page})=>{
 await page.setViewportSize({width:636,height:640});
 const {send,receive,data}=await open(page),strip=page.locator('.ck-tape');
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
 for(const locale of ['en','zh-CN']){
  expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
  for(const overflow of [false,true]){
   const sessions=data.details.sessions.slice(0,3);
   data.details.sessions=overflow?[...sessions,...Array.from({length:3},(_,i)=>({...sessions[0],sessionRef:(i+4).toString(16).padStart(16,'0')}))]:sessions;
   expect(await receive(send('display',{data}))).toBe(true);
   const rows=strip.locator('.tl');await expect(rows).toHaveCount(3);
   if(overflow)await expect(strip.locator('.t-overflow')).toHaveCount(1);else await expect(strip.locator('.t-overflow')).toHaveCount(0);
   const metrics=await strip.evaluate(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {top:r.top+parseFloat(s.paddingTop),bottom:r.bottom-parseFloat(s.paddingBottom),scroll:e.scrollHeight,client:e.clientHeight};});
   for(const row of await rows.all())for(const item of [row,...await row.locator('.t-time').all()]){const box=await item.boundingBox();expect(box.y).toBeGreaterThanOrEqual(metrics.top-0.5);expect(box.y+box.height).toBeLessThanOrEqual(metrics.bottom+0.5);}
   expect(metrics.scroll).toBeLessThanOrEqual(metrics.client);
  }
 }
});

test('S15 S19 running cursors animate only for visible active sessions and become static under Reduce Motion',async({page})=>{
 const {send,receive,data}=await open(page),cursors=page.locator('.ck-tape .t-cur');await expect(cursors).toHaveCount(2);
 const details=await cursors.first().evaluate(e=>{const s=getComputedStyle(e);return {name:s.animationName,duration:s.animationDuration,count:s.animationIterationCount,width:s.width,height:s.height}});
 expect(details).toEqual({name:'cockpit-running-cursor',duration:'1.06s',count:'infinite',width:'6px',height:'11px'});
 expect(await receive(send('appearance',{...appearance,reduceMotion:true}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 expect(await receive(send('appearance',appearance))).toBe(true);await page.emulateMedia({reducedMotion:'reduce'});expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 await page.emulateMedia({reducedMotion:'no-preference'});expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');expect(await receive(send('shell',shell))).toBe(true);expect(await receive(send('visibility',{visible:false,occluded:false,key:false}))).toBe(true);expect(await cursors.first().evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);for(const s of data.details.sessions)s.state='idle';expect(await receive(send('display',{data}))).toBe(true);await expect(cursors).toHaveCount(0);
});

test('S17 Option help describes the available last-seen strip without promising session details',async({page})=>{
 const {send,receive}=await open(page),map=page.locator('#help-map');
 for(const [locale,expected] of [['en','Running sessions first, then last seen; -- means speed unavailable.'],['zh-CN','运行中的会话在前，其后为最近观察；-- 表示速率不可用。']]){
  expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);await page.keyboard.down('Alt');
  await expect(map.locator('[data-target=".ck-tape"]')).toHaveText(expected);await page.keyboard.up('Alt');await expect(map).toBeHidden();
 }
});
