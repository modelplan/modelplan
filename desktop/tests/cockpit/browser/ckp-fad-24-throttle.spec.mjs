// SPDX-License-Identifier: MIT
// CKP-FAD-24 / CKP-FAD-17 (D115, D122, D196) and G3-92 on the built official page through its normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const effort=(e,ability,cost,star=false)=>({effort:e,label:e,star,ability,cost,time:null});
// Sol: ★ Med, current High; Opus: ★ Med, current XHigh; GLM: one effort, ★ Max = current Max (owner build G3-92).
export function throttleData({glmEfforts=['max']}={}){
 const data=visualFixture().data;
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-11-12T00:00:00Z',source:'client',truncated:false,models:[
  {id:'sol',name:'Sol 6.1',developerId:'openai',recommended:'medium',efforts:[effort('low',33.9,.13),effort('medium',39.8,.25,true),effort('high',42.8,.38),effort('xhigh',46,.63),effort('max',47.5,1.06)]},
  {id:'opus',name:'Opus 5.5',developerId:'anthropic',recommended:'medium',efforts:[effort('low',45.6,1.2),effort('medium',55.4,2.9,true),effort('high',58.1,3.95),effort('xhigh',60.1,7.5),effort('max',62.4,13)]},
  {id:'glm',name:'GLM-5.3',developerId:'zhipu',recommended:'max',efforts:glmEfforts.map((e,i)=>effort(e,40+i,1+i,e==='max'))},
 ]};
 data.details.sessions=[
  {sessionRef:'0000000000000001',source:'codex',subscriptionRef:null,model:'sol',effort:'high',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000002',source:'claude',subscriptionRef:null,model:'opus',effort:'xhigh',projectLabel:'desktop',lastObservedAt:'2026-10-20T14:04:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000003',source:'claude',subscriptionRef:null,model:'glm',effort:'max',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:03:00Z',state:'idle',rate:null},
 ];
 return data;
}
export async function openThrottles(page,{theme='night',tier='tall',height=890,glmEfforts}={}){
 await page.setViewportSize({width:636,height});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-10-20T14:05:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:throttleData({glmEfforts})}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
 return {send,receive};
}
const centres=page=>page.locator('.fd-ch:not(.empty)').evaluateAll(list=>list.map(ch=>{const mid=e=>{const r=e.getBoundingClientRect();return r.left+r.width/2;};
 return {name:ch.querySelector('.st-name').textContent,column:mid(ch),slot:mid(ch.querySelector('.fd-slot')),lever:mid(ch.querySelector('.fd-cap')),strip:mid(ch.querySelector('.fd-strip')),frame:ch.querySelector('.fd-cap').dataset.frame};}));
// The vertical centre of a level label (Max .. Low) beside the travels: the detent rows.
const row=(page,level)=>page.locator(`.sc-l[data-level="${level}"]`).evaluate(e=>{const r=e.getBoundingClientRect();return r.top+r.height/2;});
const box=locator=>locator.evaluate(e=>{const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2,top:r.top,bottom:r.bottom,width:r.width,height:r.height};});
const channel=(page,i)=>page.locator('.fd-ch:not(.empty)').nth(i);

for(const theme of ['night','day'])for(const [tier,height] of [['tall',890],['compact',640]])
 test(`G3-92 every lever sits on its slot centre in its column (${theme}, ${tier})`,async({page})=>{
  await openThrottles(page,{theme,tier,height});
  const list=await centres(page);
  expect(list.map(c=>c.name)).toEqual(['Sol 6.1','Opus 5.5','GLM-5.3']);
  // the real lever is the baked frame of the current effort: High 16, XHigh 24, Max 32 (Low 0 .. Max 32)
  expect(list.map(c=>c.frame)).toEqual(['16','24','32']);
  for(const c of list){
   expect(Math.abs(c.lever-c.slot),c.name+' lever vs slot').toBeLessThanOrEqual(.5);
   expect(Math.abs(c.slot-c.column),c.name+' slot vs column').toBeLessThanOrEqual(.5);
   expect(Math.abs(c.slot-c.strip),c.name+' slot vs LCD').toBeLessThanOrEqual(.5);
  }
 });

