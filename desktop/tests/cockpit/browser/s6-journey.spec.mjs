// SPDX-License-Identifier: MIT
import { test, expect } from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import { appearance, commands, pageId, sample, shell } from '../fixture.mjs';

test('built cockpit entry displays subscription columns and pages from wire data', async ({page}) => {
  await page.setViewportSize({width:636,height:890});
  await page.goto('/?pageId='+pageId);
  await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands();
  const receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample(), seed=data.projection.rows[0];
  data.projection.rows=Array.from({length:7},(_,i)=>{
    const row=structuredClone(seed);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};
    row.accounts[0].subscriptionRef=i.toString(16).padStart(16,'0');
    row.accounts[0].windows[0].durationSeconds=18000;
    return row;
  });
  data.subscriptions=[];
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.locator('.eng-cols .ec:visible')).toHaveCount(6);
  await expect(page.locator('.eng-lcd:visible')).toContainText('5h');
  await expect(page.locator('.eng-lcd:visible')).toContainText('Weekly');
  await expect(page.locator('.eng-lcd:visible')).toContainText('Other');
  await page.getByRole('button',{name:'Page 2'}).click();
  await expect(page.locator('.eng-cols .ec:visible')).toHaveCount(1);
  await expect(page.locator('.eng-krow:visible')).toContainText('Tool 6');
  await page.getByRole('button',{name:'Tool 6'}).click();
  await expect(page.getByRole('button',{name:'Tool 6'})).toHaveAttribute('aria-pressed','true');
});

test('account members get separate c3 columns and monthly-only readings stay in Other', async ({page}) => {
  await page.setViewportSize({width:636,height:890});
  await page.clock.setFixedTime(new Date('2026-11-01T02:00:00Z'));
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample(),row=data.projection.rows[0];data.projection.rows=[row];data.subscriptions=[];
  const monthly=row.accounts[0];monthly.subscriptionRef=null;monthly.route='saved_login_api';monthly.windows[0].role='monthly';monthly.windows[0].durationSeconds=2592000;monthly.windows[0].remainingPercent=18;monthly.windows[0].resetsAt='2026-11-01T05:00:00Z';
  const weekly=structuredClone(monthly);weekly.route='runtime_rpc';weekly.windows[0].role='weekly';weekly.windows[0].durationSeconds=604800;weekly.windows[0].remainingPercent=75;row.accounts.push(weekly);
  expect(await receive(send('display',{data}))).toBe(true);
  const cols=page.locator('.eng-cols .ec:visible');await expect(cols).toHaveCount(2);
  expect(await page.locator('.s6-page:visible').evaluate(e=>e.style.getPropertyValue('--n'))).toBe('3');
  await expect(cols.nth(0).locator('.qcell').nth(0)).toBeEmpty();
  await expect(cols.nth(0).locator('.qcell').nth(1)).toBeEmpty();
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('18%');
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('mo');
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('resets in 3h');
  await expect(cols.nth(1).locator('.qcell').nth(1)).toContainText('75%');
  expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
  await expect(page.locator('.eng-cols .ec')).toHaveCount(0);
});

test('v2 host messages update the built page and shell controls emit native actions',async({page})=>{
  await page.setViewportSize({width:636,height:890});
  await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  const ready=await page.evaluate(()=>window.__events.find(e=>e.type==='ready'));
  expect(ready.appearanceVersion).toBe(2);expect(ready.capabilities).toEqual(['appearanceUpdates','shellState','shellActions']);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:sample()}))).toBe(true);
  expect(await receive(send('appearance',{theme:'day',locale:'zh-CN',reduceMotion:true,reduceTransparency:true}))).toBe(true);
  await expect(page.locator('.eng-lcd')).toContainText('每周');await expect(page.locator('.eng-cols .ec')).toHaveCount(4);
  expect(await page.locator('html').getAttribute('data-theme')).toBe('night');
  expect(await page.locator('html').getAttribute('data-reduce-motion')).toBe('true');
  expect(await receive(send('appearance',{theme:'night',locale:'en',reduceMotion:false,reduceTransparency:false,extra:true}))).toBe(false);
  expect(await receive(send('shell',{profile:'open',attached:true,forcedClosed:false,tier:'tall',scope:'all'}))).toBe(true);
  await page.getByRole('button',{name:'分离',exact:true}).click();
  await page.getByRole('button',{name:'收起',exact:true}).click();
  await page.getByRole('button',{name:'关闭',exact:true}).click();
  expect(await receive(send('shell',{profile:'closed',attached:false,forcedClosed:true,tier:'compact',scope:'all'}))).toBe(true);
  await expect(page.locator('.s6-closed-cap')).toBeVisible();await expect(page.getByRole('button',{name:'打开驾驶舱'})).toBeDisabled();
  await expect(page.locator('#s6-closed-reason')).toContainText('高度不足');
  await page.getByRole('button',{name:'放回',exact:true}).click();
  expect(await receive(send('shell',{profile:'closed',attached:false,forcedClosed:false,tier:'compact',scope:'all'}))).toBe(true);
  await page.getByRole('button',{name:'打开驾驶舱'}).click();
  expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['detach','shutterToggle','close','putBack','shutterToggle']);
  expect(await receive(send('shell',{profile:'open',attached:true,forcedClosed:false,tier:'tall',scope:'all'}))).toBe(true);
  await expect(page.locator('.eng-cols .ec')).toHaveCount(4);await expect(page.locator('.s6-closed-cap')).toBeHidden();
});

