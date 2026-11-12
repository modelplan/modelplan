// SPDX-License-Identifier: MIT
// CKP-MFD-33 (D165, D177, D190, D201; owner-approved demo v12 "B + notches", 11-12): the comparison on the big screen
// shows two stereo-lane bars, ability (white) and cost (violet), whose full length is the model's own top effort
// (= 100 %, Max), above a line chart of ability, cost and time as shares of that effort. The whole 0-100 % track is always
// drawn and ends in a 100 % stop; notches every 10 % are cut into the tube (50 % at full height). No trial: one solid bar.
// A trial splits the tube into two lanes from 0: real on top, trial (blue) below. ★ = a thin gold line with a small ★
// ABOVE the bar, so no number ever reads as "★92%". Bars and chart are linked by hover. The built page through its normal
// bridge (fader LCD, effort keys); synthetic profile only.
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
  const fill=g.querySelector('.pc-fill'),lane=g.querySelector('.pc-lane-trial'),rec=g.querySelector('.pc-rec'),end=g.querySelector('.pc-end');
  const box=e=>{const b=e.getBBox();return {top:b.y,bottom:b.y+b.height,left:b.x,right:b.x+b.width};};
  out[k]={track:{x:L,y:n(track,'y'),w:W,h:n(track,'height')},end:end?{right:n(end,'x')+n(end,'width'),w:n(end,'width'),h:n(end,'height')}:null,
   fill:fill?{w:n(fill,'width')/W,y:n(fill,'y'),h:n(fill,'height'),v:n(fill,'data-v')}:null,lane:lane?{w:n(lane,'width')/W,y:n(lane,'y'),h:n(lane,'height'),x:at(n(lane,'x')),v:n(lane,'data-v')}:null,
   rec:rec?at(n(rec,'x')+n(rec,'width')/2):null,
   notches:[...g.querySelectorAll('.pc-notch')].map(e=>({p:n(e,'data-p'),x:at(n(e,'x')+.5),h:n(e,'height'),on:e.classList.contains('on'),mid:e.classList.contains('mid')})),
   numbers:[...g.querySelectorAll('.pc-num')].map(e=>({role:e.dataset.role,text:e.textContent,equal:e.dataset.equal==='true',fill:getComputedStyle(e).fill})),
   over:g.querySelector('.pc-over')?{trial:g.querySelector('.pc-over').classList.contains('trial')}:null,
   bar:box(track),stars:[...g.querySelectorAll('.pc-star')].map(box),numberBoxes:[...g.querySelectorAll('.pc-num')].map(e=>({...box(e),top:n(e,'y')-7})),
   max:[...g.querySelectorAll('.pc-max')].map(e=>({text:e.textContent,bottom:box(e).bottom,right:box(e).right})),
   segs:[...svg.querySelectorAll(`.pc-seg-hit[data-hk="${k}"]`)].map(e=>({l:e.dataset.hover,x0:at(n(e,'x')+.5),x1:at(n(e,'x')+n(e,'width')-.5),mfd:e.dataset.mfd}))};
 }
 return out;
});
const near=(a,b,eps=.012)=>expect(Math.abs(a-b),`${a} ≈ ${b}`).toBeLessThan(eps);

test('CKP-MFD-33 idle: the full 0-100 % track and its end bar are always drawn; one solid bar to the current effort; ★ a gold line with ★ above',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await expect(screen.locator('table.cmp')).toHaveCount(0);
 const b=await bars(page);
 for(const k of ['abl','cost']){
  // the track spans the whole scale and ends in the bright 100 % stop; the tube is 11 px (tall), the fill 9 px inside the 1 px outline
  near(b[k].track.w/(b[k].track.w),1);expect(b[k].track.h).toBe(11);
  expect(b[k].end.h).toBe(14);near(b[k].end.right,b[k].track.x+b[k].track.w,.6);
  near(b[k].fill.w,SOL.High[k]);near(b[k].fill.v,SOL.High[k]);expect(b[k].fill.h).toBe(9);
  near(b[k].rec,SOL.Med[k]);expect(b[k].lane).toBeNull();
  expect(b[k].numbers.map(n=>[n.role,n.text])).toEqual([['current',pct(SOL.High[k])]]);
  expect(b[k].over).toBeNull();
 }
 // "100%" once, above the ability bar only
 expect(b.abl.max.map(m=>m.text)).toEqual(['100%']);expect(b.cost.max).toEqual([]);
 expect(b.abl.max[0].bottom).toBeLessThanOrEqual(b.abl.bar.top+.5);near(b.abl.max[0].right,b.abl.track.x+b.abl.track.w+8,10);
 await expect(screen.locator('svg.cmp-bars .pc-label')).toHaveText(['Ability','Cost']);
 // the line chart below: ability, cost and time; the current column tinted; ★ on the ability line
 const chart=screen.locator('svg.cmp-chart');
 await expect(chart.locator('.pc-line')).toHaveCount(3);
 await expect(chart.locator('.pc-line.pc-time polyline')).toHaveCount(1);
 await expect(chart.locator('.pc-band-current')).toHaveAttribute('data-effort','High');
 await expect(chart.locator('.pc-band-trial')).toHaveCount(0);
 await expect(chart.locator('.pc-line.pc-abl .pc-star')).toHaveCount(1);
 await expect(chart.locator('.pc-legend')).toContainText('Time');
 await expect(screen.locator('.cmp-lad .lad')).toHaveText(['Low','★Med','High','XHigh','Max']);
});

