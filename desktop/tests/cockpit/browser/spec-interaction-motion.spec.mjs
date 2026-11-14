// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,currentSample,pageId,shell} from '../fixture.mjs';

test('MOT-2.3-02 page-key press gives temporary physical feedback',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data:currentSample()})])expect(await receive(raw)).toBe(true);
 const button=page.getByRole('button',{name:'Subscription',exact:true});await expect(button).toBeVisible();
 const box=await button.boundingBox();expect(box).not.toBeNull();const offset=()=>button.evaluate(e=>new DOMMatrix(getComputedStyle(e).transform).m42);
 expect(await offset()).toBe(0);await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();
 expect(await offset()).toBe(1);await page.mouse.up();await expect(button).toHaveAttribute('aria-pressed','true');expect(await offset()).toBe(0);
});
