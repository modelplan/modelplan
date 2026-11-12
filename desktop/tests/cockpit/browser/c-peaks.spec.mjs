// SPDX-License-Identifier: MIT
// D63: a declared plan's published peak-rate window (cockpitPeaksV1) is a blue, list-only alert line.
// Built page, normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,8,12).getTime(),H=36e5,at=h=>new Date(NOW+h*H).toISOString().replace('.000Z','Z');
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
function peaks(list){const data=visualFixture().data;data.details.peaks=list.map(([start,end,status='confirmed',row=data.projection.rows[0].id])=>({rowId:row,startsAt:at(start),endsAt:end===null?null:at(end),status}));return data;}
const blue=page=>page.locator('.pg-overview .mfd-alerts li.al-blue');
for(const [name,list,en,zh] of [
 ['a coming peak with its length',[[1,3]],'●Codex peak in 1h00 for 2h00','●Codex 1h00 后进入高峰 · 持续 2h00'],
 ['a coming peak without a known end',[[0.5,null,'tentative']],'●Codex peak in 30m','●Codex 30m 后进入高峰'],
 ['a peak under way',[[-1,2]],'●Codex Peak hours · now','●Codex 高峰时段 · 进行中'],
])test(`D63 peak hours: ${name}, blue and list-only`,async({page})=>{
 const {send,receive}=await open(page,peaks(list));
 await expect(blue(page)).toHaveText(en);
 await expect(page.locator('[data-caution]')).not.toHaveClass(/\b(lit|red|amber)\b/);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(blue(page)).toHaveText(zh);
});
test('D63 a peak that has ended, or a row the page does not show, has no line',async({page})=>{
 await open(page,peaks([[-3,-1],[1,2,'confirmed','declared:not-here']]));
 await expect(page.locator('.pg-overview')).toBeVisible();await expect(blue(page)).toHaveCount(0);
});
test('D63 without the negotiated field there is no peak line',async({page})=>{
 await open(page,visualFixture().data);
 await expect(blue(page)).toHaveCount(0);
});