test('CKP-MFD-33 notches: nine cuts every 10 %, the one at 50 % at full height, glass inside the fill and tinted outside it',async({page})=>{
 await open(page);
 await openSol(page);
 const b=await bars(page);
 for(const k of ['abl','cost']){
  const all=b[k].notches,per=all.filter(x=>x.p!==50);
  expect([...new Set(all.map(x=>x.p))]).toEqual([10,20,30,40,50,60,70,80,90]);
  for(const x of all)near(x.x,x.p/100,.02);
  const mid=all.filter(x=>x.mid);expect(mid).toHaveLength(1);expect(mid[0].h).toBe(9);
  for(const x of per)expect(x.h).toBe(2); // each of the others is a short notch at the top and one at the bottom
  expect(per).toHaveLength(16);
  for(const x of all)expect(x.on,`${x.p}% against the fill at ${SOL.High[k]}`).toBe(x.p/100<SOL.High[k]-.005);
 }
});

test('CKP-MFD-33 trial higher: the tube splits into two lanes from 0, real on top (5 px) and the trial blue below (3 px); the trial column is tinted',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 const b=await bars(page);
 for(const k of ['abl','cost']){
  near(b[k].fill.w,SOL.High[k]);near(b[k].lane.w,SOL.XHigh[k]);near(b[k].lane.x,0,.005);
  expect(b[k].fill.h).toBe(5);expect(b[k].lane.h).toBe(3);expect(b[k].lane.y).toBeGreaterThan(b[k].fill.y+b[k].fill.h-.01);
  expect(b[k].lane.w).toBeGreaterThan(b[k].fill.w);
  expect(b[k].numbers.map(n=>[n.role,n.text,n.equal])).toEqual([['current',pct(SOL.High[k]),false],['trial',pct(SOL.XHigh[k]),false]]);
 }
 const chart=screen.locator('svg.cmp-chart');
 await expect(chart.locator('.pc-band-trial')).toHaveAttribute('data-effort','XHigh');
 await expect(chart.locator('.pc-ring[data-role="trial"]')).toHaveCount(2);
 // a chart column is a trial key too
 await chart.locator('.pc-hit[data-mfd="try:Low"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('Low');
});

test('CKP-MFD-33 trial lower: the trial lane stops short of the real lane; blue number left of the white one',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await screen.locator('.cmp-lad [data-mfd="try:Low"]').click();
 const b=await bars(page);
 for(const k of ['abl','cost']){
  near(b[k].fill.w,SOL.High[k]);near(b[k].lane.w,{abl:33.9/47.5,cost:.132/1.056}[k]);
  expect(b[k].lane.w).toBeLessThan(b[k].fill.w);
  expect(b[k].numbers.map(n=>n.role)).toEqual(['current','trial']);
 }
});

