// SPDX-License-Identifier: MIT
// S13: deferred panels must not present synthetic study history as facts.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
for(const locale of ['en','zh-CN'])test(`S13 deferred historical panels stay unavailable (${locale})`,async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 for(const raw of [send('load',{appearance:{...appearance,locale},shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const screen=page.locator('.mfd-screen'),missing=locale==='en'?'Data unavailable':'暂无数据';
 await expect(screen).toContainText(locale==='en'?'Quota only':'仅额度');await expect(screen.locator('.ov-chart,.hm-grid,.wh-list,.ws-list')).toHaveCount(0);
 for(const opt of ['chart','days','stack']){const button=page.locator(`[data-opt="${opt}"]`);if(await button.count()){await button.click();await expect(screen).toContainText(locale==='en'?'Quota only':'仅额度');await expect(screen.locator('.ov-chart,.hm-grid')).toHaveCount(0);}}
 for(const name of locale==='en'?['Effort','Breakdown']:['档位','去向']){await page.getByRole('button',{name,exact:true}).click();await expect(screen).toContainText(missing);await expect(screen.locator('.wh-list,.ws-list,.fc-chart')).toHaveCount(0);if(name==='Breakdown'||name==='去向'){await page.locator('[data-opt="where"]').click();await expect(screen).toContainText(missing);await expect(screen.locator('.wh-list,.ws-list')).toHaveCount(0);}}
 await page.getByRole('button',{name:locale==='en'?'Subscription':'订阅',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();await page.locator('[data-opt="tab"]').click();await expect(screen).toContainText(missing);await expect(screen.locator('.rs-list,[data-fill="cyc"]')).toHaveCount(0);
});
