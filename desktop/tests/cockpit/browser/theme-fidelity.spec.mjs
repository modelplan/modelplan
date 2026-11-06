// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('initial and live themes reach the strip, engine, deck and help',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme:'day'},shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
 const colours=()=>page.evaluate(()=>{const css=(s,p)=>getComputedStyle(document.querySelector(s),p);return {theme:document.documentElement.dataset.theme,metal:css('.ek-all').backgroundImage,deck:css('.mfd-pk .pk').backgroundImage,tape:css('.ck-tape').backgroundColor,filter:css('.ck-head','::before').filter,pop:css(document.querySelector('.help-map-title')?'.help-map-title':'.ck-head').color};});
 await page.keyboard.down('Alt');const day=await colours();await expect(page.locator('#help-map')).toBeVisible();await page.keyboard.up('Alt');
 expect(day.theme).toBe('day');expect(day.filter).not.toBe('none');
 expect(await receive(send('appearance',{...appearance,theme:'night'}))).toBe(true);
 await page.keyboard.down('Alt');const night=await colours();await page.keyboard.up('Alt');
 expect(night.theme).toBe('night');expect(night.filter).toBe('none');expect(night.metal).not.toBe(day.metal);expect(night.deck).not.toBe(day.deck);expect(night.pop).not.toBe(day.pop);
 expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);await expect(page.locator('html')).toHaveAttribute('data-theme','day');
});
