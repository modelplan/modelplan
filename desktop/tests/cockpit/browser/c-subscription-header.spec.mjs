// SPDX-License-Identifier: MIT
// Owner build 13: the Subscription page header read "Codex · modelplan · 3.6753333333333 min ago" with no mark and no
// plan. The study names the subscription with its vendor mark and plan, and the age in whole minutes.
// The built page through its normal bridge; synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile,CODEX_REF} from '../build13-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,scope:CODEX_REF},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 await page.locator('[data-mfd="page:sub"]').click();
}

test('B13 Subscription header: subscription name, vendor mark, plan and whole minutes',async({page})=>{
 await open(page,build13Profile());
 const head=page.locator('.mfd-page .sp-h');
 await expect(head.locator('b')).toHaveText('ChatGPT Pro');
 const mark=await head.locator('.mg').evaluate(e=>({ink:getComputedStyle(e).getPropertyValue('--v').trim(),mask:getComputedStyle(e).webkitMaskImage||getComputedStyle(e).maskImage}));
 expect(mark.ink).toBe('#6aa8ff');expect(mark.mask).toContain('assets/brands/openai-white.svg');
 await expect(page.locator('.mfd-page .sp-sub .pl')).toHaveText('Pro');
 const age=await page.locator('.mfd-page .sp-sub .src').textContent();
 expect(age).toMatch(/· 4 min ago$/);expect(age).not.toMatch(/\d\.\d/);
});

test('B13 Subscription header: a reading under a minute old says just now (Chinese)',async({page})=>{
 const data=build13Profile();for(const row of data.projection.rows)for(const a of row.accounts)a.observedAt=new Date(Date.now()-20000).toISOString();
 await open(page,data,'zh-CN');
 await expect(page.locator('.mfd-page .sp-h b')).toHaveText('ChatGPT Pro');
 expect(await page.locator('.mfd-page .sp-sub .src').textContent()).toMatch(/刚刚$/);
});
