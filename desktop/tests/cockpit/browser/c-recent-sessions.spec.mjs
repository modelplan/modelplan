// SPDX-License-Identifier: MIT
// D63: the Breakdown page's 7-day time view lists the recorded sessions of the past week (cockpitSessionsV1,
// details.recentSessions) beside the live ones, with their last sighting only. Built page, normal bridge, synthetic data.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,8,12).getTime(),H=36e5,at=h=>new Date(NOW-h*H).toISOString().replace('.000Z','Z');
async function open(page,data,{locale='en',names=true}={}){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale,showProjectNames:names},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
function fixture(){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.details.sessions=[{sessionRef:'00000000000000a1',source:'codex',subscriptionRef:ref,model:'Sol 6.1',effort:'high',projectLabel:'live-project',lastObservedAt:at(0.01),state:'running',rate:null}];
 data.details.recentSessions=[
  {sessionRef:'00000000000000a1',source:'codex',subscriptionRef:ref,model:'Sol 6.1',effort:'high',projectLabel:'live-project',lastObservedAt:at(0.01)},
  {sessionRef:'00000000000000b2',source:'codex',subscriptionRef:ref,model:'Sol 6.1',effort:'medium',projectLabel:'older-project',lastObservedAt:at(50)},
  {sessionRef:'00000000000000c3',source:'claude-code',subscriptionRef:null,model:'unknown',effort:null,projectLabel:null,lastObservedAt:at(140)},
 ];
 return data;
}
async function timeView(page,period){
 await page.getByRole('button',{name:'Breakdown',exact:true}).click();
 await page.locator('[data-opt="where"] b').nth(1).click();
 await page.locator('[data-opt="time"] b').nth(period==='7d'?1:0).click();
}
const rows=page=>page.locator('.ws-list .ws').evaluateAll(list=>list.map(e=>e.dataset.mfd.slice('session:'.length)));

test('D63 the 7-day view lists last week’s recorded sessions after the live one, once each',async({page})=>{
 await open(page,fixture());await timeView(page,'7d');
 expect(await rows(page)).toEqual(['00000000000000a1','00000000000000b2','00000000000000c3']);
 await expect(page.locator('.ws-list .ws-h').nth(1)).toContainText('Last seen 2');
 await expect(page.locator('.ws[data-mfd="session:00000000000000b2"] .ws-p')).toHaveText('older-project');
 // A last sighting, never an end time or a token count.
 await expect(page.locator('.ws[data-mfd="session:00000000000000b2"] .ws-at')).toHaveText('11/6 10:00');
 await expect(page.locator('.ws[data-mfd="session:00000000000000b2"] .ws-tk')).toHaveText('--');
});
test('D63 the Today view keeps only today’s sessions',async({page})=>{
 await open(page,fixture());await timeView(page,'today');
 expect(await rows(page)).toEqual(['00000000000000a1']);
});
test('D63 a subscription scope keeps its own recorded sessions; unbound ones stay under All',async({page})=>{
 await open(page,fixture());await page.keyboard.press('1');await timeView(page,'7d');
 expect(await rows(page)).toEqual(['00000000000000a1','00000000000000b2']);
});
test('D63 project names off hide the recorded sessions’ labels too',async({page})=>{
 await open(page,fixture(),{names:false});await timeView(page,'7d');
 await expect(page.locator('.ws[data-mfd="session:00000000000000b2"] .ws-p')).toHaveText('--');
});
test('D63 without the negotiated field the 7-day view shows only what is live',async({page})=>{
 const data=fixture();delete data.details.recentSessions;
 await open(page,data);await timeView(page,'7d');
 expect(await rows(page)).toEqual(['00000000000000a1']);
});
