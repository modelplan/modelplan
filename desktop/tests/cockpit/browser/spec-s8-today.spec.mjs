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

test('S12 Subscription shows verified reset cards and withholds unitless detail credits',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.clock.setFixedTime(new Date('2026-11-03T12:00:00Z'));await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions=data.details.subscriptions.slice(0,1);
 const detail=data.details.subscriptions[0];detail.resetCards={state:'complete',count:5,truncated:false,sources:[],items:Array.from({length:5},(_,i)=>({id:(i+1).toString(16).padStart(64,'0'),expiresAt:`2026-11-${String(4+i).padStart(2,'0')}T12:00:00Z`}))};detail.credits={balance:19613.957,observedAt:'2026-11-03T11:55:00Z'};
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();const cards=page.locator('.pg-sub .rc'),credits=page.locator('.pg-sub .cr-l').filter({has:page.locator('.cr-bal')});
 await expect(cards).toContainText('5');await expect(cards.locator('.rc-exp i:not(.more)')).toHaveCount(4);await expect(cards.locator('.rc-exp .more')).toHaveText('+1');expect((await cards.getAttribute('title')).split('\n')).toHaveLength(5);
 await expect(credits).toHaveCount(0);await expect(page.locator('.cr-30')).toHaveCount(0);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(credits).toHaveCount(0);
 detail.resetCards={state:'unknown',count:null,truncated:false,sources:[],items:[]};detail.credits=null;expect(await receive(send('display',{data}))).toBe(true);await expect(cards).toHaveCount(0);await expect(credits).toHaveCount(0);
 detail.resetCards={state:'complete',count:5,truncated:false,sources:[],items:[]};detail.credits={balance:100,observedAt:'2026-11-03T11:55:00Z'};data.subscriptions=[];expect(await receive(send('display',{data}))).toBe(true);await page.locator('.eng-keys .ek[data-sub]').first().click();await expect(cards).toHaveCount(0);await expect(credits).toHaveCount(0);
});

test('S8 unitless detail balance does not become labelled credits on the normal page',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 data.projection.rows=data.projection.rows.slice(0,1);data.details.subscriptions=data.details.subscriptions.slice(0,1);
 data.details.subscriptions[0].credits={balance:19613.957,observedAt:'2026-11-03T11:55:00Z'};
 for(const raw of [send('load',{appearance,shell,redBelow:25}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();await page.locator('.eng-keys .ek[data-sub]').first().click();
 await expect(page.locator('.pg-sub .cr-bal')).toHaveCount(0);
});
