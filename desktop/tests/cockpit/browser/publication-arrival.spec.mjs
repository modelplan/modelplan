// SPDX-License-Identifier: MIT
// A fresh install opens the cockpit before the publication arrives, through the normal bridge.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test('the faders say the data is unavailable, then fill when the publication arrives',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const {data}=visualFixture();data.details.publication=null;
 expect(await receive(send('display',{data}))).toBe(true);
 const note=page.locator('.fd-bank .mp-empty'),channels=page.locator('.fd-ch:not(.empty)');
 await expect(note).toHaveText('Data unavailable');await expect(channels).toHaveCount(0);
 const model={id:'model-a',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null}]};
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[model]};
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(channels).toHaveCount(1);await expect(channels.first().locator('.fd-strip')).toContainText('Synthetic A');
 await expect(note).toHaveCount(0);
});
