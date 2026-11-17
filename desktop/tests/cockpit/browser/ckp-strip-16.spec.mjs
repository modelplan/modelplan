// SPDX-License-Identifier: MIT
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
  {sessionRef:'0000000000000001',source:'claude-code',subscriptionRef:null,model:'Opus 5.5',effort:'high',projectLabel:'modelplans.ai',projectState:'named',lastObservedAt:ago(0),state:'running',rate:61.2,startedAt:ago(42),observedOutputTokens:310000},
  {sessionRef:'0000000000000002',source:'codex',subscriptionRef:null,model:'unknown',effort:'medium',projectLabel:'cli',projectState:'named',lastObservedAt:ago(6),state:'idle',rate:40,startedAt:ago(31),observedOutputTokens:96000},
  {sessionRef:'0000000000000003',source:'codex',subscriptionRef:null,model:'Sol 6.1',effort:null,projectLabel:'desktop',projectState:'named',lastObservedAt:ago(0),state:'running',rate:null},
 ];
 return data;
}
const cells=row=>row.evaluate(e=>[...e.children].map(c=>c.className.split(' ')[0]));

test('CKP-STRIP-16 a line reads chip, tool, project, model and effort, elapsed, tokens, then the right end',async({page})=>{
 await open(page,stripData());const rows=page.locator('.ck-tape .t-observed');await expect(rows).toHaveCount(3);
 expect(await cells(rows.first())).toEqual(['chip','t-tool','t-proj','t-me','t-elapsed','t-tok','t-live']);
 const first=rows.nth(0);
 await expect(first.locator('.t-tool')).toHaveText('Claude');await expect(first.locator('.t-proj')).toHaveText('modelplans.ai');
 await expect(first.locator('.t-me')).toHaveText('Opus 5.5 High');await expect(first.locator('.t-elapsed')).toHaveText('42m');await expect(first.locator('.t-tok')).toHaveText('310k');
 await expect(first.locator('.t-live')).toHaveText('● 61 t/s');await expect(first.locator('.t-live .t-cur')).toHaveCount(1);
 await expect(first).toHaveAttribute('aria-label','Claude · modelplans.ai · Opus 5.5 High · Elapsed 42m · 310k tokens · Running · Session rate 61 t/s');
 // A running session whose speed is not measurable yet, with no start or tokens: "--", never zero.
 const third=rows.nth(1);await expect(third.locator('.t-tool')).toHaveText('Codex');await expect(third.locator('.t-me')).toHaveText('Sol 6.1');
 await expect(third.locator('.t-elapsed')).toHaveText('--');await expect(third.locator('.t-tok')).toHaveText('--');await expect(third.locator('.t-live')).toHaveText('● -- t/s');
 for(const row of await rows.all())await expect(row.locator('.t-time,.t-dot')).toHaveCount(0);
});

test('CKP-STRIP-09 an idle line ends in its age only, with no speed and no cursor; it follows the clock',async({page})=>{
 const {send,receive}=await open(page,stripData()),idle=page.locator('.ck-tape .t-observed[data-session="0000000000000002"]');
 await expect(idle.locator('.t-live')).toHaveText('6m ago');await expect(idle.locator('.t-live .t-cur')).toHaveCount(0);await expect(idle.locator('.t-elapsed')).toHaveText('25m');await expect(idle.locator('.t-tok')).toHaveText('96k');
 const deadline=await page.evaluate(()=>window.__events.filter(e=>e.type==='nextDeadline').at(-1)?.deadlineUnixMs);expect(deadline).toBe(String(NOW+60000));
 expect(await receive(send('tick',{nowUnixMs:String(NOW+3*60000),reason:'deadline'}))).toBe(true);
 await expect(idle.locator('.t-live')).toHaveText('9m ago');await expect(page.locator('.ck-tape .t-observed').first().locator('.t-elapsed')).toHaveText('45m');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(idle.locator('.t-live')).toHaveText('9m前');
});

test('CKP-STRIP-17 tools use display names and an unknown model reads as dim "Unknown model"',async({page})=>{
 const {send,receive}=await open(page,stripData()),idle=page.locator('.ck-tape .t-observed[data-session="0000000000000002"]'),model=idle.locator('.t-model');
 await expect(idle.locator('.t-tool')).toHaveText('Codex');await expect(model).toHaveText('Unknown model');await expect(model).toHaveClass(/\bt-unknown\b/);await expect(idle.locator('.t-eff')).toHaveText('Med');
 const [dim,named]=await Promise.all([model,page.locator('.ck-tape .t-observed').first().locator('.t-model')].map(l=>l.evaluate(e=>getComputedStyle(e).color+'|'+getComputedStyle(e).opacity)));
 expect(dim).not.toBe(named);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);await expect(model).toHaveText('未知模型');
});

test('CKP-STRIP-16 the strip text fits without clipping in both locales and tiers',async({page})=>{
 const {send,receive}=await open(page,stripData());
 for(const tier of ['tall','compact'])for(const locale of ['en','zh-CN']){
  expect(await receive(send('shell',{...shell,tier}))).toBe(true);expect(await receive(send('appearance',{...appearance,locale}))).toBe(true);
  for(const cell of await page.locator('.ck-tape .t-observed :is(.t-tool,.t-elapsed,.t-tok,.t-live)').all()){const size=await cell.evaluate(e=>({scroll:e.scrollWidth,client:e.clientWidth,text:e.textContent}));expect(size.scroll,`${tier} ${locale} ${size.text}`).toBeLessThanOrEqual(size.client);}
 }
});
