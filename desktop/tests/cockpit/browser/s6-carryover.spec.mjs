// SPDX-License-Identifier: MIT
// Adapted from #403 macrev2-403-6: classify real, current synthetic windows
// through the built page, including producer limit and model-scope variants.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('named 5h and weekly rows exclude restricted, special and unknown pools',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=currentSample();data.projection.rows=[data.projection.rows[0]];data.subscriptions=[];
 const account=data.projection.rows[0].accounts[0],seed=account.windows[0];account.subscriptionRef=null;
 const show=async(windows)=>{account.windows=windows;expect(await receive(send('display',{data}))).toBe(true);return page.locator('.eng-cols .ec').first();};
 for(const [role,duration,row,alias,wrong] of [['session',18000,'first','five_hour','weekly'],['weekly',604800,'second','weekly','five_hour']]){
  const general={...structuredClone(seed),id:`${role}:${duration}:main:main`,role,durationSeconds:duration,limitKey:'main',poolKey:'main',remainingPercent:75};delete general.modelScope;
  const restricted={...structuredClone(general),id:`${role}:${duration}:code_review:code_review`,limitKey:'code_review',poolKey:'code_review',modelScope:{models:['opus']},remainingPercent:1};
  for(const pair of [[restricted,general],[general,restricted]]){const col=await show(pair);await expect(col.locator(`.qcell[data-row=${row}] .qvalue`)).toHaveText('75');await expect(col.locator('.qcell[data-row=other] .qvalue')).toHaveText('1');}
  const named={...restricted,modelScope:undefined,remainingPercent:2};delete named.modelScope;
  for(const pair of [[named,general],[general,named]]){const col=await show(pair);await expect(col.locator(`.qcell[data-row=${row}] .qvalue`)).toHaveText('75');await expect(col.locator('.qcell[data-row=other] .qvalue')).toHaveText('2');}
  for(const [field,value,percent] of [['poolKey','code_review',3],['limitKey',wrong,4],['limitKey','other',8],['limitKey','unrecognized',9]]){
   const item={...general,[field]:value,remainingPercent:percent};const col=await show([item]);await expect(col.locator(`.qcell[data-row=${row}]`)).toBeEmpty();await expect(col.locator('.qcell[data-row=other] .qvalue')).toHaveText(String(percent));
  }
  const accepted={...general,limitKey:alias};const col=await show([accepted]);await expect(col.locator(`.qcell[data-row=${row}] .qvalue`)).toHaveText('75');
  const modelUnknown={...restricted,modelScope:{models:['unknown']}};const unknown=await show([modelUnknown]);await expect(unknown.locator(`.qcell[data-row=${row}]`)).toBeEmpty();await expect(unknown.locator('.qcell[data-row=other] .qvalue')).toHaveText('1');
 }
 const other={...seed,id:'other:604800:main:main',role:'other',durationSeconds:604800,limitKey:'main',poolKey:'main',remainingPercent:12};delete other.modelScope;
 const col=await show([other]);await expect(col.locator('.qcell[data-row=second]')).toBeEmpty();await expect(col.locator('.qcell[data-row=other] .qvalue')).toHaveText('12');
 account.windows=[{...other,modelScope:{models:[]}}];expect(await receive(send('display',{data}))).toBe(false);
});

test('native scope load and shell updates do not emit selection actions',async({page})=>{
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const data=currentSample(),ref=data.projection.rows[0].accounts[0].subscriptionRef,send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,scope:ref},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.eng-keys button[data-scope="'+ref+'"]')).toHaveAttribute('aria-pressed','true');
 expect(await receive(send('shell',{...shell,scope:'all'}))).toBe(true);
 await expect(page.locator('.ek-all')).toHaveAttribute('aria-pressed','true');
 expect(await receive(send('shell',{...shell,scope:ref}))).toBe(true);
 await expect(page.locator('.eng-keys button[data-scope="'+ref+'"]')).toHaveAttribute('aria-pressed','true');
 expect(await page.evaluate(()=>window.__messages.filter(m=>m.type==='action'))).toEqual([]);
});

test('native compact forced closure and later tall layout preserve action gates',async({page})=>{
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),closed={...shell,profile:'closed',forcedClosed:true,tier:'compact'};
 expect(await receive(send('load',{appearance,shell:closed,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:currentSample()}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-layout','640');await expect(page.locator('#cockpit')).toHaveAttribute('data-shell','closed');
 await expect(page.locator('[data-shutter]')).toBeDisabled();await expect(page.locator('#s6-closed-reason')).toContainText('Not enough window height');
 expect(await receive(send('shell',{...shell,tier:'tall'}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-layout','890');await expect(page.locator('#cockpit')).toHaveAttribute('data-shell','open');
 await expect(page.locator('[data-shutter]')).toBeEnabled();
 await expect(page.locator('[data-detach]')).toHaveCount(0);
 await page.getByRole('button',{name:'Close',exact:true}).click();
 expect(await page.evaluate(()=>window.__messages.filter(m=>m.type==='action').map(m=>m.action))).toEqual(['close']);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN',redBelow:25}))).toBe(true);
 await expect(page.getByRole('button',{name:'关闭',exact:true})).toBeVisible();
});
