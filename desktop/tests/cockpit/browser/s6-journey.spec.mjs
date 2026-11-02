// SPDX-License-Identifier: MIT
import { test, expect } from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import { appearance, commands, pageId, sample, shell } from '../fixture.mjs';

// These alert cases need a current producer-style window, not the expired
// timestamp in the shared historical Go capture.
function makeCurrent(account) {
 const deadline=new Date(Date.now()+3600000).toISOString();
 account.valueState='current';account.freshUntil=deadline;
 for(const w of account.windows){w.current=true;w.validUntil=deadline;w.resetsAt=null;}
}

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
  await expect(page.locator('.eng-cols .ec[data-col]:visible')).toHaveCount(6);
  await expect(page.locator('.eng-lcd:visible')).toContainText('5h');
  await expect(page.locator('.eng-lcd:visible')).toContainText('Weekly');
  await expect(page.locator('.eng-lcd:visible')).toContainText('Other');
  await page.getByRole('button',{name:'Page 2'}).click();
  await expect(page.locator('.eng-cols .ec[data-col]:visible')).toHaveCount(1);
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
  const cols=page.locator('.eng-cols .ec[data-col]:visible');await expect(cols).toHaveCount(2);
  expect(await page.locator('.s6-page:visible').evaluate(e=>e.style.getPropertyValue('--n'))).toBe('3');
  await expect(cols.nth(0).locator('.qcell').nth(0)).toBeEmpty();
  await expect(cols.nth(0).locator('.qcell').nth(1)).toBeEmpty();
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('18%');
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('mo');
  await expect(cols.nth(0).locator('.qcell').nth(2)).toContainText('3h00');
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
  const shutter=page.getByRole('button',{name:'舷窗快门'});await expect(shutter).toHaveAttribute('aria-pressed','false');
  const before=await page.locator('.ck-eng').boundingBox();await shutter.click();
  await page.getByRole('button',{name:'关闭',exact:true}).click();
  expect(await receive(send('shell',{profile:'closed',attached:false,forcedClosed:true,tier:'compact',scope:'all'}))).toBe(true);
  await expect(page.locator('.s6-closed-cap')).toBeVisible();await expect(shutter).toBeDisabled();
  await expect(page.locator('.ck-eng')).toBeVisible();await expect(page.locator('.ck-deck')).toBeVisible();
  expect((await page.locator('.s6-closed-cap').boundingBox()).height).toBe(16);
  expect((await page.locator('.ck-eng').boundingBox()).height).toBe(220);expect(before.height).toBe(226);
  await expect(page.locator('#s6-closed-reason')).toContainText('高度不足');
  await page.getByRole('button',{name:'放回',exact:true}).click();
  expect(await receive(send('shell',{profile:'closed',attached:false,forcedClosed:false,tier:'compact',scope:'all'}))).toBe(true);
  await expect(shutter).toBeEnabled();await expect(shutter).toHaveAttribute('aria-pressed','true');await shutter.click();
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
  await expect(page.getByRole('button',{name:'Porthole shutter'})).toBeDisabled();
  await expect(page.locator('#s6-closed-reason')).toContainText('Not enough window height');
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
  data.projection.rows=Array.from({length:7},(_,i)=>{const row=structuredClone(seed);row.id='tool'+i;row.name={en:'Tool '+i,zh:'工具 '+i};row.vendorKey=['openai','claude','cursor','copilot','kimi','glm','opencode'][i];row.accounts[0].subscriptionRef=null;makeCurrent(row.accounts[0]);row.accounts[0].windows[0].remainingPercent=i===6?15:70;return row;});
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.locator('.wordmark b')).toHaveCSS('color','rgb(223, 96, 76)');
  await expect(page.locator('.s6-page:visible img.vendor-mark')).toHaveCount(6);
  await expect(page.locator('.s6-page:visible .ek-name').first()).toHaveCSS('font-weight','500');
  await expect(page.locator('.hud')).toBeHidden();
  const quotaGeometry=await page.locator('.s6-page:visible .qnum').first().evaluate(e=>{const n=e.getBoundingClientRect(),r=e.closest('.qcell').getBoundingClientRect(),line=e.closest('.qline').getBoundingClientRect();return {number:n.height,line:line.height,cell:r.height};});
  expect(quotaGeometry.line).toBeGreaterThanOrEqual(quotaGeometry.number);expect(quotaGeometry.cell).toBeGreaterThanOrEqual(quotaGeometry.line);
  await expect(page.locator('.s6-page:visible .qrow-t')).toHaveCount(6);
  await expect(page.locator('.s6-page:visible .qrow-t').first()).toHaveAttribute('data-available','false');
  await expect(page.locator('.s6-page:visible img.vendor-mark').first()).toHaveCSS('width','16px');
  expect(await page.locator('.s6-page:visible .eng-keys .ek .bl').first().evaluate(e=>getComputedStyle(e).backgroundColor)).toBe('rgb(106, 168, 255)');
  await expect(page.locator('.s6-alert')).toContainText('ALERT');
  expect(await page.locator('.s6-page:visible img.vendor-mark').evaluateAll(imgs=>imgs.every(i=>i.complete&&i.naturalWidth>0))).toBe(true);
  await expect(page.getByRole('button',{name:'Page 2'})).toHaveClass(/lv-red/);
  const all=page.getByRole('button',{name:'All',exact:true}).first();await expect(all).toHaveAttribute('aria-pressed','true');
  expect(await all.locator('.bl').evaluate(e=>getComputedStyle(e).opacity)).toBe('1');
  await page.getByRole('button',{name:'Tool 0',exact:true}).click();
  await expect(all).toHaveAttribute('aria-pressed','false');expect(await all.locator('.bl').evaluate(e=>getComputedStyle(e).opacity)).toBe('0.22');
  let selected=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));expect(selected.action).toBe('scopeSelect');expect(selected.key).toBe('tool0#saved_login_api');
  expect(await receive(send('display',{data}))).toBe(true);await expect(page.getByRole('button',{name:'Tool 0',exact:true})).toHaveAttribute('aria-pressed','true');
  await page.getByRole('button',{name:'All',exact:true}).first().click();selected=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));expect(selected.key).toBe('all');
  await page.getByRole('button',{name:'Page 2'}).click();await expect(page.getByRole('button',{name:'Page 2'})).toHaveClass(/lv-red/);await expect(page.locator('.s6-page:visible img.vendor-mark')).toHaveCount(1);
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

