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

test('COL-2.1-18 Set 1: Codex, GLM and Cursor keys carry their owner-chosen identity colours; Claude keeps its orange',async({page})=>{
 // xAI/Grok has no cockpit engine key yet (no vendor row, no logo); its colour is pinned in the unit test.
 await open(page,['openai','glm','cursor','claude']);
 expect((await keys(page)).slice(0,4).map(k=>k.v)).toEqual(['#10a37f','#3859ff','#f79dcb','#d97757']);
});

test('COL-2.1-18 Claude, GLM and Kimi keys: GLM next to Kimi collides (12.7) so the later one takes its fallback #8dabfd',async({page})=>{
 await open(page,['claude','kimi','glm']);
 const list=await keys(page);
 expect(list.slice(0,3).map(k=>k.v)).toEqual(['#d97757','#007cff','#8dabfd']);
 for(const k of list.slice(0,3))expect(k.text.length).toBeGreaterThan(0); // colour is never alone
 await open(page,['claude','glm','kimi']);
 const first=await keys(page);expect(first[1].v).toBe('#3859ff');expect(first[2].v).not.toBe('#007cff'); // the later of the two takes its alternate
});

test('COL-2.1-18 contrast: on day the identity marks are drawn at 40% of the maker colour (Codex #064133); on night they are the colour',async({page})=>{
 await open(page,['openai','glm','cursor','claude'],'day');
 const fills=()=>page.locator('.eng-keys .ek .bl').evaluateAll(l=>l.map(e=>{const c=getComputedStyle(e).backgroundColor;const m=/^color\(srgb ([\d.]+) ([\d.]+) ([\d.]+)\)/.exec(c);return m?'rgb('+m.slice(1).map(x=>Math.round(x*255)).join(', ')+')':c;}));
 expect((await fills()).slice(0,4)).toEqual(['rgb(6, 65, 51)','rgb(22, 36, 102)','rgb(99, 63, 81)','rgb(87, 48, 35)']);
 await open(page,['openai','glm','cursor','claude'],'night');
 expect((await fills()).slice(0,4)).toEqual(['rgb(16, 163, 127)','rgb(56, 89, 255)','rgb(247, 157, 203)','rgb(217, 119, 87)']);
});
