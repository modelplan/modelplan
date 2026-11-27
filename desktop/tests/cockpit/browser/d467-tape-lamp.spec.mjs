// SPDX-License-Identifier: MIT
// D467 (master spec §6.1 tape, C10 help map): the record strip with nothing running reads the header "No session running now · recent"
// over the last-seen sessions in ink-3; the Option help map names the lamp. Both languages, both layouts, built page.
// Owner decision D277 (2026-11-16): CKP-STRIP-09 / CKP-STRIP-16 / CKP-STRIP-17 on the built page through its normal
// bridge, with synthetic data only. A strip line reads chip · tool · project · model + effort · elapsed · tokens · right
// end; the right end is "● 58 t/s" with the cursor while running, "6m ago" when idle. The strip is "now".
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-16T12:00:00Z'),ago=n=>new Date(NOW-n*60000).toISOString();
async function open(page,data){
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(v){window.__events.push(typeof v==='string'?JSON.parse(v):v);}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
function stripData(){
 const {data}=visualFixture();
 data.details.sessions=[
  {sessionRef:'0000000000000001',source:'claude-code',subscriptionRef:null,model:'Opus 5.5',effort:'high',projectLabel:'modelplans.ai',projectState:'named',lastObservedAt:ago(0),state:'running',rate:61.2,startedAt:ago(42),observedTotalTokens:310000},
  {sessionRef:'0000000000000002',source:'codex',subscriptionRef:null,model:'unknown',effort:'medium',projectLabel:'cli',projectState:'named',lastObservedAt:ago(6),state:'idle',rate:40,startedAt:ago(31),observedTotalTokens:96000},
  {sessionRef:'0000000000000003',source:'codex',subscriptionRef:null,model:'Sol 6.1',effort:null,projectLabel:'desktop',projectState:'named',lastObservedAt:ago(0),state:'running',rate:null},
 ];
 return data;
}

for(const [locale,head,caption] of [['en','No session running now · recent','Lamp = a session is running'],['zh-CN','现在没有会话在跑 · 最近','灯 = 有会话在跑']])
test(`D467 tape: idle header over last-seen sessions in ink-3, running sessions first (${locale})`,async({page})=>{
 const data=stripData();data.details.sessions.forEach(s=>{s.state='idle';});
 const {send,receive}=await open(page,data);
 expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
 const tape=page.locator('.ck-tape');
 await expect(tape.locator('.t-head')).toHaveText(head);
 await expect(tape.locator('.t-observed')).toHaveCount(3);
 const first=await tape.locator('.t-head').evaluate(e=>e.nextElementSibling.dataset.state);expect(first).toBe('idle');
 const [muted,row]=await tape.evaluate(t=>[getComputedStyle(t.querySelector('.t-head')).color,getComputedStyle(t.querySelector('.t-observed')).color]);
 expect(row,'idle rows share the header ink-3').toBe(muted);
 // The header takes one of the five lines: five lines hold it and four rows; the overflow line counts the rest.
 for(let i=4;i<=8;i++)data.details.sessions.push({...data.details.sessions[0],sessionRef:'000000000000000'+i,state:'idle',lastObservedAt:ago(i)});
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(tape.locator('.t-head')).toHaveCount(1);
 expect(await tape.locator('.tl').count(),'header + rows + overflow stay within the strip').toBeLessThanOrEqual(5);
 // One running session: no header, the running line leads.
 const run=stripData();
 expect(await receive(send('display',{data:run}))).toBe(true);
 await expect(tape.locator('.t-head')).toHaveCount(0);
 await expect(tape.locator('.t-observed').first()).toHaveAttribute('data-state','running');
});
