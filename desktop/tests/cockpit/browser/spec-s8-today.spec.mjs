// SPDX-License-Identifier: MIT
// S8: synthetic production-shaped facts reach the normal cockpit page.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('S8 Overview Today is shown for known totals and hidden for unknown contributions',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.projection.rows=data.projection.rows.slice(0,2);data.details.subscriptions=data.details.subscriptions.slice(0,2);data.details.subscriptions[0].today[0].observedOutputTokens=12000;data.details.subscriptions[1].today[0].observedOutputTokens=13000;
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const total=page.locator('.pg-overview .ov-total');await expect(total).toHaveText('25k');
 data.details.subscriptions[1].today=[];expect(await receive(send('display',{data}))).toBe(true);await expect(total).toHaveCount(0);
 await page.locator('.eng-keys .ek[data-sub]').first().click();await expect(total).toHaveText('12k');
 data.details.subscriptions[0].today[0].observedOutputTokens=0;expect(await receive(send('display',{data}))).toBe(true);await expect(total).toHaveText('0');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(total).toHaveText('0');
 data.details.subscriptions[0].today=[];expect(await receive(send('display',{data}))).toBe(true);await expect(total).toHaveCount(0);
});