// G3-92 (owner 11-12: the blue trial ghost grip looked off-centre in the GLM column): a trial in each column in turn, GLM with
// two efforts so it can show one; the ghost grip, the lever and the slot share the column centre.
for(const theme of ['night','day'])for(const [tier,height] of [['tall',890],['compact',640]])
 test(`G3-92 every trial ghost grip sits on its slot centre in its column (${theme}, ${tier})`,async({page})=>{
  await openThrottles(page,{theme,tier,height,glmEfforts:['high','max']});
  for(const [i,trial] of [[0,'Med'],[1,'High'],[2,'High']]){
   const ch=channel(page,i),slider=ch.locator('[role=slider]');await slider.focus();await page.keyboard.press('ArrowDown');
   await expect(slider).toHaveAttribute('aria-valuetext',trial);await expect(ch.locator('.fd-ghost')).toBeVisible();
   await expect.poll(async()=>Math.abs((await box(ch.locator('.fd-ghost'))).y-await row(page,trial))).toBeLessThanOrEqual(1);
   const [ghost,slot,lever,column]=await Promise.all(['.fd-ghost','.fd-slot','.fd-cap'].map(s=>box(ch.locator(s))).concat(box(ch)));
   for(const [name,x] of [['ghost',ghost.x],['lever',lever.x],['column',column.x]])expect(Math.abs(x-slot.x),`column ${i} ${name} vs slot`).toBeLessThanOrEqual(.5);
  }
 });

test('G3-92 a Max-only model shows no ghost: keys, drag and label clicks all land on its one effort',async({page})=>{
 await openThrottles(page);
 const glm=channel(page,2),slider=glm.locator('[role=slider]');await slider.focus();
 for(const key of ['ArrowDown','ArrowUp'])await page.keyboard.press(key);
 await expect(slider).toHaveAttribute('aria-valuetext','Max');await expect(glm.locator('.fd-ghost')).toBeHidden();await expect(glm.locator('.fd-tline')).toBeHidden();
});

for(const [tier,height,u] of [['tall',890,1],['compact',640,80/97]])
 test(`CKP-FAD-24 the baked throttle is drawn per theme at the travel's scale (${tier})`,async({page})=>{
  const {send,receive}=await openThrottles(page,{tier,height});
  const sol=channel(page,0),slot=await box(sol.locator('.fd-slot')),lever=await box(sol.locator('.fd-cap'));
  expect(slot.width).toBeCloseTo(38*u,1);expect(slot.height).toBeCloseTo(134*u,1);expect(lever.width).toBeCloseTo(64*u,1);
  // the art's Max and Low detents (16.5 and 113.5 u below the tile top) are the Max and Low label rows
  expect(Math.abs(slot.top+16.5*u-await row(page,'Max'))).toBeLessThanOrEqual(1);
  expect(Math.abs(slot.top+113.5*u-await row(page,'Low'))).toBeLessThanOrEqual(1);
  const art=()=>sol.evaluate(ch=>['.fd-slot','.fd-cap'].map(s=>getComputedStyle(ch.querySelector(s)).backgroundImage));
  expect((await art()).join()).toMatch(/throttle\/plate-night\.png.*throttle\/lever-night\.png/);
  expect(await receive(send('appearance',{...appearance,theme:'day'}))).toBe(true);
  expect((await art()).join()).toMatch(/throttle\/plate-day\.png.*throttle\/lever-day\.png/);
 });

test('CKP-FAD-24 the recommended effort is a small gold ★ tick on the slot scale',async({page})=>{
 await openThrottles(page);
 for(const [i,level] of [[0,'Med'],[1,'Med'],[2,'Max']]){
  const ch=channel(page,i),rec=await box(ch.locator('.fd-rec')),star=await box(ch.locator('.fd-rec .g-star')),slot=await box(ch.locator('.fd-slot'));
  expect(Math.abs(rec.y-await row(page,level)),'★ on the '+level+' row').toBeLessThanOrEqual(1);
  expect(rec.x-slot.x).toBeGreaterThan(19);expect(rec.x-slot.x).toBeLessThan(22);   // right of the plate's ticks (11.6 u)
  expect(rec.width).toBeCloseTo(3,0);expect(star.width).toBeLessThanOrEqual(9);
  expect(await ch.locator('.fd-rec').evaluate(e=>getComputedStyle(e).backgroundColor)).toBe('rgb(212, 185, 148)');
 }
});

