// SPDX-License-Identifier: MIT
// D131 / COL-2.1-18: the engine keys, faders, record strip and subscription header take their maker colour from the one
// shared table (GLM is no longer purple), and a later maker whose colour sits too close to one already shown takes its
// alternate shade. The built page through its normal bridge; synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,sample,excludePortholeFlicker} from '../fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,vendorKeys,theme='night'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),data=sample();
 data.projection.rows.forEach((row,i)=>{row.vendorKey=vendorKeys[i]??null;});
 expect(await receive(send('load',{appearance:{...appearance,theme},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
const keys=page=>page.locator('.eng-keys .ek').evaluateAll(list=>list.map(k=>({text:k.innerText.trim().replace(/\s+/g,' '),v:getComputedStyle(k.querySelector('.bl')).getPropertyValue('--v').trim()})));

test('COL-2.1-18 Claude, GLM and Kimi keys carry the shared brand colours; GLM is not purple or green',async({page})=>{
 await open(page,['claude','glm','kimi']);
 const list=await keys(page);
 expect(list.slice(0,3).map(k=>k.v)).toEqual(['#d97757','#b9c2cc','#007cff']);
 // Colour is never alone: every key keeps its name (and mark).
 for(const k of list.slice(0,3))expect(k.text.length).toBeGreaterThan(0);
});

test('COL-2.1-18 GLM next to Codex: the two light greys collide, so the later one (GLM) takes its alternate shade',async({page})=>{
 await open(page,['openai','claude','glm']);
 expect((await keys(page)).slice(0,3).map(k=>k.v)).toEqual(['#ececec','#d97757','#656d76']);
});

test('COL-2.1-18 a maker too close to one already shown takes its alternate shade, in order',async({page})=>{
 // Cursor's light grey (#eef2f6) is within a few units of OpenAI's (#ececec): the later one (Cursor) takes its alternate.
 await open(page,['openai','claude','cursor']);
 const list=await keys(page);
 expect(list[0].v).toBe('#ececec');
 expect(list[2].v).not.toBe('#eef2f6');expect(list[2].v).toMatch(/^#[0-9a-f]{6}$/);
 await open(page,['cursor','claude','openai']);
 const swapped=await keys(page);
 expect(swapped[0].v).toBe('#eef2f6');expect(swapped[2].v).not.toBe('#ececec');
});

test('COL-2.1-18 contrast: on day the identity marks are drawn darker than the maker colour; on night they are the colour',async({page})=>{
 await open(page,['openai','claude','glm'],'day');
 const day=await page.locator('.eng-keys .ek .bl').first().evaluate(e=>getComputedStyle(e).backgroundColor);
 expect(day).not.toBe('rgb(236, 236, 236)');expect(Number(day.match(/\d+/)[0])).toBeLessThan(120);
 await open(page,['openai','claude','glm'],'night');
 expect(await page.locator('.eng-keys .ek .bl').first().evaluate(e=>getComputedStyle(e).backgroundColor)).toBe('rgb(236, 236, 236)');
});