test('CKP-MFD-33 ★ placement: the ★ line sits at the recommended effort; "100%" is hidden when ★ is near the end (Luna ★ at 94 %)',async({page})=>{
 await open(page);
 await page.locator('[data-bank="1"]').click();
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Luna'}).first().locator('.fd-strip').click();
 await expect(page.locator('.mfd-page.pg-compare .mfd-title')).toContainText('Luna');
 const b=await bars(page);
 near(b.abl.rec,31/33);expect(b.abl.max).toEqual([]);
 expect(b.abl.rec).toBeGreaterThan(.9);
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

test('CKP-MFD-33 A1: the small cockpit keeps both bars (9 px tube, 4 + 2 px lanes) and a readable chart under them',async({page})=>{
 await open(page,{tier:'compact',height:640});
 const screen=await openSol(page);
 let b=await bars(page);near(b.abl.fill.w,SOL.High.abl);near(b.cost.fill.w,SOL.High.cost);
 expect(b.abl.track.h).toBe(9);expect(b.abl.fill.h).toBe(7);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 b=await bars(page);expect(b.abl.fill.h).toBe(4);expect(b.abl.lane.h).toBe(2);
 const sizes=await screen.evaluate(s=>({bars:s.querySelector('svg.cmp-bars').getBoundingClientRect().height,
  chart:s.querySelector('svg.cmp-chart')?.getBoundingClientRect().height??0,lines:s.querySelectorAll('svg.cmp-chart .pc-line').length}));
 expect(sizes.bars).toBe(58);expect(sizes.chart).toBeGreaterThanOrEqual(50);expect(sizes.lines).toBe(3);
});

test('CKP-MFD-33 chart link: a bar row sets its chart line apart; a bar segment draws the dashed box on the chart column; a chart column or effort key draws the dashed line on both bars; a click tries the effort',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 const chart=screen.locator('svg.cmp-chart'),bars_=screen.locator('svg.cmp-bars');
 const width=sel=>chart.locator(sel).evaluate(e=>parseFloat(getComputedStyle(e).strokeWidth));
 const opacity=sel=>chart.locator(sel).evaluate(e=>Number(getComputedStyle(e).opacity));
 // 1. hover the Ability row (its label area): that line thickens, the others dim
 const w0=await width('.pc-line.pc-abl polyline');
 await bars_.locator('.pc-hit[data-hk="abl"]').first().hover();
 await expect(screen).toHaveAttribute('data-hk','abl');
 await expect.poll(()=>width('.pc-line.pc-abl polyline')).toBeGreaterThan(w0);
 await expect.poll(()=>opacity('.pc-line.pc-cost')).toBeLessThan(.5);
 await expect.poll(()=>opacity('.pc-line.pc-time')).toBeLessThan(.5);
 await expect.poll(()=>opacity('.pc-line.pc-abl')).toBe(1);
 await bars_.locator('.pc-hit[data-hk="cost"]').first().hover();
 await expect(screen).toHaveAttribute('data-hk','cost');
 await expect.poll(()=>opacity('.pc-line.pc-abl')).toBeLessThan(.5);
 // 2. hover a bar segment (XHigh): the dashed box on that chart column, the dashed line on both bars
 await expect(chart.locator('.pc-band-hover.hot')).toHaveCount(0);
 await bars_.locator('.pc-seg-hit[data-hover="XHigh"][data-hk="abl"]').hover();
 await expect(chart.locator('.pc-band-hover.hot')).toHaveAttribute('data-effort','XHigh');
 await expect(bars_.locator('.pc-preview.hot')).toHaveCount(2);
 await expect(chart.locator('.pc-band-hover.hot')).toBeVisible();
 // 3. hover a chart column and an effort key
 await chart.locator('.pc-hit[data-hover="Low"]').hover();
 await expect(chart.locator('.pc-band-hover.hot')).toHaveAttribute('data-effort','Low');
 await expect(bars_.locator('.pc-preview.hot')).toHaveCount(2);
 await expect(bars_.locator('.pc-preview.hot').first()).toHaveAttribute('data-effort','Low');
 await screen.locator('.cmp-lad [data-hover="Max"]').hover();
 await expect(chart.locator('.pc-band-hover.hot')).toHaveAttribute('data-effort','Max');
 await expect(bars_.locator('.pc-preview.hot')).toHaveCount(2);
 // the dashed line stands at the hovered effort's value (Max = 100 %)
 const x=await bars_.locator('.pc-abl .pc-preview.hot').evaluate(l=>Number(l.getAttribute('x1')));
 const t=await bars_.locator('.pc-abl .pc-track').evaluate(e=>[Number(e.getAttribute('x')),Number(e.getAttribute('width'))]);
 near((x-t[0])/t[1],1,.03);
 // 4. leaving clears it; the current effort's own key... and clicking a bar segment tries that effort
 await page.mouse.move(2,2);
 await expect(chart.locator('.pc-band-hover.hot')).toHaveCount(0);await expect(screen).not.toHaveAttribute('data-hk',/.*/);
 await bars_.locator('.pc-seg-hit[data-hover="XHigh"][data-hk="cost"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 expect((await bars(page)).cost.lane.v).toBeCloseTo(SOL.XHigh.cost,2);
 // the trial effort itself has no preview (the lane shows it)
 await expect(bars_.locator('.pc-preview[data-effort="XHigh"]')).toHaveCount(0);
 // every effort is a segment, together covering the track from 0 to the top effort
 const segs=(await bars(page)).abl.segs;expect(segs.map(s=>s.l)).toEqual(['Low','Med','High','XHigh','Max']);
 near(segs[0].x0,0,.01);near(segs.at(-1).x1,1,.02);
});