test('initial compact closed shell and later tall tier select independent layouts',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell:{profile:'closed',attached:false,forcedClosed:true,tier:'compact',scope:'all'}}))).toBe(true);
  await expect(page.locator('#cockpit')).toHaveAttribute('data-layout','640');
  await expect(page.locator('#cockpit')).toHaveAttribute('data-shell','closed');
  await expect(page.locator('.s6-closed-cap')).toBeVisible();
  await expect(page.getByRole('button',{name:'Open Cockpit'})).toBeDisabled();
  expect(await receive(send('shell',{profile:'open',attached:true,forcedClosed:false,tier:'tall',scope:'all'}))).toBe(true);
  await expect(page.locator('#cockpit')).toHaveAttribute('data-layout','890');
  await expect(page.locator('#cockpit')).toHaveAttribute('data-shell','open');
  await expect(page.locator('.s6-closed-cap')).toBeHidden();
  expect(await receive(send('shell',{profile:'open',attached:true,forcedClosed:false,tier:'full',scope:'all'}))).toBe(false);
});

test('wordmark, vendor marks, off-page caution and scope actions follow the actual display',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample(),seed=data.projection.rows[0];data.subscriptions=[];
  data.projection.rows=Array.from({length:7},(_,i)=>{const row=structuredClone(seed);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.vendorKey=['openai','claude','cursor','copilot','kimi','glm','opencode'][i];row.accounts[0].subscriptionRef=null;row.accounts[0].windows[0].remainingPercent=i===6?15:70;return row;});
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.locator('.wordmark b')).toHaveCSS('color','rgb(223, 96, 76)');
  await expect(page.locator('.s6-page:visible img.vendor-mark')).toHaveCount(6);
  expect(await page.locator('.s6-page:visible img.vendor-mark').evaluateAll(imgs=>imgs.every(i=>i.complete&&i.naturalWidth>0))).toBe(true);
  await expect(page.getByRole('button',{name:'Page 2'})).toHaveClass(/lv-red/);
  const all=page.getByRole('button',{name:'All',exact:true}).first();await expect(all).toHaveAttribute('aria-pressed','true');
  expect(await all.evaluate(e=>getComputedStyle(e,'::after').opacity)).toBe('1');
  await page.getByRole('button',{name:'Tool 0',exact:true}).click();
  await expect(all).toHaveAttribute('aria-pressed','false');expect(await all.evaluate(e=>getComputedStyle(e,'::after').opacity)).toBe('0.22');
  let selected=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));expect(selected.action).toBe('scopeSelect');expect(selected.key).toBe('tool0#saved_login_api');
  expect(await receive(send('display',{data}))).toBe(true);await expect(page.getByRole('button',{name:'Tool 0',exact:true})).toHaveAttribute('aria-pressed','true');
  await page.getByRole('button',{name:'All',exact:true}).first().click();selected=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));expect(selected.key).toBe('all');
  await page.getByRole('button',{name:'Page 2'}).click();await expect(page.getByRole('button',{name:'Page 2'})).not.toHaveClass(/lv-red/);await expect(page.locator('.s6-page:visible img.vendor-mark')).toHaveCount(1);
});

test('native session scope is restored on load and shell updates without emitting an action',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  const data=sample(),key=data.projection.rows[0].accounts[0].subscriptionRef;
  expect(await receive(send('load',{appearance,shell:{...shell,scope:key}}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.getByRole('button',{name:'Codex',exact:true})).toHaveAttribute('aria-pressed','true');
  expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').length)).toBe(0);
  expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);
  await expect(page.getByRole('button',{name:'All',exact:true}).first()).toHaveAttribute('aria-pressed','true');
  expect(await receive(send('shell',{...shell,scope:'invalid/member'}))).toBe(false);
});