test('live language changes update empty-state and paging accessibility copy',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  await expect(page.locator('.ck-eng')).toContainText('Waiting for display data');
  expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:false,reduceTransparency:false}))).toBe(true);
  await expect(page.locator('.ck-eng')).toContainText('等待显示数据');
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample(),seed=data.projection.rows[0];data.subscriptions=[];data.projection.rows=Array.from({length:7},(_,i)=>{const row=structuredClone(seed);row.id='tool'+i;row.accounts[0].subscriptionRef=null;return row;});
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.getByRole('button',{name:'第 2 页'})).toBeVisible();
  expect(await receive(send('appearance',{theme:'night',locale:'en',reduceMotion:false,reduceTransparency:false}))).toBe(true);
  await expect(page.getByRole('button',{name:'Page 2'})).toBeVisible();
  expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
  await expect(page.locator('.ck-eng')).toContainText('Display data cleared');
  expect(await receive(send('appearance',{viewRevision:'4',theme:'night',locale:'zh-CN',reduceMotion:false,reduceTransparency:false}))).toBe(true);
  await expect(page.locator('.ck-eng')).toContainText('显示数据已清除');
});

test('v1 strip uses a brand mark and equal icon keys with localized accessible names',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  await expect(page.locator('.ck-brand .s6-brand-mark')).toBeVisible();
  expect(await page.locator('.s6-brand-mark').evaluate(e=>getComputedStyle(e).backgroundImage)).toContain('brand-mark.svg');
  expect(await page.locator('.s6-brand-mark').evaluate(e=>['::before','::after'].map(p=>getComputedStyle(e,p).content))).toEqual(['none','none']);
  const settings=page.getByRole('button',{name:'Settings',exact:true}),detach=page.getByRole('button',{name:'Detach',exact:true}),close=page.getByRole('button',{name:'Close',exact:true});
  await expect(close).toHaveText('');expect(await close.evaluate(e=>getComputedStyle(e,'::before').backgroundImage)).toContain('close-normal');await expect(settings).not.toHaveText('Settings');await expect(detach).not.toHaveText('Detach');
  const sizes=await Promise.all([settings,detach,close].map(b=>b.boundingBox()));expect(sizes.every(r=>r.width===sizes[0].width&&r.height===sizes[0].height)).toBe(true);
  expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:false,reduceTransparency:false}))).toBe(true);
  await expect(page.getByRole('button',{name:'设置',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'分离',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'关闭',exact:true})).toHaveText('');
  await expect(page.getByText('ALERT',{exact:true})).toBeVisible();
  await expect(page.locator('.s6-alert')).toHaveAttribute('aria-label','告警未激活');
});


