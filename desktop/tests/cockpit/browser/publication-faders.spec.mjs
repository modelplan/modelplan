// SPDX-License-Identifier: MIT
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sampleWithDetails,shell} from '../fixture.mjs';
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
 data.details.sessions=[{sessionRef:'0123456789abcdef',source:'codex',subscriptionRef:null,model:'model-b',effort:'high',projectLabel:null,lastObservedAt:'2026-10-24T12:00:00Z',state:'running',rate:null}];
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(strips.nth(0)).toContainText('Synthetic C');await expect(strips.nth(1)).toContainText('Synthetic B');await expect(strips.nth(2)).toContainText('Synthetic A');
 delete data.details.publication;expect(await receive(send('display',{data}))).toBe(true);await expect(page.locator('.fd-ch.empty')).toHaveCount(3);
});

test('S10 trial does not transfer to a replacement publication occupying the same fader slot',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 const model={id:'model-a',name:'Synthetic A',developerId:'openai',recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:2,time:null},{effort:'high',label:'High',star:false,ability:50,cost:3,time:null}]};
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[model]};
 for(const raw of [send('load',{appearance,shell}),send('visibility',{visible:true,occluded:false,key:true}),send('display',{data})])expect(await receive(raw)).toBe(true);
 const slider=page.locator('.fd-ch:not(.empty) [role=slider]').first();await slider.focus();await page.keyboard.press('ArrowUp');await expect(slider).toHaveAttribute('aria-valuetext','High');
 expect(await receive(send('display',{data}))).toBe(true);await expect(slider).toHaveAttribute('aria-valuetext','High');
 data.details.publication={...data.details.publication,publicationId:'fedcba9876543210fedcba98',models:[{...model,id:'model-b',name:'Synthetic B'}]};expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.fd-strip').first()).toContainText('Synthetic B');await expect(slider).toHaveAttribute('aria-valuetext','Med');await expect(page.locator('.fd-ch:not(.empty) .fd-ghost')).toBeHidden();
 await slider.focus();await page.keyboard.press('ArrowUp');await expect(slider).toHaveAttribute('aria-valuetext','High');
 data.details.publication.models=[{...model,id:'model-c',name:'Synthetic C'}];expect(await receive(send('display',{data}))).toBe(true);await expect(slider).toHaveAttribute('aria-valuetext','Med');
 await slider.focus();await page.keyboard.press('ArrowUp');await expect(slider).toHaveAttribute('aria-valuetext','High');
 data.details.publication.publicationId='aaaaaaaaaaaaaaaaaaaaaaaa';expect(await receive(send('display',{data}))).toBe(true);await expect(slider).toHaveAttribute('aria-valuetext','Med');
});

test('C-09 page accepts absent and valid publication',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=visualFixture().data;
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 delete data.details.publication;expect(await receive(send('display',{data}))).toBe(true);
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-10-24T12:00:00Z',source:'client',truncated:false,models:[]};
 expect(await receive(send('display',{data}))).toBe(true);
});

test('the normal entry shows faders from negotiated details, without the visual fixture',async({page})=>{
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:sampleWithDetails()}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(2);await expect(page.locator('.fd-ch.empty')).toHaveCount(1);
 await expect(page.locator('.fd-ch:not(.empty) .st-name').first()).toHaveText('Synthetic A');
});