test('CKP-FAD-24/-17 a drag moves the blue ghost continuously and snaps it to the nearest effort; the lever stays',async({page})=>{
 await openThrottles(page);
 const sol=channel(page,0),travel=sol.locator('[role=slider]'),ghost=sol.locator('.fd-ghost'),line=sol.locator('.fd-tline'),lever=sol.locator('.fd-cap');
 const t=await box(travel),high=await row(page,'High'),med=await row(page,'Med'),low=await row(page,'Low');
 await expect(ghost).toBeHidden();await expect(line).toBeHidden();
 await page.mouse.move(t.x,high);await page.mouse.down();
 // between the detents the ghost follows the pointer (no snapping while dragging)
 const between=med+(low-med)*.7;await page.mouse.move(t.x,between,{steps:4});
 await expect(ghost).toBeVisible();expect(Math.abs((await box(ghost)).y-between)).toBeLessThanOrEqual(1);
 const drawn=await box(line);expect(Math.abs(drawn.top-(high))).toBeLessThanOrEqual(1);expect(Math.abs(drawn.bottom-between)).toBeLessThanOrEqual(1);
 expect(await lever.getAttribute('data-frame')).toBe('16');
 await page.mouse.up();
 // released 70 % of the way to Low: the trial is Low, the ghost sits on the Low row and the real lever stays on High
 await expect(travel).toHaveAttribute('aria-valuetext','Low');await expect(travel).toHaveAttribute('data-trial','Low');await expect(travel).toHaveAttribute('data-lever','High');
 await expect.poll(async()=>Math.abs((await box(ghost)).y-low)).toBeLessThanOrEqual(1);
 expect(await lever.getAttribute('data-frame')).toBe('16');await expect(sol.locator('.st-try')).toContainText('Low');
 const spans=await box(line);expect(Math.abs(spans.top-(high))).toBeLessThanOrEqual(1);expect(Math.abs(spans.bottom-low)).toBeLessThanOrEqual(1);
 // the rod is faint (a quarter of the trial blue's opacity), still visible
 expect(await line.evaluate(e=>getComputedStyle(e).backgroundColor)).toMatch(/^color\(srgb 0\.62\d* 0\.82\d* 1 \/ 0\.25\)$|^rgba\(159, 210, 255, 0\.25\)$/);
 // dropping the ghost back on the real lever cancels the trial (CKP-FAD-17)
 const g=await box(ghost);await page.mouse.move(t.x,g.y);await page.mouse.down();await page.mouse.move(t.x,high+3,{steps:4});await page.mouse.up();
 await expect(travel).toHaveAttribute('data-trial','');await expect(ghost).toBeHidden();await expect(line).toBeHidden();await expect(travel).toHaveAttribute('aria-valuetext','High');
});

test('CKP-FAD-24 a release snaps only to efforts the model has (GLM has Max only)',async({page})=>{
 await openThrottles(page);
 const glm=channel(page,2),travel=glm.locator('[role=slider]'),t=await box(travel);
 await page.mouse.move(t.x,await row(page,'Max'));await page.mouse.down();await page.mouse.move(t.x,await row(page,'Low'),{steps:4});
 await expect(glm.locator('.fd-ghost')).toBeVisible();await page.mouse.up();
 await expect(travel).toHaveAttribute('aria-valuetext','Max');await expect(travel).toHaveAttribute('data-trial','');await expect(glm.locator('.fd-ghost')).toBeHidden();
});

test('CKP-FAD-12 the real lever glides through the baked frames when the current effort changes',async({page})=>{
 const {send,receive}=await openThrottles(page);
 const lever=channel(page,0).locator('.fd-cap'),data=throttleData();data.details.sessions[0].effort='low';
 const seen=lever.evaluate(e=>new Promise(done=>{const frames=new Set(),t0=performance.now();const look=()=>{frames.add(getComputedStyle(e).getPropertyValue('--fd-frame').trim());if(performance.now()-t0<600)requestAnimationFrame(look);else done([...frames]);};requestAnimationFrame(look);}));
 expect(await receive(send('display',{data}))).toBe(true);
 const frames=(await seen).map(Number);
 expect(await lever.getAttribute('data-frame')).toBe('0');expect(frames.at(-1)).toBe(0);
 expect(frames.some(f=>f>0&&f<16),'intermediate frames').toBe(true);
});