test('shutter supports drag and keyboard without toggling twice',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance:{...appearance,reduceMotion:true},shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const shutter=page.getByRole('button',{name:'Porthole shutter'}),box=await shutter.boundingBox();
  await page.mouse.move(box.x+20,box.y+15);await page.mouse.down();await page.mouse.move(box.x+120,box.y+15,{steps:4});await page.mouse.up();
  expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['shutterToggle']);
  expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
  await expect(shutter).toHaveAttribute('aria-pressed','true');
  expect(await page.locator('.shutter-thumb').evaluate(e=>getComputedStyle(e).transitionDuration)).toBe('0s');
  await shutter.focus();await page.keyboard.press('ArrowLeft');
  expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['shutterToggle','shutterToggle']);
});

test('study faders and MFD retain empty states without invented cockpit details',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const mfdData=sample();mfdData.projection.rows[0].accounts[0].valueState='retained';
  expect(await receive(send('display',{data:mfdData}))).toBe(true);
  await expect(page.locator('.dk-fad')).toBeVisible();await expect(page.locator('.fd-ch.empty')).toHaveCount(3);
  await expect(page.locator('.fd-strip:disabled')).toHaveCount(3);await expect(page.locator('#cockpit')).toHaveAttribute('data-details-available','false');
  await expect(page.locator('.mfd-page')).toHaveText('Quota only');await page.getByRole('button',{name:'Plans',exact:true}).click();
  await expect(page.getByRole('button',{name:'Plans',exact:true})).toHaveAttribute('aria-pressed','true');
  await expect(page.locator('.mfd-page .sa-list .sa')).toHaveCount(4);await expect(page.locator('.mfd-page')).toContainText('75%');await expect(page.locator('.mfd-page')).toContainText('Last known reading');
  const verified=sample().projection.rows[0].accounts[0].subscriptionRef;
  expect(await receive(send('shell',{...shell,scope:verified}))).toBe(true);await expect(page.locator('.mfd-page .sp-now')).toHaveCount(1);
  expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);await expect(page.locator('.mfd-page .sa-list .sa')).toHaveCount(4);
  expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false}))).toBe(true);
  await expect(page.getByRole('button',{name:'订阅',exact:true})).toHaveAttribute('aria-pressed','true');await expect(page.locator('.mfd-page')).toContainText('模拟方案');await expect(page.locator('.mfd-page')).toContainText('上次读数');
  expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(page.getByRole('button',{name:'总览',exact:true})).toHaveAttribute('aria-pressed','true');await expect(page.locator('.mfd-page .sp-now')).toHaveCount(0);
});

