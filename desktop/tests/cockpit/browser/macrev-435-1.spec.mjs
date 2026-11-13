// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

function memberData(locator,verified=false){
 const data=currentSample();data.projection.rows=[data.projection.rows[0]];const account=data.projection.rows[0].accounts[0];
 account.subscriptionRef=verified?'0123456789abcdef':null;account.accountLocator=locator;
 const w=account.windows[0];Object.assign(w,{id:'session:18000:main:main',role:'session',durationSeconds:18000,limitKey:'main',poolKey:'main',remainingPercent:18});delete w.modelScope;
 if(!verified)data.subscriptions=[];return data;
}
async function open(page,data,scope='all'){
 await page.addInitScript(()=>{window.__messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__messages.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,scope},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);return {send,receive};
}
for(const [oldLocator,newLocator] of [['1111111111111111','2222222222222222'],['1111111111111111','1111111111111111'],['1111111111111111',null],[null,null]])test(`unverified singleton replacement resets scope (${oldLocator??'nil'} → ${newLocator??'nil'})`,async({page})=>{
 const data=memberData(oldLocator),key='codex#saved_login_api',{send,receive}=await open(page,data);
 await page.locator(`.eng-keys button[data-scope="${key}"]`).click();await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
 data.projection.rows[0].accounts[0].accountLocator=newLocator;data.projection.rows[0].accounts[0].windows[0].remainingPercent=75;
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 await expect(page.locator('.ek-all')).toHaveAttribute('aria-pressed','true');await expect(page.locator('.eng-cols .ec .qvalue').first()).toHaveText('75');
 expect(await receive(send('shell',{...shell,scope:key}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 await page.locator(`.eng-keys button[data-scope="${key}"]`).click();await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
});
test('a proven subscription reference stays selected through replacement and reopen',async({page})=>{
 const ref='0123456789abcdef',data=memberData('1111111111111111',true),{send,receive}=await open(page,data);
 await page.locator(`.eng-keys button[data-scope="${ref}"]`).click();data.projection.rows[0].accounts[0].accountLocator='2222222222222222';data.projection.rows[0].accounts[0].windows[0].remainingPercent=75;
 expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');await expect(page.locator(`.eng-keys button[data-scope="${ref}"]`)).toHaveAttribute('aria-pressed','true');
 await page.reload();await page.waitForFunction(()=>!!window.modelPlanCockpit);const second=commands();
 expect(await receive(second('load',{appearance,shell:{...shell,scope:ref},redBelow:25}))).toBe(true);expect(await receive(second('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect(await receive(second('display',{data}))).toBe(true);
 await expect(page.locator(`.eng-keys button[data-scope="${ref}"]`)).toHaveAttribute('aria-pressed','true');
});
for(const locator of ['1111111111111111',null])test(`reopened page rejects unverified scope (${locator??'nil'})`,async({page})=>{
 const data=memberData(locator),key='codex#saved_login_api',{receive}=await open(page,data);
 await page.locator(`.eng-keys button[data-scope="${key}"]`).click();await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','subscription');
 await page.reload();await page.waitForFunction(()=>!!window.modelPlanCockpit);const next=commands();
 expect(await receive(next('load',{appearance,shell:{...shell,scope:key},redBelow:25}))).toBe(true);
 expect(await receive(next('visibility',{visible:true,occluded:false,key:true}))).toBe(true);expect(await receive(next('display',{data}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');await expect(page.locator('.ek-all')).toHaveAttribute('aria-pressed','true');
 expect(await receive(next('shell',{...shell,scope:key}))).toBe(true);await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
});
