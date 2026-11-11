// SPDX-License-Identifier: MIT
// D63: the full alert list adds extra resets expiring within 48 hours (with the lower-effort advice from #719); rows
// whose data the producer does not send are left out. Built page, normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,4,12).getTime(),H=36e5;
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
function cards(hours,state='complete'){
 const data=visualFixture().data;
 data.details.subscriptions[0].resetCards={state,count:hours.length,truncated:false,sources:[],items:hours.map((h,i)=>({id:(i+1).toString(16).padStart(64,'0'),expiresAt:h===null?null:new Date(NOW+h*H).toISOString().replace('.000Z','Z')}))};
 return data;
}
const blue=page=>page.locator('.pg-overview .mfd-alerts li.al-blue');
for(const [name,hours,en,zh] of [
 ['one card inside 48 h',[30,72],'●Codex · 1 reset expires within 48 hours','●Codex · 重置次数中有 1 次将在 48 小时内到期'],
 ['two cards inside 48 h',[2,47.5,100],'●Codex · 2 resets expire within 48 hours','●Codex · 重置次数中有 2 次将在 48 小时内到期'],
])test(`D63 extra resets expiring soon are listed: ${name}`,async({page})=>{
 const {send,receive}=await open(page,cards(hours));
 await expect(blue(page)).toHaveText(en);
 await expect(page.locator('[data-caution]')).not.toHaveClass(/\b(lit|red|amber)\b/);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(blue(page)).toHaveText(zh);
});
for(const [name,hours,state] of [['cards later than 48 h',[49,200],'complete'],['an expiry already passed',[-1],'complete'],['no expiry time',[null],'complete'],['unknown cards',[10],'unknown']])
 test(`D63 no expiring-reset line for ${name}`,async({page})=>{
  await open(page,cards(hours,state));
  await expect(page.locator('.pg-overview')).toBeVisible();await expect(blue(page)).toHaveCount(0);
 });
test('D63 the lamp opens the full list with the expiring resets in it',async({page})=>{
 const data=cards([30]);data.projection.rows[0].accounts[0].windows[0].remainingPercent=10;
 await open(page,data);
 await page.locator('[data-caution]').click();
 await expect(page.locator('.mfd-alerts.all li.al-red')).toHaveCount(1);
 await expect(page.locator('.mfd-alerts.all li.al-blue')).toHaveText('●Codex · 1 reset expires within 48 hours');
});
test('D63 a subscription joined only by row and route gets no personal reset line',async({page})=>{
 const data=cards([30]);data.subscriptions=[];
 await open(page,data);
 await expect(blue(page)).toHaveCount(0);
});