test('record strip preserves unknown live-session coverage across tier and clear',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  expect(await receive(send('display',{data:sample()}))).toBe(true);await expect(page.locator('.ck-tape .t-blank')).toHaveCount(5);
  await expect(page.locator('.ck-tape')).toHaveAttribute('data-sessions-available','false');await expect(page.locator('.ck-tape')).toHaveAttribute('aria-label','Live session coverage unavailable');
  expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);await expect(page.locator('.ck-tape .t-blank')).toHaveCount(3);
  expect(await receive(send('appearance',{theme:'night',locale:'zh-CN',reduceMotion:true,reduceTransparency:false}))).toBe(true);
  await expect(page.locator('.ck-tape')).toHaveAttribute('aria-label','实时会话覆盖情况不可用');
  expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);await expect(page.locator('.ck-tape .t-blank')).toHaveCount(3);
  await expect(page.locator('.ck-tape .tl:not(.t-blank)')).toHaveCount(0);
});

test('macrev-403-2: colliding unverified members remain distinct through paging and refresh',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample(),row=data.projection.rows[0];data.subscriptions=[];row.accounts[0].subscriptionRef=null;row.accounts[0].windows[0].remainingPercent=18;
  const second=structuredClone(row.accounts[0]);second.subscriptionRef='fedcba9876543210';second.windows[0].remainingPercent=75;row.accounts.push(second);
  const seed=structuredClone(row);seed.accounts=[structuredClone(row.accounts[0])];data.projection.rows=[row,...Array.from({length:5},(_,i)=>{const r=structuredClone(seed);r.id='other'+i;r.name={en:'Other '+i,zh:'其他 '+i};return r;})];
  expect(await receive(send('display',{data}))).toBe(true);
  const first=page.locator('.s6-page:visible .ec').nth(0),other=page.locator('.s6-page:visible .ec').nth(1);
  await expect(first).toContainText('18%');await expect(other).toContainText('75%');
  const keys=page.locator('.s6-page:visible .eng-keys button');await expect(keys).toHaveCount(6);
  await expect(keys.nth(0)).toHaveAttribute('data-scope','codex#saved_login_api#1');await expect(keys.nth(1)).toHaveAttribute('data-scope','codex#saved_login_api#2');
  await keys.nth(1).click();expect(await page.evaluate(()=>window.__events.filter(e=>e.action==='scopeSelect').at(-1).key)).toBe('codex#saved_login_api#2');
  await page.getByRole('button',{name:'Page 2'}).click();await page.getByRole('button',{name:'Page 1'}).click();
  await expect(page.locator('.s6-page:visible .eng-keys button').nth(1)).toHaveAttribute('aria-pressed','true');
  row.accounts.reverse();expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.locator('.s6-page:visible .ec').nth(0)).toContainText('75%');await expect(page.locator('.s6-page:visible .ec').nth(1)).toContainText('18%');
  await expect(page.getByRole('button',{name:'All',exact:true}).first()).toHaveAttribute('aria-pressed','true');
  expect(await receive(send('shell',{...shell,scope:'codex#saved_login_api#1'}))).toBe(true);
  await expect(page.locator('.s6-page:visible .eng-keys button').nth(0)).toHaveAttribute('aria-pressed','true');
});

