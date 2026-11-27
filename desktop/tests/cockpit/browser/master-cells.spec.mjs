// SPDX-License-Identifier: MIT
// D474 master spec (round 5), #1290, on the built page through its normal bridge, synthetic data only:
// - decision 1 / C26 (§3.2): two lines per quota cell, wide (3 columns) and narrow (6 columns), zh and en; line 1 is the
//   reset in ink-3 and never coloured; line 2 the estimate in amber only when it runs out first, else faint 够用.
// - used up: line 2 已用完 in red. §3.4: 失败·2h keeps the numbers; a kept reading whose reset passed lapses to -- 读不到.
// - C33: a cell names its extra window only under the 额外 heading.
// - decision 3 (C13, C45): with the host's `seen` set, a never-read subscription has no column and keeps its grey line.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=Date.parse('2026-11-27T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
async function open(page,data,locale='zh-CN',before=[]){
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 for(const [type,fields] of before)expect(await receive(send(type,fields))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// n subscriptions cloned from the visual fixture's first one; every reading current; 5h resets in 4d14h... per case.
function fixture(n){
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];data.details.forecasts=[];data.details.resetEvents=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0'),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref,accountLocator:ref,valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
  a.windows=a.windows.slice(0,2);
  Object.assign(a.windows[0],{current:true,validUntil:iso(600),resetsAt:iso(189),remainingPercent:90});
  Object.assign(a.windows[1],{current:true,validUntil:iso(600),resetsAt:iso(6600),remainingPercent:53});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref,today:[{...detail.today[0],source:row.id}]});
 }
 const account=i=>data.projection.rows[i].accounts[0];
 const forecast=(i,j,minutes)=>data.details.forecasts.push({source:data.projection.rows[i].id,subscriptionRef:account(i).subscriptionRef,windowId:account(i).windows[j].id,runsOutAt:minutes===null?null:iso(minutes),pace:minutes===null?'on_track':'tight',basis:'recent-rate',observedAt:iso(-2)});
 const sync=()=>{for(const [i,s] of data.subscriptions.entries())s.accounts[0].account=structuredClone(account(i));};
 return {data,account,forecast,sync};
}
const cell=(page,i,row)=>page.locator('.eng-cols > .ec[data-col]').nth(i).locator(`.qcell[data-row="${row}"]`);
const colour=(locator,css)=>locator.evaluate((e,css)=>{const p=document.createElement('i');p.style.color=css;e.parentElement.append(p);const r=[getComputedStyle(e).color,getComputedStyle(p).color];p.remove();return r;},css);

for(const [locale,cols,l1,est,lasts] of [
 ['zh-CN',3,'4d14h 后重置','预估 2d16h 用完','够用到重置'],['zh-CN',6,'4d14h后','2d16h完','够用'],
 ['en',3,'resets in 4d14h','est. out in 2d16h','lasts to reset'],['en',6,'in 4d14h','out 2d16h','lasts']])
 test(`decision 1: two lines per cell, ${cols} columns (${locale})`,async({page})=>{
  const {data,forecast,sync}=fixture(cols);
  forecast(0,1,3840);forecast(0,0,null);sync();// weekly runs out in 2d16h, before its 4d14h reset; 5h lasts
  await open(page,data,locale);
  await expect(page.locator('.eng-lcd')).toHaveClass(new RegExp(`cls-${cols<=3?'wide':'narrow'}`));
  const weekly=cell(page,0,'second');
  await expect(weekly.locator('.ql1')).toHaveText(l1);await expect(weekly.locator('.ql2')).toHaveText(est);
  await expect(weekly.locator('.ql2')).toHaveClass(/\bwarn\b/);await expect(weekly).toHaveClass(/\blv-mid\b/);
  const [ink,muted]=await colour(weekly.locator('.ql1'),'var(--lcd-muted)');expect(ink,'the reset line is never coloured').toBe(muted);
  const [amber,mid]=await colour(weekly.locator('.ql2'),'var(--st-mid)');expect(amber).toBe(mid);
  const five=cell(page,0,'first');
  await expect(five.locator('.ql2')).toHaveText(lasts);
  const [faint,ink3]=await colour(five.locator('.ql2'),'var(--lcd-muted)');expect(faint,'够用 is ink-3').toBe(ink3);
  await expect(five).toHaveClass(/\blv-ok\b/);
  // No forecast: no line 2 at all; nothing is ever cut with an ellipsis or says 约.
  await expect(cell(page,1,'first').locator('.ql2')).toHaveCount(0);
  expect(await page.locator('.ck-eng').innerText()).not.toMatch(/…|约|~/);
 });

