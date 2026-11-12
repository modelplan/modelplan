// SPDX-License-Identifier: MIT
// CKP-MFD-33 (D165, D177, D190, D201; owner-approved demo v8): the comparison on the big screen shows two bars,
// ability (white) and cost (violet), whose full length is the model's own top effort (= 100 %, Max), above a line chart
// of ability, cost and time as shares of that effort. Current = white tick + number under the bar; trial = blue tick,
// blue number and a blue segment between the two; ★ = a thin gold line with a small ★ ABOVE the bar, so no number ever
// reads as "★92%". The built page through its normal bridge (fader LCD, effort keys); synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,{locale='en',tier='tall',height=890,theme='night'}={}){
 await page.setViewportSize({width:636,height});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale,theme},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
}
// GPT-6.1 Sol in the build-13 profile: running at High, ★ Med, top effort Max (ability 47.5, cost 1.056, time 221).
const SOL={High:{abl:42.8/47.5,cost:.375/1.056},XHigh:{abl:46/47.5,cost:.63/1.056},Med:{abl:39.8/47.5,cost:.248/1.056}};
const pct=v=>Math.round(v*100)+'%';
async function openSol(page){
 await page.locator('.fd-ch:not(.empty)').first().locator('.fd-strip').click();
 const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
 await expect(screen.locator('.mfd-title')).toContainText('Sol 6.1');
 return screen;
}
// Every reading in SVG user units (= CSS px: the svg is drawn at its measured size).
const bars=page=>page.locator('svg.cmp-bars').evaluate(svg=>{
 const n=(e,a)=>e?Number(e.getAttribute(a)):null,out={};
 for(const k of ['abl','cost']){
  const g=svg.querySelector(`.pc-${k}`),track=g.querySelector('.pc-track'),L=n(track,'x'),W=n(track,'width'),at=x=>(x-L)/W;
  const fill=g.querySelector('.pc-fill'),seg=g.querySelector('.pc-seg'),rec=g.querySelector('.pc-rec'),tick=r=>g.querySelector(`.pc-tick[data-role="${r}"]`);
  const box=e=>{const b=e.getBBox();return {top:b.y,bottom:b.y+b.height,left:b.x,right:b.x+b.width};};
  out[k]={fill:fill?n(fill,'width')/W:null,rec:rec?at(n(rec,'x')+n(rec,'width')/2):null,
   current:tick('current')?at(n(tick('current'),'x')+1):null,trial:tick('trial')?at(n(tick('trial'),'x')+1):null,
   seg:seg?[at(n(seg,'x')),at(n(seg,'x')+n(seg,'width'))]:null,
   numbers:[...g.querySelectorAll('.pc-num')].map(e=>({role:e.dataset.role,text:e.textContent})),
   bar:box(track),stars:[...g.querySelectorAll('.pc-star')].map(box),numberBoxes:[...g.querySelectorAll('.pc-num')].map(box)};
 }
 return out;
});
const near=(a,b,eps=.012)=>expect(Math.abs(a-b),`${a} ≈ ${b}`).toBeLessThan(eps);

test('CKP-MFD-33 idle: the bars are shares of the top effort, current white with its number below, ★ a gold line with ★ above',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await expect(screen.locator('table.cmp')).toHaveCount(0);
 const b=await bars(page);
 for(const k of ['abl','cost']){
  near(b[k].fill,SOL.High[k]);near(b[k].current,SOL.High[k]);near(b[k].rec,SOL.Med[k]);
  expect(b[k].trial).toBeNull();expect(b[k].seg).toBeNull();
  expect(b[k].numbers).toEqual([{role:'current',text:pct(SOL.High[k])}]);
 }
 await expect(screen.locator('svg.cmp-bars .pc-label')).toHaveText(['Ability','Cost']);
 // The line chart below: ability, cost and time; the current column tinted; ★ on the ability line.
 const chart=screen.locator('svg.cmp-chart');
 await expect(chart.locator('.pc-line')).toHaveCount(3);
 await expect(chart.locator('.pc-line.pc-time polyline')).toHaveCount(1);
 await expect(chart.locator('.pc-band-current')).toHaveAttribute('data-effort','High');
 await expect(chart.locator('.pc-band-trial')).toHaveCount(0);
 await expect(chart.locator('.pc-line.pc-abl .pc-star')).toHaveCount(1);
 await expect(chart.locator('.pc-legend')).toContainText('Time');
 await expect(screen.locator('.cmp-lad .lad')).toHaveText(['Low','★Med','High','XHigh','Max']);
});

test('CKP-MFD-33 trial: a blue tick, a blue number and a blue segment between current and trial; the trial column tinted',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 const b=await bars(page);
 for(const k of ['abl','cost']){
  near(b[k].current,SOL.High[k]);near(b[k].trial,SOL.XHigh[k]);near(b[k].fill,SOL.High[k]);
  near(b[k].seg[0],SOL.High[k]);near(b[k].seg[1],SOL.XHigh[k]);
  expect(b[k].numbers).toEqual([{role:'current',text:pct(SOL.High[k])},{role:'trial',text:pct(SOL.XHigh[k])}]);
 }
 const chart=screen.locator('svg.cmp-chart');
 await expect(chart.locator('.pc-band-trial')).toHaveAttribute('data-effort','XHigh');
 await expect(chart.locator('.pc-ring[data-role="trial"]')).toHaveCount(2);
 // A chart column is a trial key too.
 await chart.locator('.pc-hit[data-mfd="try:Low"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('Low');
});

test('CKP-MFD-33 no "★<number>": every ★ sits above its bar, every number below it, and no text joins ★ to a digit',async({page})=>{
 await open(page,{locale:'zh-CN'});
 const screen=await openSol(page);
 // Try ★ itself: the trial number lands on the ★ line, the case that used to read "★84%".
 await screen.locator('.cmp-lad [data-mfd="try:Med"]').click();
 const b=await bars(page);
 for(const k of ['abl','cost']){
  expect(b[k].stars).toHaveLength(1);expect(b[k].numberBoxes.length).toBe(2);
  for(const s of b[k].stars)expect(s.bottom).toBeLessThanOrEqual(b[k].bar.top+.5);
  for(const box of b[k].numberBoxes)expect(box.top).toBeGreaterThanOrEqual(b[k].bar.bottom);
 }
 expect(await screen.innerText()).not.toMatch(/★\s*\d/);
 await expect(screen.locator('svg.cmp-bars .pc-label')).toHaveText(['能力','花费']);
 await expect(screen.locator('svg.cmp-chart .pc-legend')).toContainText('耗时');
});

test('CKP-MFD-33 A1: the small cockpit keeps both bars and a readable chart under them',async({page})=>{
 await open(page,{tier:'compact',height:640});
 const screen=await openSol(page);
 const b=await bars(page);near(b.abl.fill,SOL.High.abl);near(b.cost.fill,SOL.High.cost);
 const sizes=await screen.evaluate(s=>({bars:s.querySelector('svg.cmp-bars').getBoundingClientRect().height,
  chart:s.querySelector('svg.cmp-chart')?.getBoundingClientRect().height??0,lines:s.querySelectorAll('svg.cmp-chart .pc-line').length}));
 expect(sizes.bars).toBe(58);expect(sizes.chart).toBeGreaterThanOrEqual(50);expect(sizes.lines).toBe(3);
});
