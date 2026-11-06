// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('CKP-MFD-06 overview lists critical alerts before warnings in either delivery order',async({page})=>{
 const data=visualFixture().data,row=data.projection.rows[0],account=row.accounts[0];
 const warning={severity:'warning',source:row.id,subscriptionRef:account.subscriptionRef,windowId:account.windows[0].id,remainingPercent:35};
 const critical={...warning,windowId:account.windows[1].id,severity:'critical',remainingPercent:20};
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 data.details.alerts=[warning,critical];
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const alerts=page.locator('.mfd-alerts > li');await expect(alerts).toHaveCount(2);
 await expect(alerts.nth(0)).toHaveClass(/\bal-red\b/);await expect(alerts.nth(0)).toContainText('20%');await expect(alerts.nth(1)).toHaveClass(/\bal-amber\b/);
 data.details.alerts=[critical,warning];expect(await receive(send('display',{data}))).toBe(true);
 await expect(alerts.nth(0)).toHaveClass(/\bal-red\b/);await expect(alerts.nth(1)).toHaveClass(/\bal-amber\b/);
});
