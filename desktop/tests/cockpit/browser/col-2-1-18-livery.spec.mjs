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

test('COL-2.1-18 D250: Codex, GLM, Cursor and Claude keys carry the old pastel accents (no two collide)',async({page})=>{
 // xAI/Grok has no cockpit engine key yet (no vendor row, no logo); its colour is pinned in the unit test.
 await open(page,['openai','glm','cursor','claude']);
 expect((await keys(page)).slice(0,4).map(k=>k.v)).toEqual(['#6aa8ff','#8f7dff','#eef2f6','#ff9a6a']);
});

test('COL-2.1-18 Copilot, Claude and GLM keys: GLM next to Copilot collides (9.7) so the later one takes its fallback #4422a0',async({page})=>{
 await open(page,['claude','copilot','glm']);
 const list=await keys(page);
 expect(list.slice(0,3).map(k=>k.v)).toEqual(['#ff9a6a','#c08cff','#4422a0']);
 for(const k of list.slice(0,3))expect(k.text.length).toBeGreaterThan(0); // colour is never alone
 await open(page,['claude','glm','copilot']);
 const first=await keys(page);expect(first[1].v).toBe('#8f7dff');expect(first[2].v).not.toBe('#c08cff'); // the later of the two takes its alternate
});

test('COL-2.1-18 contrast: on day the identity marks are drawn at 40% of the maker colour (Codex #2a4366); on night they are the colour',async({page})=>{
 await open(page,['openai','glm','cursor','claude'],'day');
 const fills=()=>page.locator('.eng-keys .ek .bl').evaluateAll(l=>l.map(e=>{const c=getComputedStyle(e).backgroundColor;const m=/^color\(srgb ([\d.]+) ([\d.]+) ([\d.]+)\)/.exec(c);return m?'rgb('+m.slice(1).map(x=>Math.round(x*255)).join(', ')+')':c;}));
 expect((await fills()).slice(0,4)).toEqual(['rgb(42, 67, 102)','rgb(57, 50, 102)','rgb(95, 97, 98)','rgb(102, 62, 42)']);
 await open(page,['openai','glm','cursor','claude'],'night');
 expect((await fills()).slice(0,4)).toEqual(['rgb(106, 168, 255)','rgb(143, 125, 255)','rgb(238, 242, 246)','rgb(255, 154, 106)']);
});