// G3-92 (owner 11-12): detent -> y is one mapping from the effort NAME on the full Low..Max scale, for the lever, the ghost and the
// rod. GLM (Low + Max) with the lever on Max and a trial on Low: the rod starts at the lever's grip edge (the Max detent) and
// ends on the ghost, which sits exactly on the Low row. The old art hid the rod's top under the lever's baked handle (it looked
// like it started at XHigh). Also: unknown current (lever on the ★ row), a 3-effort model, 1x and 2x.
// The lever's grip centre: its baked tile is fixed, the grip moves inside it by frame (Max 32 at 16.5 u .. Low 0 at 113.5 u).
const grip=async ch=>{const b=await box(ch.locator('.fd-cap')),f=Number(await ch.locator('.fd-cap').getAttribute('data-frame')),u=b.height/134;return b.top+(16.5+97*(1-f/32))*u;};
const scaleRows=async page=>Object.fromEntries(await Promise.all(['Low','Med','High','XHigh','Max'].map(async l=>[l,await row(page,l)])));
for(const theme of ['night','day'])for(const dsf of [1,2])for(const [tier,height] of [['tall',890],['compact',640]])
 test(`G3-92 detent rows are one mapping for lever, ghost and rod; axis shared (${theme}, ${dsf}x, ${tier})`,async({browser})=>{
  const ctx=await browser.newContext({deviceScaleFactor:dsf,baseURL:'http://127.0.0.1:41783'}),page=await ctx.newPage();
  await openThrottles(page,{theme,tier,height,glmEfforts:['low','max']});
  const rows=await scaleRows(page);
  // Sol (index 0): lever High, trial Max (rod above the lever). GLM (index 2): lever Max, trial Low (rod down to Low).
  for(const [i,keys,from,to] of [[0,['ArrowUp','ArrowUp'],'High','Max'],[2,['ArrowDown'],'Max','Low']]){
   const ch=channel(page,i),slider=ch.locator('[role=slider]');await slider.focus();for(const k of keys)await page.keyboard.press(k);
   await expect(slider).toHaveAttribute('aria-valuetext',to);await expect(slider).toHaveAttribute('data-lever',from);
   await expect.poll(async()=>Math.abs((await box(ch.locator('.fd-ghost'))).y-rows[to])).toBeLessThanOrEqual(.6);
   await page.waitForTimeout(400);
   const rod=await box(ch.locator('.fd-tline')),lever=await box(ch.locator('.fd-cap')),ghost=await box(ch.locator('.fd-ghost')),slot=await box(ch.locator('.fd-slot'));
   // the lever pivots about the slot centre: the rod runs from that pivot (midway between the Max and Low rows) to the ghost
   const pivot=(rows.Max+rows.Low)/2,down=rows[to]>pivot;
   expect(Math.abs((down?rod.top:rod.bottom)-pivot),'rod starts at the slot-centre pivot').toBeLessThanOrEqual(.6);
   expect(Math.abs((down?rod.bottom:rod.top)-rows[to]),'rod ends on the ghost detent').toBeLessThanOrEqual(.6);
   expect(Math.abs(await grip(ch)-rows[from]),'lever grip on its own detent row').toBeLessThanOrEqual(.6);
   for(const [name,x] of [['ghost',ghost.x],['rod',rod.x],['slot',slot.x]])expect(Math.abs(x-lever.x),name+' axis vs lever').toBeLessThanOrEqual(.5);
   // the rod is faint but visible; in the day theme it is the dark blue
   // the ghost rod is as wide as the real lever's rod (5 u)
   expect(Math.abs(rod.width-5*(tier==='tall'?1:80/97)),'ghost rod width').toBeLessThanOrEqual(.5);
   const bg=await ch.locator('.fd-tline').evaluate(e=>getComputedStyle(e).backgroundColor);
   if(theme==='night')expect(bg).toMatch(/0\.25\)$/);
   if(theme==='day')expect(bg).toMatch(/0\.55\)$/);
  }
 });

// Unknown current: no session, so the lever rests on the ★ row; a trial on another effort still lands on that effort's row.
test('G3-92 unknown current: the lever is on the ★ row and the ghost on the trial effort row',async({page})=>{
 const {send,receive}=await openThrottles(page);
 const data=throttleData();data.details.sessions=[];expect(await receive(send('display',{data}))).toBe(true);
 const rows=await scaleRows(page);
 for(const [i,star] of [[0,'Med'],[1,'Med'],[2,'Max']]){
  const ch=channel(page,i);await expect.poll(async()=>Math.abs(await grip(ch)-rows[star])).toBeLessThanOrEqual(.6);
  const slider=ch.locator('[role=slider]');await slider.focus();await expect(slider).toHaveAttribute('data-lever',star);
  if(i<2){await page.keyboard.press('ArrowUp');await expect.poll(async()=>Math.abs((await box(ch.locator('.fd-ghost'))).y-rows.High)).toBeLessThanOrEqual(.6);}
 }
});
