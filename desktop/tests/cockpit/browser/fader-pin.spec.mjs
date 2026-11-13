// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';

test('long press toggles a favourite and moves it to the first bank',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const fixture=visualFixture();fixture.publication.faders.push({...fixture.publication.faders[0],id:'fourth',name:'Fourth',short:'Fourth'});
 await renderVisualDeck(page,fixture,'en');
 await page.locator('[data-bank="1"]').click();
 const strip=page.locator('.fd-strip').first();await expect(strip).toContainText('Fourth');
 await strip.click();await expect(strip.locator('.st-pin')).toHaveCount(0);
 const box=await strip.boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
 await page.waitForTimeout(650);
 await expect(page.locator('.st-pin')).toHaveCount(0);
 await page.mouse.up();
 await expect(page.locator('.fd-strip').first()).toContainText('Fourth');
 await expect(page.locator('.fd-strip').first().locator('.st-pin')).toHaveCount(1);
 const first=await page.locator('.fd-strip').first().boundingBox();await page.mouse.move(first.x+first.width/2,first.y+first.height/2);await page.mouse.down();
 await page.waitForTimeout(650);
 await page.mouse.up();
 await expect(page.locator('.fd-strip').first()).toContainText('Sol 6.1');
 await expect(page.locator('.st-pin')).toHaveCount(0);
});
