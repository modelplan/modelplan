// SPDX-License-Identifier: MIT
// CKP-ENG-21: pressing the selected engine key again returns to All. The built page through its normal bridge,
// synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('CKP-ENG-21 pressing the selected engine key again returns to All',async({page})=>{
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const key=page.locator('.ek[data-sub]').first(),all=page.locator('.ek[data-all]');
 const scopes=()=>page.evaluate(()=>window.sent.filter(m=>m.action==='scopeSelect').map(m=>m.key));
 await key.click();
 await expect(page.locator('[data-scope="subscription"]')).toHaveCount(1);
 const ref=(await scopes()).at(-1);expect(ref).toBeTruthy();expect(ref).not.toBe('all');
 await key.click();
 expect(await scopes()).toEqual([ref,'all']);
 await expect(page.locator('[data-scope="all"]')).toHaveCount(1);
 // A different key still selects that key, and All stays a plain select.
 await key.click();await all.click();expect((await scopes()).slice(-2)).toEqual([ref,'all']);
});