for(const [locale,usedUp,fail,unread] of [['zh-CN','已用完','失败·2h','读不到'],['en','used up','Fail·2h','no reading']])
 test(`used up, 失败·2h and the lapse rule (${locale})`,async({page})=>{
  const {data,account,sync}=fixture(3);
  account(0).windows[0].remainingPercent=0;
  Object.assign(account(1),{valueState:'retained',observedAt:iso(-120),lastFailure:{at:iso(-5),code:'network'}});
  Object.assign(account(2),{valueState:'retained',observedAt:iso(-400),lastFailure:{at:iso(-5),code:'network'}});account(2).windows[0].resetsAt=iso(-10);
  sync();await open(page,data,locale);
  await expect(cell(page,0,'first').locator('.qvalue')).toHaveText('0');
  await expect(cell(page,0,'first').locator('.ql2.crit')).toHaveText(usedUp);
  await expect(cell(page,1,'first').locator('.qvalue')).toHaveText('90');await expect(cell(page,1,'first').locator('.ql1')).toHaveText(fail);
  await expect(cell(page,2,'first').locator('.qvalue')).toHaveText('--');await expect(cell(page,2,'first').locator('.ql1')).toHaveText(unread);
  await expect(cell(page,2,'second').locator('.qvalue'),'only the lapsed window').toHaveText('53');
  await expect(page.locator('.eng-cols > .ec[data-col]')).toHaveCount(3);
 });

test('C33: names only under the 额外 heading; the hover names the period',async({page})=>{
 const {data,account,sync}=fixture(2);
 const extra=(i,label,limitKey,role,resetMin)=>{const dur=role==='monthly'?2592000:604800,pool=limitKey==='mcp'?'main':limitKey;const w={...structuredClone(account(i).windows[0]),id:`${role}:${dur}:${limitKey}:${pool}`,role,durationSeconds:dur,limitKey,poolKey:pool,label:{en:label,zh:label},remainingPercent:64,resetsAt:iso(resetMin)};if(limitKey==='mcp')delete w.modelScope;else w.modelScope={models:['opus']};account(i).windows.push(w);};
 extra(0,'MCP','mcp','monthly',21540);extra(1,'Opus','opus','weekly',3480);sync();
 await open(page,data);
 await expect(page.locator('.eng-labels .lb-other')).toHaveText('额外');
 await expect(cell(page,0,'other').locator('.ql1')).toHaveText('MCP 14d23h 后重置');
 await expect(cell(page,0,'other')).toHaveAttribute('data-tip',/MCP · 每月额度/);
});

test('decision 3: with the host seen set a never-read subscription has no column; its grey line stays',async({page})=>{
 const {data,account,sync}=fixture(3);
 Object.assign(account(2),{valueState:'none',observedAt:null,windows:[],lastFailure:{at:iso(-1),code:'not_signed_in'}});sync();
 const seen=[account(0).subscriptionRef,account(1).subscriptionRef];
 const {send,receive}=await open(page,data,'en',[['seen',{ids:seen}]]);
 await expect(page.locator('.eng-cols > .ec[data-col]')).toHaveCount(2);
 await page.locator('[data-caution]').click();
 await expect(page.locator('.pg-alerts .mfd-alerts.all li.al-grey')).toHaveText(/Sub 3 no reading · not signed in/);
 // Read before on this Mac: the column stays with -- 读不到.
 expect(await receive(send('seen',{ids:[...seen,account(2).subscriptionRef]}))).toBe(true);
 await expect(page.locator('.eng-cols > .ec[data-col]')).toHaveCount(3);
 await expect(cell(page,2,'first').locator('.qvalue')).toHaveText('--');
});
