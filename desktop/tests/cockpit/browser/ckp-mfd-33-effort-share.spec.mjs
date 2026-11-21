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
import {firstPixel} from '../png-pixel.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,{locale='en',tier='tall',height=890,theme='night',edit=null}={}){
 await page.setViewportSize({width:636,height});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale,theme},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=build13Profile();edit?.(data);
 expect(await receive(send('display',{data}))).toBe(true);
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
 // no gold wash on the ★ column (the ★ on the key and the bar is enough)
 await expect(chart.locator('.pc-band-rec')).toHaveCount(0);
 // rendered pixels: the current column is a neutral, clearly lighter haze than the empty chart
 const cb=await chart.locator('.pc-band-current').boundingBox(),eb=await chart.locator('.pc-hit[data-hover="Max"]').boundingBox();
 const at=async(bb,dx)=>firstPixel(await page.screenshot({clip:{x:bb.x+bb.width/2+dx,y:bb.y+bb.height-9,width:1,height:1}}));
 const cur=await at(cb,-8),empty=await at(eb,-8),lum=q=>.3*q[0]+.59*q[1]+.11*q[2];
 expect(Math.max(...cur.slice(0,3))-Math.min(...cur.slice(0,3)),`current ${cur}`).toBeLessThanOrEqual(12);
 expect(lum(cur)-lum(empty),`current ${cur} vs empty ${empty}`).toBeGreaterThanOrEqual(35);
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

