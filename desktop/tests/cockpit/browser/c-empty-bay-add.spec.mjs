// SPDX-License-Identifier: MIT
// D95: with fewer than three subscriptions the first empty engine bay offers a quiet "add a subscription" affordance that
// opens Settings; no other bay does, and it is gone at three or more subscriptions. Built page, synthetic data.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,count,locale='en') {
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const data=visualFixture().data;
 data.projection.rows=data.projection.rows.slice(0,count);data.subscriptions=data.subscriptions.slice(0,count);data.details.subscriptions=data.details.subscriptions.slice(0,count);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}

for(const count of [1,2])test(`D95 ${count} subscription(s): exactly one empty bay shows the add affordance`,async({page})=>{
 await open(page,count);
 await expect(page.locator('.ec-add')).toHaveCount(1);
 await expect(page.locator('.ec-add-label')).toHaveText('Add a subscription');await expect(page.locator('.ec-plus')).toHaveCount(1);
 // It sits in the first empty bay; the other empty bays stay plain.
 const bays=page.locator('.eng-cols > .ec-bay');await expect(bays).toHaveCount(3-count);
 await expect(bays.first().locator('.ec-add')).toHaveCount(1);
 if(count===1)await expect(bays.nth(1).locator('.ec-add')).toHaveCount(0);
});

test('D95 the affordance is half strength at rest, in the axis-label tone, and rises on hover and focus',async({page})=>{
 await open(page,1);
 const add=page.locator('.ec-add'),axis=await page.locator('.eng-labels .lb').first().evaluate(e=>getComputedStyle(e).color);
 expect(await page.locator('.ec-add-label').evaluate(e=>getComputedStyle(e).color)).toBe(axis);
 const rest=Number(await add.evaluate(e=>getComputedStyle(e).opacity));expect(rest).toBeLessThanOrEqual(0.5);
 // The plus is centred in the bay and drawn with two thin strokes; the bay itself has no border.
 const bay=await page.locator('.eng-cols > .ec-bay').first().boundingBox(),plus=await page.locator('.ec-plus').boundingBox();
 expect(Math.abs(plus.x+plus.width/2-(bay.x+bay.width/2))).toBeLessThan(1.5);
 expect(await add.evaluate(e=>getComputedStyle(e.parentElement).borderTopWidth)).toBe('0px');
 await page.locator('.eng-cols > .ec-bay').first().hover();
 expect(Number(await add.evaluate(e=>getComputedStyle(e).opacity))).toBeGreaterThan(rest);
 await page.mouse.move(0,0);
 await page.locator('.eng-cols > .ec-bay').first().focus();
 expect(Number(await add.evaluate(e=>getComputedStyle(e).opacity))).toBeGreaterThan(rest);
});

test('D95 clicking the affordance opens Settings',async({page})=>{
 await open(page,2);
 await page.locator('.eng-cols > .ec-bay').first().click();
 const event=await page.evaluate(()=>window.__events.filter(e=>e.type==='action').at(-1));
 expect(event.action).toBe('openSettings');
});

test('D95 the Chinese label comes from the same bay',async({page})=>{
 await open(page,1,'zh-CN');
 await expect(page.locator('.ec-add-label')).toHaveText('添加订阅');
});

test('D95 three or more subscriptions show no affordance',async({page})=>{
 await open(page,3);
 await expect(page.locator('.ec-add')).toHaveCount(0);
});
