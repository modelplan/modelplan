// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';

for(const locale of ['en','zh-CN'])test(`visual fixture populates the synthetic last-seen strip and test-only faders (${locale})`,async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:sample()}))).toBe(true);
 await expect(page.locator('.fd-ch.empty')).toHaveCount(3);await expect(page.locator('.ck-tape')).toHaveAttribute('data-sessions-available','false');
 const fixture=visualFixture();expect(await receive(send('display',{data:fixture.data}))).toBe(true);
 await expect(page.locator('.ck-tape .t-observed')).toHaveCount(2);await expect(page.locator('.fd-ch.empty')).toHaveCount(3);
 const columns=page.locator('.eng-cols .ec[data-col]');await expect(columns).toHaveCount(4);
 for(const column of await columns.all()){
  await expect(column.locator('.qcell[data-row=first] .qvalue')).toHaveText('75');
  await expect(column.locator('.qcell[data-row=second] .qvalue')).toHaveText('40');
  await expect(column.locator('.qrow-t .qtokens')).not.toBeEmpty();
  await expect(column.locator('.qrow-t .qaverage')).not.toBeEmpty();
 }
 await expect(page.locator('.lb-other')).toHaveText(locale==='en'?'Other':'其他');
 await renderVisualDeck(page,fixture,locale);await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
 await expect(page.locator('.fd-strip').nth(0)).toContainText('Sol 6.1');await expect(page.locator('.fd-strip').nth(1)).toContainText('Opus 5.5');await expect(page.locator('.fd-strip').nth(2)).toContainText('GLM-5.3');
});