test('macrev2-403-6: only general known 5h and weekly windows occupy named rows',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample();data.projection.rows=[data.projection.rows[0]];data.subscriptions=[];
  const account=data.projection.rows[0].accounts[0],seed=account.windows[0];account.subscriptionRef=null;
  const show=async windows=>{account.windows=windows;expect(await receive(send('display',{data}))).toBe(true);return page.locator('.s6-page:visible .ec').first().locator('.qcell');};
  for(const [role,duration,index] of [['session',18000,0],['weekly',604800,1]]){
    const general={...structuredClone(seed),role,durationSeconds:duration,limitKey:'main',poolKey:'main',remainingPercent:75};delete general.modelScope;
    const restricted={...structuredClone(general),limitKey:'code_review',poolKey:'code_review',modelScope:{models:['opus']},remainingPercent:1};
    for(const pair of [[restricted,general],[general,restricted]]){const cells=await show(pair);await expect(cells.nth(index)).toContainText('75%');await expect(cells.nth(2)).toContainText('1%');}
    const namedPool={...structuredClone(general),limitKey:'code_review',poolKey:'code_review',remainingPercent:2};
    for(const pair of [[namedPool,general],[general,namedPool]]){const cells=await show(pair);await expect(cells.nth(index)).toContainText('75%');await expect(cells.nth(2)).toContainText('2%');}
    const poolOnly={...structuredClone(general),poolKey:'code_review',remainingPercent:3};const poolCells=await show([poolOnly]);await expect(poolCells.nth(index)).toBeEmpty();await expect(poolCells.nth(2)).toContainText('3%');
    const alias={...structuredClone(general),limitKey:role==='session'?'five_hour':'weekly'};const aliasCells=await show([alias]);await expect(aliasCells.nth(index)).toContainText('75%');
    const wrongAlias={...structuredClone(general),limitKey:role==='session'?'weekly':'five_hour',remainingPercent:4};const wrongCells=await show([wrongAlias]);await expect(wrongCells.nth(index)).toBeEmpty();await expect(wrongCells.nth(2)).toContainText('4%');
    const cells=await show([restricted]);await expect(cells.nth(index)).toBeEmpty();await expect(cells.nth(2)).toContainText('1%');
    const unknownModel={...restricted,modelScope:{models:['unknown']}};const unknownModelCells=await show([unknownModel]);await expect(unknownModelCells.nth(index)).toBeEmpty();await expect(unknownModelCells.nth(2)).toContainText('1%');
    const unknown={...structuredClone(general),limitKey:'other',remainingPercent:8};const unknownCells=await show([unknown]);await expect(unknownCells.nth(index)).toBeEmpty();await expect(unknownCells.nth(2)).toContainText('8%');
    const future={...structuredClone(general),limitKey:'unrecognized',remainingPercent:9};const futureCells=await show([future]);await expect(futureCells.nth(index)).toBeEmpty();await expect(futureCells.nth(2)).toContainText('9%');
  }
  const roleUnknown={...structuredClone(seed),role:'other',durationSeconds:604800,limitKey:'main',remainingPercent:12};const cells=await show([roleUnknown]);await expect(cells.nth(1)).toBeEmpty();await expect(cells.nth(2)).toContainText('12%');
  const invalid={...roleUnknown,modelScope:{models:[]}};account.windows=[invalid];expect(await receive(send('display',{data}))).toBe(false);
});

test('verified scope remains selected across a display refresh',async({page})=>{
  await page.setViewportSize({width:636,height:890});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample();expect(await receive(send('display',{data}))).toBe(true);
  await page.getByRole('button',{name:'Codex',exact:true}).click();expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.getByRole('button',{name:'Codex',exact:true})).toHaveAttribute('aria-pressed','true');
});

test('clearing the display also clears its derived threshold alert',async({page})=>{
  await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
  const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
  expect(await receive(send('load',{appearance,shell}))).toBe(true);
  expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
  const data=sample();makeCurrent(data.projection.rows[0].accounts[0]);data.projection.rows[0].accounts[0].windows[0].remainingPercent=10;
  expect(await receive(send('display',{data}))).toBe(true);
  await expect(page.locator('.s6-alert')).toHaveClass(/lit/);
  expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
  await expect(page.locator('.s6-alert')).not.toHaveClass(/lit|red|amber/);
  await expect(page.locator('.s6-alert')).toHaveAttribute('aria-label','Alert inactive');
});