test('CKP-MFD-33 trial higher: the tube splits into two lanes from 0, real on top (4.5 px), a 1.5 px glass gap and the trial blue below (3 px); the trial column is tinted',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 const b=await bars(page);
 for(const k of ['abl','cost']){
  near(b[k].fill.w,SOL.High[k]);near(b[k].lane.w,SOL.XHigh[k]);near(b[k].lane.x,0,.005);
  expect(b[k].fill.h).toBe(4.5);expect(b[k].lane.h).toBe(3);expect(b[k].lane.y).toBeGreaterThan(b[k].fill.y+b[k].fill.h-.01);
  expect(b[k].lane.w).toBeGreaterThan(b[k].fill.w);
  expect(b[k].numbers.map(n=>[n.role,n.text,n.equal])).toEqual([['current',pct(SOL.High[k]),false],['trial',pct(SOL.XHigh[k]),false]]);
 }
 const chart=screen.locator('svg.cmp-chart');
 await expect(chart.locator('.pc-band-trial')).toHaveAttribute('data-effort','XHigh');
 await expect(chart.locator('.pc-ring[data-role="trial"]')).toHaveCount(2);
 // rendered pixels: the trial column is a light blue haze (hue 200-215 degrees, visible saturation), lighter than the empty chart
 // sampled just below the 0 % baseline, inside the column, where no series line can pass (the chart is shorter since
 // the key numbers joined the page, so 9 px up now lands on Low's cost line)
 {const tb=await chart.locator('.pc-band-trial').boundingBox(),eb=await chart.locator('.pc-hit[data-hover="Low"]').boundingBox();
  const px=async(bb,dx)=>firstPixel(await page.screenshot({clip:{x:bb.x+bb.width/2+dx,y:bb.y+bb.height-3,width:1,height:1}}));
  const [r,g,b]=await px(tb,-8),e=await px(eb,6),mx=Math.max(r,g,b),mn=Math.min(r,g,b),hue=60*(4+(r-g)/(mx-mn)),sat=(mx-mn)/mx;
  expect(hue,`trial ${r},${g},${b}`).toBeGreaterThan(200);expect(hue,`trial ${r},${g},${b}`).toBeLessThan(220);expect(sat).toBeGreaterThan(.3);
  expect(.3*r+.59*g+.11*b-(.3*e[0]+.59*e[1]+.11*e[2])).toBeGreaterThanOrEqual(35);}
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

test('CKP-MFD-33 A1: the small cockpit keeps both bars (9 px tube, 3.5 + 1.5 + 2 px lanes) and a readable chart under them',async({page})=>{
 await open(page,{tier:'compact',height:640});
 const screen=await openSol(page);
 let b=await bars(page);near(b.abl.fill.w,SOL.High.abl);near(b.cost.fill.w,SOL.High.cost);
 expect(b.abl.track.h).toBe(9);expect(b.abl.fill.h).toBe(7);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 b=await bars(page);expect(b.abl.fill.h).toBe(3.5);expect(b.abl.lane.h).toBe(2);
 const sizes=await screen.evaluate(s=>({bars:s.querySelector('svg.cmp-bars').getBoundingClientRect().height,
  chart:s.querySelector('svg.cmp-chart')?.getBoundingClientRect().height??0,lines:s.querySelectorAll('svg.cmp-chart .pc-line').length}));
 // V1-FINAL §13.3 (WP-05): the short cockpit keeps the bars and the keys WITH their two numbers; the chart gets shorter but stays
 // (34 px is the view's own floor for drawing it).
 expect(sizes.bars).toBe(58);expect(sizes.chart).toBeGreaterThanOrEqual(34);expect(sizes.lines).toBe(3);
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

// CKP-MFD-52 as ruled for v1 final (V1-FINAL §8.5, LATER; supersedes the macrevc-885-1 rule for ABILITY only): ability is a
// share of the model's highest-scoring effort, so a top effort without a score no longer blanks every ability number. Cost
// keeps the top effort as its reference (macrevc-885-1 still holds for cost and time, each metric independently).
test('CKP-MFD-52 top effort without a published ability: ability is a share of the best-scoring effort, which is named; cost keeps the top effort',async({page})=>{
 const dropMaxAbility=data=>{const drop=list=>list.map(m=>{if(m.id!=='gpt-6.1-sol')return m;const c=structuredClone(m);for(const e of c.efforts)if(e.effort==='max')e.ability=null;return c;});data.details.publishedModels=drop(data.details.publishedModels);data.details.publication.models=drop(data.details.publication.models);};
 await open(page,{edit:dropMaxAbility});
 const screen=await openSol(page);
 const b=await bars(page);
 near(b.cost.fill.w,SOL.High.cost);expect(b.cost.numbers.map(n=>n.text)).toEqual([pct(SOL.High.cost)]);
 near(b.abl.fill.w,42.8/46);expect(b.abl.numbers.map(n=>n.text)).toEqual([pct(42.8/46)]);
 expect(b.abl.max.map(m=>m.text)).toEqual(['100% = XHigh']);
 await expect(screen.locator('.cmp-nums .lad-n[data-effort="Max"] .lad-a')).toHaveText('—');
 await expect(screen.locator('.cmp-nums .lad-n[data-effort="XHigh"] .lad-a')).toHaveText('100%');
 await expect(screen.locator('svg.cmp-chart')).toBeVisible();
});

/* ---------- WP-05 bar version, v1 final (V1-FINAL §8.5; CKP-MFD-33 amended, CKP-MFD-50…54; board r6-effort-final) ---------- */
// Sol at Standard, every effort as a share of the top effort (Max): ability from OUR published score, cost with a $.
const SOL_KEYS=[['Low','71%','$13%'],['Med','84%','$23%'],['High','90%','$36%'],['XHigh','97%','$60%'],['Max','100%','$100%']];
const keyNums=screen=>screen.locator('.cmp-nums .lad-n').evaluateAll(cells=>cells.map(c=>({e:c.dataset.effort,a:c.querySelector('.lad-a').textContent,c:c.querySelector('.lad-c').textContent,
 role:c.classList.contains('try')?'trial':c.classList.contains('cur')?'current':'other',colour:getComputedStyle(c.querySelector('.lad-a')).color,title:c.closest('[title]')?.getAttribute('title')??c.getAttribute('title')??''})));
// build13Models (and its array) are shared module objects: every edit works on copies so nothing leaks into the next test.
const solEfforts=(data,fn)=>{const edit=list=>list.map(m=>{if(m.id!=='gpt-6.1-sol')return m;const c=structuredClone(m);fn(c);return c;});
 data.details.publishedModels=edit(data.details.publishedModels);data.details.publication.models=edit(data.details.publication.models);};
const rgb=s=>s.match(/\d+(\.\d+)?/g).slice(0,3).map(Number);

test('CKP-MFD-50 the cost bar and cost line are mid-grey #8d97a1, ability stays white; the title reads "Effort · <model>"',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 await expect(screen.locator('.mfd-title')).toHaveText('Effort · Sol 6.1');
 const fill=sel=>screen.locator(sel).first().evaluate(e=>getComputedStyle(e).fill),stroke=sel=>screen.locator(sel).first().evaluate(e=>getComputedStyle(e).stroke);
 for(const sel of ['svg.cmp-bars .pc-cost .pc-chip','svg.cmp-bars .pc-cost .pc-cap,svg.cmp-bars .pc-cost .pc-end'])expect(rgb(await fill(sel)),sel).toEqual([141,151,161]);
 expect(rgb(await stroke('svg.cmp-chart .pc-line.pc-cost polyline'))).toEqual([141,151,161]);
 // the fill gradient of the cost bar is the same grey (no violet left anywhere on the page)
 const stops=await screen.locator('svg.cmp-bars [class^="pc-g-cost"]').evaluateAll(s=>s.map(e=>getComputedStyle(e).stopColor));
 expect(stops.length).toBeGreaterThan(0);for(const s of stops)expect(rgb(s)).toEqual([141,151,161]);
 expect(await screen.evaluate(s=>[...s.querySelectorAll('*')].some(e=>{const c=getComputedStyle(e);return [c.fill,c.stroke,c.color,c.stopColor].some(v=>/180,\s*142,\s*224/.test(v||''));}))).toBe(false);
 await open(page,{locale:'zh-CN'});
 await expect((await openSol(page)).locator('.mfd-title')).toHaveText('档位 · Sol 6.1');
});

test('CKP-MFD-51 two numbers under every effort key: ability %, then cost % with a $; white = current, blue = trial, grey = others',async({page})=>{
 await open(page);
 const screen=await openSol(page);
 let n=await keyNums(screen);
 expect(n.map(x=>[x.e,x.a,x.c])).toEqual(SOL_KEYS);
 expect(n.map(x=>x.role)).toEqual(['other','other','current','other','other']);
 // the numbers sit under their keys
 const keys=await screen.locator('.cmp-lad .lad').evaluateAll(b=>b.map(e=>{const r=e.getBoundingClientRect();return {x:r.left+r.width/2,b:r.bottom};}));
 const cells=await screen.locator('.cmp-nums .lad-n').evaluateAll(c=>c.map(e=>{const r=e.getBoundingClientRect();return {x:r.left+r.width/2,t:r.top};}));
 keys.forEach((k,i)=>{expect(Math.abs(k.x-cells[i].x)).toBeLessThan(2);expect(cells[i].t).toBeGreaterThanOrEqual(k.b-.5);});
 const cur=rgb(n[2].colour),other=rgb(n[0].colour);
 expect(Math.min(...cur)).toBeGreaterThan(200);expect(Math.max(...other)).toBeLessThan(Math.min(...cur));
 // every text is at least 10 px
 for(const px of await screen.locator('.cmp-nums .lad-n b').evaluateAll(b=>b.map(e=>parseFloat(getComputedStyle(e).fontSize))))expect(px).toBeGreaterThanOrEqual(10);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 n=await keyNums(screen);
 expect(n.map(x=>[x.e,x.a,x.c])).toEqual(SOL_KEYS);
 expect(n.map(x=>x.role)).toEqual(['other','other','current','trial','other']);
 const [r,g,b]=rgb(n[3].colour);expect(b).toBeGreaterThan(r+60);expect(b).toBeGreaterThan(g);
 // trying the current effort itself adds nothing: no blue
 await screen.locator('.cmp-lad [data-mfd="try:High"]').click();
 expect((await keyNums(screen)).map(x=>x.role)).toEqual(['other','other','current','other','other']);
});

test('CKP-MFD-52 ability % is OUR score ÷ the top effort; a published aaScore is only an "AA official" reference; no score = "—"',async({page})=>{
 // aaScore deliberately far from our scores: if it drove the share, High would read 51 % instead of 90 %.
 const aa={low:20,medium:25,high:31,xhigh:58,max:61};
 await open(page,{edit:data=>solEfforts(data,m=>{for(const e of m.efforts)e.aaScore=aa[e.effort];})});
 let screen=await openSol(page);
 let n=await keyNums(screen);
 expect(n.map(x=>[x.e,x.a,x.c])).toEqual(SOL_KEYS);
 expect((await bars(page)).abl.numbers.map(x=>x.text)).toEqual(['90%']);
 expect(n.find(x=>x.e==='High').title).toContain('AA official 31');
 // zh: AA 官方分
 await open(page,{locale:'zh-CN',edit:data=>solEfforts(data,m=>{for(const e of m.efforts)e.aaScore=aa[e.effort];})});
 screen=await openSol(page);
 expect((await keyNums(screen)).find(x=>x.e==='Max').title).toContain('AA 官方分 61');
 // aaScore absent: no AA reference anywhere; an unscored effort and an unpriced one show "—"
 await open(page,{edit:data=>solEfforts(data,m=>{for(const e of m.efforts){if(e.effort==='low')e.ability=null;if(e.effort==='medium')e.cost=null;}})});
 screen=await openSol(page);
 n=await keyNums(screen);
 expect(n.map(x=>[x.e,x.a,x.c])).toEqual([['Low','—','$13%'],['Med','84%','—'],...SOL_KEYS.slice(2)]);
 for(const x of n)expect(x.title).not.toContain('AA');
 expect(await screen.innerText()).not.toContain('AA');
});

test('CKP-MFD-53 there is no Enter-to-apply: the keys are only ‹ back and fast, and Enter on an effort key only tries it',async({page})=>{
 await page.addInitScript(()=>{window.__posted=[];});
 await open(page);
 await page.evaluate(()=>{window.webkit.messageHandlers.cockpit.postMessage=m=>window.__posted.push(JSON.stringify(m));});
 const screen=await openSol(page);
 expect(await screen.innerText()).not.toMatch(/Enter|回车|apply|应用/i);
 // the bottom keys are ‹ back and the fast key (dark when the tool has no fast mode); nothing else, no apply key
 await expect(page.locator('.mfd-ok.mfd-vk .vk-back')).toHaveCount(1);await expect(page.locator('.mfd-ok.mfd-vk .vk-fast')).toHaveCount(1);
 await expect(page.locator('.mfd-ok.mfd-vk > *:not(.vk-back):not(.vk-fast)')).toHaveCount(0);
 const before=await page.evaluate(()=>window.__posted.length);
 await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').focus();await page.keyboard.press('Enter');
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 await page.keyboard.press('Enter');
 // the tool setting is never changed: nothing leaves the page naming the tried effort, the real effort stays High
 expect((await page.evaluate(()=>window.__posted)).slice(before).filter(m=>/xhigh/i.test(m))).toEqual([]);
 await expect(screen.locator('.cmp-lad .lad.cur')).toHaveText('High');
 expect(await page.locator('.mfd-page').innerText()).not.toMatch(/Enter|回车|apply|应用/i);
});

test('CKP-MFD-54 hint line bottom right: "click an effort or drag the fader to try it" idle, "trial only" while trying; the website link sits to its left',async({page})=>{
 for(const [locale,idle,trying] of [['en','Click an effort or drag the fader to try it','Trial only — your tool settings stay unchanged'],['zh-CN','点一个档位或拖推杆来试','试算，不会改工具设置']]){
  await open(page,{locale});
  const screen=await openSol(page);
  const hint=screen.locator('.cmp-foot .cmp-hint'),link=screen.locator('.cmp-foot .cmp-links a');
  await expect(hint).toHaveText(idle);await expect(link.first()).toBeVisible();
  await expect(screen.locator('.cmp-h .website-link')).toHaveCount(0);
  const hb=await hint.boundingBox(),lb=await link.first().boundingBox(),pb=await screen.boundingBox(),nb=await screen.locator('.cmp-nums').boundingBox();
  expect(lb.x+lb.width).toBeLessThanOrEqual(hb.x+.5);expect(hb.x+hb.width).toBeGreaterThan(pb.x+pb.width-20);expect(hb.y).toBeGreaterThanOrEqual(nb.y+nb.height-1);
  expect(await hint.evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThanOrEqual(10);
  expect(await screen.evaluate(e=>e.scrollWidth<=e.clientWidth+.5)).toBe(true);
  await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
  await expect(hint).toHaveText(trying);
 }
});

test('CKP-MFD-54 short cockpit: the hint becomes an ⓘ outside the effort-key row; the keys and both bars stay',async({page})=>{
 await open(page,{tier:'compact',height:640});
 const screen=await openSol(page);
 const mark=screen.locator('.cmp-trial-i');
 await expect(mark).toBeVisible();await expect(mark).toHaveAttribute('aria-label','Click an effort or drag the fader to try it');
 expect(await mark.evaluate(e=>!!e.closest('.cmp-lad'))).toBe(false);
 const mb=await mark.boundingBox(),keys=await screen.locator('.cmp-lad .lad').evaluateAll(b=>b.map(e=>{const r=e.getBoundingClientRect();return {l:r.left,r:r.right,t:r.top,b:r.bottom};}));
 for(const k of keys)expect(mb.x>=k.r-.5||mb.x+mb.width<=k.l+.5||mb.y>=k.b-.5||mb.y+mb.height<=k.t+.5,'ⓘ overlaps a key').toBe(true);
 await expect(screen.locator('.cmp-lad .lad')).toHaveCount(5);await expect(screen.locator('.cmp-nums .lad-n')).toHaveCount(5);
 expect(await screen.evaluate(e=>e.scrollWidth<=e.clientWidth+.5&&e.scrollHeight<=e.clientHeight+.5)).toBe(true);
});

test('CKP-MFD-54 a model with a single effort shows "Only one effort" and no chart; an unreported current draws only the ★ line',async({page})=>{
 await open(page,{edit:data=>solEfforts(data,m=>{m.efforts=m.efforts.filter(e=>e.effort==='medium');})});
 let screen=await openSol(page);
 await expect(screen.locator('.cmp-single')).toHaveText('Only one effort');
 await expect(screen.locator('svg.cmp-chart')).toHaveCount(0);
 await open(page,{locale:'zh-CN',edit:data=>solEfforts(data,m=>{m.efforts=m.efforts.filter(e=>e.effort==='medium');})});
 await expect((await openSol(page)).locator('.cmp-single')).toHaveText('只有一档');
 await open(page,{edit:data=>{data.details.sessions[0].effort=null;}});
 screen=await openSol(page);
 const b=await bars(page);
 expect(b.abl.fill).toBeNull();expect(b.cost.fill).toBeNull();expect(b.abl.rec).not.toBeNull();
 await expect(screen.locator('.cmp-note')).toContainText('current unknown');
});

test('CKP-MFD-50 the title carries the model\'s 7-day use: "7d 212M · 17%" (no ≈$ until estimated cost exists); nothing without history',async({page})=>{
 const ranking=(top,total)=>({measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:top.length,totalObservedOutputTokens:total,top},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}});
 const withHistory=data=>{data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,subscriptions:[],
  models:ranking([{name:'gpt-6.1-sol',observedOutputTokens:212e6,observedRequests:900,share:212/1247}],1247e6),tools:ranking([],0),daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};};
 await open(page,{edit:withHistory});
 let screen=await openSol(page);
 await expect(screen.locator('.cmp-h .cmp-use')).toHaveText('7d 212M · 17%');
 await open(page,{locale:'zh-CN',edit:withHistory});
 screen=await openSol(page);
 await expect(screen.locator('.cmp-h .cmp-use')).toHaveText('7天 212M · 占 17%');
 await open(page);
 screen=await openSol(page);
 await expect(screen.locator('.cmp-h .cmp-use')).toHaveCount(0);
});

