// SPDX-License-Identifier: MIT
// The porthole HUD from published public data, through the normal bridge. Synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
const model=(id,ability,cost)=>({id,name:'Synthetic '+id,developerId:'openai',recommended:'high',efforts:[effort('low',ability-8,cost/3),effort('high',ability,cost,true)]});
const models=Array.from({length:8},(_,i)=>model('m'+i,40+i,.1*(i+1)));models.push(model('dominated-sol',30,2));
async function open(page,{tier='tall',published=models,session=null}={}) {
 const {data}=visualFixture();if(published)data.details.publishedModels=published;if(session)data.details.sessions=[session];
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
test('CKP-PORT-04 the tall HUD lists the first six models, complete, under a mini chart',async({page})=>{
 await open(page);const hud=page.locator('.hud');
 await expect(hud.locator('.hp')).toHaveCount(6);await expect(hud.locator('.hp b').first()).toHaveText('Synthetic m0');await expect(hud.locator('.hp-rec').first()).toHaveText('★high');
 const box=await hud.boundingBox();expect([box.width,box.height]).toEqual([180,160]);
 const svg=await hud.locator('svg.hud-mini').boundingBox();expect([svg.width,svg.height]).toEqual([162,77]);
});
test('CKP-PORT-08 one point per model at ★, a dashed frontier, dominated dots dimmed, no names inside',async({page})=>{
 await open(page,{published:[model('a',40,.1),model('b',50,.3),model('c',35,.9)]});
 await expect(page.locator('.hud-dot')).toHaveCount(3);await expect(page.locator('.hud-dot.dominated')).toHaveCount(1);
 expect((await page.locator('.hud-front').getAttribute('points')).trim().split(/\s+/).length).toBe(2);
 await expect(page.locator('.hud-mini text')).toHaveCount(0);
});
test('CKP-PORT-08 a different current effort is a white dot linked to its ★',async({page})=>{
 await open(page,{published:[model('a',40,.1)],session:{sessionRef:'0000000000000001',source:'Codex',subscriptionRef:null,model:'a',effort:'low',projectLabel:null,lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null}});
 await expect(page.locator('.hud-cur')).toHaveCount(1);await expect(page.locator('.hud-link')).toHaveCount(1);
});
test('CKP-PORT-05 the compact profile is one strip of three',async({page})=>{
 await open(page,{tier:'compact'});
 await expect(page.locator('.hud.hud-strip .hp')).toHaveCount(3);await expect(page.locator('.hud-mini')).toHaveCount(0);
 const box=await page.locator('.hud').boundingBox();expect(box.width).toBe(216);
});
test('CKP-PORT-06 a row opens 档位 and Esc or Back returns to the page before',async({page})=>{
 await open(page);
 await page.locator('.hud .hp').first().click();await expect(page.locator('.fc')).toBeVisible();
 await expect(page.locator('.mfd-back')).toBeVisible();await page.keyboard.press('Escape');await expect(page.locator('.fc')).toHaveCount(0);
 await page.locator('.hud-dot').first().click();await expect(page.locator('.fc')).toBeVisible();
 await page.locator('.mfd-back').click();await expect(page.locator('.fc')).toHaveCount(0);
});
test('CKP-PORT-06 hovering a row lights its rocket when the still has it',async({page})=>{
 await open(page,{published:[model('dominated-sol',30,2)]});
 await page.locator('.hud .hp').first().hover();await expect(page.locator('.ck-still-body.ck-hot')).toHaveCount(1);
 await page.mouse.move(1,1);await expect(page.locator('.ck-still-body.ck-hot')).toHaveCount(0);
});
test('an older engine shows no HUD',async({page})=>{
 await open(page,{published:null});await expect(page.locator('.hud')).toBeHidden();
});
