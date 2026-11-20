// SPDX-License-Identifier: MIT
// CKP-SHELL-50 / MENU-52 (WP-09): the big-screen time key and T show and request the app's one range. The host's
// shell carries it before the first render; the page asks, the host decides and echoes it.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,range) {
 await page.addInitScript(()=>{window.__msgs=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__msgs.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:range===undefined?shell:{...shell,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 return {send,receive};
}
const lit=page=>page.locator('[data-opt="range"] b.on');
const asked=page=>page.evaluate(()=>window.__msgs.filter(m=>m.type==='action'&&m.action==='rangeSelect').map(m=>m.key));

test('CKP-SHELL-50 the host range is on the time key from the first render; T cycles it through the app',async({page})=>{
 const {send,receive}=await open(page,'30d');
 await expect(page.locator('[data-opt="range"] b')).toHaveText(['Today','7d','30d']);
 await expect(lit(page)).toHaveText('30d');
 await page.keyboard.press('t');
 expect(await asked(page)).toEqual(['today']);
 await expect(lit(page)).toHaveText('Today');
 await page.keyboard.press('t');
 expect(await asked(page)).toEqual(['today','7d']);
 await expect(lit(page)).toHaveText('7d');
 // The host decides: its shell is the source of truth (here another surface chose 30d).
 expect(await receive(send('shell',{...shell,range:'30d'}))).toBe(true);
 await expect(lit(page)).toHaveText('30d');
 // A held key does not race through the ranges; a modifier is not T.
 await page.keyboard.press('Meta+t');
 expect(await asked(page)).toEqual(['today','7d']);
});

test('MENU-52 the time key asks the app for the range and keeps the same words on every page',async({page})=>{
 const {send,receive}=await open(page,'today');
 await expect(lit(page)).toHaveText('Today');
 await page.locator('[data-opt="range"] b',{hasText:/^7d$/}).click();
 expect(await asked(page)).toEqual(['7d']);
 await expect(lit(page)).toHaveText('7d');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(page.locator('[data-opt="range"] b')).toHaveText(['今天','7天','30天']);
 await expect(lit(page)).toHaveText('7天');
});

test('CKP-SHELL-50 a shell without a range (an older host) shows the fresh-profile range, 7d',async({page})=>{
 await open(page,undefined);
 await expect(lit(page)).toHaveText('7d');
});