// G3-144/145 (owner 11-21): with a price estimate the title reads "7天 1k · ≈$7.3 · 占 100%" (one ≈, always the 7-day use,
// whatever the range), and an unknown current effort says "档位未报告" (the tool did not report it), not "当前未报告".
test('G3-144 the title shows one ≈ with the 7-day cost, and names an unreported current effort',async({page})=>{
 const priced=data=>{data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,subscriptions:[],
  models:{measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:1,totalObservedOutputTokens:1000,top:[{name:'gpt-6.1-sol',observedOutputTokens:1000,observedRequests:9,share:1}]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}},
  tools:{measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}},daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[],
  cost:{basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-04',daily:[],hourly:[],models:{today:[],recent7d:[{model:'gpt-6.1-sol',source:'codex',estimatedUsd:7.3,pricedTokens:1000,unpricedTokens:0}],recent30d:[]}}};
  data.details.sessions[0].effort=null;};
 await open(page,{locale:'zh-CN',edit:priced});
 const screen=await openSol(page);
 await expect(screen.locator('.cmp-h .cmp-use')).toHaveText('7天 1k · ≈$7.3 · 占 100%');
 await expect(screen.locator('.cmp-h .cmp-note')).toHaveText('档位未报告');
});

// V1-FINAL §14 (WP-05): every new string passes the pseudo-long check: long form, then short, then left out; numbers never cut.
test('CKP-MFD-50…54 pseudo-long English: the effort page keeps its numbers whole and nothing runs out of the screen',async({page})=>{
 const {usePseudoLong}=await import('../pseudo-long.mjs');
 for(const [tier,height] of [['tall',890],['compact',640]]){
  await usePseudoLong(page);
  await open(page,{tier,height});
  const screen=await openSol(page);
  for(const step of ['idle','trial']){
   if(step==='trial')await screen.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
   const fit=await screen.evaluate(s=>{const out=[],box=s.getBoundingClientRect();
    for(const e of s.querySelectorAll('.cmp-h > *, .cmp-foot > *, .cmp-foot a, .cmp-hint, .lad-n b, .lad')){const r=e.getBoundingClientRect();if(!r.width)continue;
     if(r.left<box.left-.5||r.right>box.right+.5)out.push(['outside',e.className,e.textContent]);
     if(e.scrollWidth>e.clientWidth+1&&!e.classList.contains('mfd-title'))out.push(['clipped',e.className,e.textContent]);}
    return out;});
   expect(fit,`${tier} ${step}`).toEqual([]);
   expect((await keyNums(screen)).map(x=>[x.a,x.c])).toEqual(SOL_KEYS.map(k=>[k[1],k[2]]));
  }
 }
});

