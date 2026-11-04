// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('admitted cockpit details populate faders and pin on release',async({page})=>{
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=visualFixture().data;
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[
  {id:'model-a',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]},
  {id:'model-b',name:'Synthetic B',developerId:'anthropic',recommended:'high',efforts:[{effort:'high',label:'High',star:true,ability:null,cost:null,time:null}]},
  {id:'model-c',name:'Synthetic C',developerId:'google',recommended:'max',efforts:[{effort:'max',label:'Max',star:true,ability:50,cost:4,time:null}]},
 ]};
 expect(await receive(send('display',{data}))).toBe(true);
 const strips=page.locator('.fd-strip');await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
 await expect(strips.nth(0)).toContainText('Synthetic A');await expect(strips.nth(1)).toContainText('Synthetic B');await expect(strips.nth(2)).toContainText('Synthetic C');
 const box=await strips.nth(2).boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.waitForTimeout(600);
 await expect(page.locator('.st-pin')).toHaveCount(0);await page.mouse.up();
 await expect(strips.nth(0)).toContainText('Synthetic C');await expect(strips.nth(0).locator('.st-pin')).toHaveCount(1);
 delete data.details.publication;expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.fd-ch.empty')).toHaveCount(3);
});
