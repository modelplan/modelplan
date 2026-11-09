// SPDX-License-Identifier: MIT
// Owner D76: the engine's Reserve row label explains itself on hover or focus, in the MFD's floating tip style, and
// carries the same words as its accessible name. Built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

const words={en:'Reserve: extra resets you can still use and remaining credits','zh-CN':'储备：还能用的额外重置次数和剩余点数'};
for(const locale of ['en','zh-CN'])test(`D76 the Reserve label has a hover and focus hint (${locale})`,async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=currentSample();
 data.projection.rows[0].accounts[0].credits={balance:3903,unit:'credits'};
 expect(await receive(send('load',{appearance:{...appearance,locale},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 const label=page.locator('.eng-labels .lb-r');
 await expect(label).toHaveAttribute('aria-label',words[locale]);
 const tip=page.locator('.mfd-tip.eng-hint');
 await expect(tip).toHaveCount(0);
 await label.hover();
 await expect(tip).toBeVisible();await expect(tip).toHaveText(words[locale]);
 const box=await tip.boundingBox(),view=page.viewportSize();
 expect(box.x).toBeGreaterThanOrEqual(0);expect(box.x+box.width).toBeLessThanOrEqual(view.width);
 await page.mouse.move(5,5);await expect(tip).toHaveCount(0);
 await label.focus();await expect(tip).toBeVisible();
});