test('CKP-MFD-52 the best-scoring effort need not be the top one; a model with no ability scores says so',async({page})=>{
 // XHigh scores above Max: XHigh is 100 % and named, Max reads below 100 %; cost still a share of Max
 await open(page,{edit:data=>solEfforts(data,m=>{for(const e of m.efforts)if(e.effort==='xhigh')e.ability=50;})});
 let screen=await openSol(page);
 let n=await keyNums(screen);
 expect(n.map(x=>[x.e,x.a,x.c])).toEqual([['Low',pct(33.9/50),'$13%'],['Med',pct(39.8/50),'$23%'],['High',pct(42.8/50),'$36%'],['XHigh','100%','$60%'],['Max',pct(47.5/50),'$100%']]);
 expect((await bars(page)).abl.max.map(m=>m.text)).toEqual(['100% = XHigh']);
 // no ability score at all: every ability number is "—", no ability fill, and the header says why
 await open(page,{locale:'zh-CN',edit:data=>solEfforts(data,m=>{for(const e of m.efforts)e.ability=null;})});
 screen=await openSol(page);
 n=await keyNums(screen);
 expect(n.map(x=>x.a)).toEqual(['—','—','—','—','—']);expect(n.map(x=>x.c)).toEqual(SOL_KEYS.map(k=>k[2]));
 expect((await bars(page)).abl.fill).toBeNull();
 await expect(screen.locator('.cmp-note .cmp-no-abl')).toHaveText('没有能力分');
});
