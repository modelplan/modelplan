// SPDX-License-Identifier: MIT
// D405 (owner 2026-11-24, direction 06): the lever area. Effort names sit in the two gaps between the levers (shown twice),
// the big screen takes about 61.8% of the deck, the upper tier (lamps + cards) and the lower tier (levers + bank row)
// split the deck height about evenly, and a card's token count reads clearly larger than its other small lines.
// The tilt is drawn with light only: no 3D transform anywhere in the deck. Official build, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {renderVisualDeck,visualFixture} from '../visual-fixture.mjs';
import {build13Profile} from '../build13-fixture.mjs';
import {levelK} from '../../../cockpit/study/rocket-r1/fader-view.js';

// The CKP-FAD-24 throttle fixture (Sol ★Med current High, Opus ★Med current XHigh, GLM ★Max).
const effort=(e,ability,cost,star=false)=>({effort:e,label:e,star,ability,cost,time:null});
// Sol: ★ Med, current High; Opus: ★ Med, current XHigh; GLM: one effort, ★ Max = current Max (owner build G3-92).
function throttleData({glmEfforts=['max']}={}){
 const data=visualFixture().data;
 // GLM remains eligible after live sessions clear because this fixture has a visible ZCode subscription.
 const zai=structuredClone(data.projection.rows[0]);zai.id='zai';zai.name={en:'ZCode',zh:'ZCode'};zai.vendorKey='glm';
 zai.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});data.projection.rows.push(zai);
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-11-12T00:00:00Z',source:'client',truncated:false,models:[
  {id:'sol',name:'Sol 6.1',developerId:'openai',recommended:'medium',efforts:[effort('low',33.9,.13),effort('medium',39.8,.25,true),effort('high',42.8,.38),effort('xhigh',46,.63),effort('max',47.5,1.06)]},
  {id:'opus',name:'Opus 5.5',developerId:'anthropic',recommended:'medium',efforts:[effort('low',45.6,1.2),effort('medium',55.4,2.9,true),effort('high',58.1,3.95),effort('xhigh',60.1,7.5),effort('max',62.4,13)]},
  {id:'glm',name:'GLM-5.3',developerId:'zhipuai',recommended:'max',efforts:glmEfforts.map((e,i)=>effort(e,40+i,1+i,e==='max'))},
 ]};
 data.details.sessions=[
  {sessionRef:'0000000000000001',source:'codex',subscriptionRef:null,model:'sol',effort:'high',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000002',source:'claude',subscriptionRef:null,model:'opus',effort:'xhigh',projectLabel:'desktop',lastObservedAt:'2026-10-20T14:04:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000003',source:'zcode',subscriptionRef:null,model:'glm',effort:'max',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:03:00Z',state:'idle',rate:null},
 ];
 return data;
}
async function openThrottles(page,{theme='night',tier='tall',height=890,glmEfforts}={}){
 await page.setViewportSize({width:636,height});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date('2026-10-20T14:05:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,theme},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:throttleData({glmEfforts})}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
 // D405: the code-drawn slots follow the travel's size; wait until they are drawn for the current one.
 await page.waitForFunction(()=>[...document.querySelectorAll('.fd-ch .fd-travel')].every(t=>{const s=t.querySelector('.fd-slotsvg');return s&&Math.abs(Number(s.getAttribute('height'))-t.offsetHeight)<1;}));
 await page.waitForFunction(()=>document.querySelectorAll('.fd-cap').length&&[...document.querySelectorAll('.fd-cap')].every(c=>!c.getAnimations().length));
 return {send,receive};
}

const rect=l=>l.evaluate(e=>{const r=e.getBoundingClientRect();return {l:r.left,r:r.right,t:r.top,b:r.bottom,w:r.width,h:r.height,x:r.left+r.width/2,y:r.top+r.height/2};});
const channels=page=>page.locator('.fd-ch:not(.empty)');

for(const [tier,height] of [['tall',890],['compact',640]]){
 test(`D405 the big screen takes about 61.8% of the deck (${tier})`,async({page})=>{
  await openThrottles(page,{tier,height});
  const deck=await rect(page.locator('.ck-deck')),mfd=await rect(page.locator('.dk-mfd')),fad=await rect(page.locator('.dk-fad'));
  expect(mfd.w/deck.w,'big screen share of the deck').toBeGreaterThan(.605);
  expect(mfd.w/deck.w,'big screen share of the deck').toBeLessThan(.63);
  // The lever area is exactly three channels and two 12 px gaps: no scale column beside the levers.
  expect(fad.w).toBeCloseTo(3*64+2*12,0);
 });

 test(`D405 effort names sit in both gaps between the levers, on the detent rows (${tier})`,async({page})=>{
  await openThrottles(page,{tier,height});
  const cols=page.locator('.fd-scale .sc-travel');
  await expect(cols).toHaveCount(2);
  const ch=await channels(page).evaluateAll(list=>list.map(c=>{const r=c.getBoundingClientRect();return {l:r.left,r:r.right};}));
  // On the tilted face a gap's centre at a row is midway between its two slot lines at that row (D405, owner 11-24).
  const lines=await slotGeometry(page),lineX=(c,y)=>{const p=c.pts,f=(y-c.box.top-p[0][1])/(p[3][1]-p[0][1]);return c.box.left+((p[0][0]+(p[3][0]-p[0][0])*f)+(p[1][0]+(p[2][0]-p[1][0])*f))/2;};
  const gapAt=(i,y)=>(lineX(lines[i],y)+lineX(lines[i+1],y))/2;
  expect(ch[1].l-ch[0].r).toBeCloseTo(12,0);expect(ch[2].l-ch[1].r).toBeCloseTo(12,0);
  for(const i of [0,1]){
   const col=cols.nth(i);
   await expect(col.locator('.sc-l')).toHaveText(['Low','Med','High','XHigh','Max']);
   for(const level of ['Max','XHigh','High','Med','Low']){
    const label=await rect(col.locator(`.sc-l[data-level="${level}"]`)),first=await rect(cols.nth(0).locator(`.sc-l[data-level="${level}"]`));
    expect(Math.abs(label.x-gapAt(i,label.y)),`gap ${i+1} ${level} centred on the gap at its row`).toBeLessThanOrEqual(1);
    expect(Math.abs(label.y-first.y),`gap ${i+1} ${level} on the same row`).toBeLessThanOrEqual(.5);
   }
  }
  // A name never runs under a recommended star: the star ends before the label column starts.
  for(const i of [0,1]){
   const star=await rect(channels(page).nth(i).locator('.fd-rec .g-star')),rec=await channels(page).nth(i).locator('.fd-rec').getAttribute('data-l');
   const label=await rect(cols.nth(i).locator(`.sc-l[data-level="${rec}"]`));
   const text=await cols.nth(i).locator(`.sc-l[data-level="${rec}"]`).evaluate(e=>{const r=document.createRange();r.selectNodeContents(e);const b=r.getBoundingClientRect();return {l:b.left,r:b.right};});
   expect(star.r,`star ${i+1} clear of its row's label`).toBeLessThanOrEqual(text.l+.5);
   expect(label.w).toBeGreaterThan(0);
  }
 });
}

test('D405 a name in the second gap tries that effort like the first',async({page})=>{
 await openThrottles(page);
 await channels(page).nth(0).locator('.fd-strip').click();
 await page.locator('.fd-scale .sc-travel').nth(1).locator('.sc-l[data-level="Low"]').click();
 await expect(channels(page).nth(0)).toHaveClass(/trying/);
 await expect(channels(page).nth(0).locator('.fd-ghost')).toBeVisible();
});

test('D405 the upper and lower tiers split the deck about evenly (tall); the tilt is light only',async({page})=>{
 await openThrottles(page);
 const deck=await rect(page.locator('.ck-deck')),strip=await rect(channels(page).nth(0).locator('.fd-strip')),travel=await rect(channels(page).nth(0).locator('.fd-travel'));
 const upper=strip.b-deck.t,lower=deck.b-travel.t;
 expect(upper/lower,`upper ${upper} vs lower ${lower}`).toBeGreaterThan(.92);
 expect(upper/lower,`upper ${upper} vs lower ${lower}`).toBeLessThan(1.08);
 // No 3D: no perspective and no transform other than 2D translation anywhere in the deck.
 const threeD=await page.locator('.ck-deck').evaluate(deck=>[deck,...deck.querySelectorAll('*')].flatMap(e=>{const s=getComputedStyle(e);return s.perspective!=='none'||/matrix3d|rotate/.test(s.transform)?[e.className.toString()]:[];}));
 expect(threeD).toEqual([]);
 // Both tiers are drawn: the upper tier ends at the cards' front edge, the lower tier runs under the levers.
 const tiers=await page.locator('.dk-fad').evaluate(e=>['::before','::after'].map(p=>getComputedStyle(e,p).content));
 expect(tiers).toEqual(['""','""']);
});

test('D405 the card token count is clearly larger and brighter than the card\'s other small lines',async({page})=>{
 // The visual fixture's cards carry use in the range ("212M 17%").
 await page.setViewportSize({width:636,height:890});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw),fixture=visualFixture();
 expect(await receive(send('load',{appearance,shell}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:fixture.data}))).toBe(true);
 await renderVisualDeck(page,fixture,'en');
 const sol=channels(page).nth(0);
 const [tok,pct,eff]=await Promise.all(['.cd-use .cd-tok','.cd-use .cd-pct','.cd-eff'].map(s=>sol.locator(s).evaluate(e=>{const s=getComputedStyle(e);return {size:parseFloat(s.fontSize),weight:Number(s.fontWeight),colour:s.color};})));
 expect(tok.size).toBeGreaterThanOrEqual(12);expect(tok.size-pct.size).toBeGreaterThanOrEqual(2);expect(tok.size-eff.size).toBeGreaterThanOrEqual(2);
 expect(tok.weight).toBeGreaterThanOrEqual(600);
 // Nothing on any card is clipped.
 const clipped=await channels(page).evaluateAll(list=>list.map(c=>c.querySelector('.fd-strip')).filter(s=>s.scrollHeight>s.clientHeight+1||[...s.querySelectorAll('.cd-use')].some(u=>u.scrollWidth>u.clientWidth+1)).length);
 expect(clipped).toBe(0);
});

test('D405/D376 the subscription columns reach the bottom of the upper panel; no update row under them',async({page})=>{
 await openThrottles(page);
 const eng=await rect(page.locator('.ck-eng'));
 const cols=await page.locator('.ck-eng .ec').evaluateAll(list=>list.map(e=>e.getBoundingClientRect().bottom));
 expect(cols.length).toBeGreaterThan(0);
 for(const b of cols)expect(eng.b-b,'column bottom vs panel bottom').toBeLessThanOrEqual(8);
 await expect(page.locator('.ck-eng')).not.toContainText(/Updated|Refresh|更新|刷新/);
 await expect(page.locator('.ck-eng .eng-upd, .ck-eng .eng-foot')).toHaveCount(0);
});

// The c-plans-pages local-history profile: Sol 900 output tokens (≈$12), Terra 100 (≈$3), the others unused.
const ranking=top=>({entities:top.length,totalObservedOutputTokens:top.reduce((n,e)=>n+e.observedOutputTokens,0),top});
const entity=(name,tokens)=>({name,observedOutputTokens:tokens,observedRequests:1,share:0});
function withHistory(used=true,priced=false){
 const data=build13Profile(),at=n=>{const d=new Date(Date.now()-n*864e5);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
 const top=used?[entity('gpt-6.1-sol',900),entity('gpt-6.1-terra',100)]:[],none={measure:'observed-output-tokens',attribution:'unattributed'};
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:at(3),subscriptions:[],daily:[],hourly:[],cycles:[],
  models:{...none,recent7d:ranking(top),recent30d:ranking(top)},tools:{...none,recent7d:ranking([]),recent30d:ranking([])},
  projects:{recent7d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[],recent30d:used?[{ref:'p1',label:'modelPlans',model:'gpt-6.1-sol',effort:'high',observedOutputTokens:900,share:0.9},{ref:'p2',label:'site',model:'gpt-6.1-terra',effort:'medium',observedOutputTokens:100,share:0.1}]:[]}};
 if(priced)data.history.cost={basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-04',daily:[{at:at(1),source:'codex',estimatedUsd:15,pricedTokens:1000,unpricedTokens:0}],hourly:[],
  models:{today:[],recent7d:[{model:'gpt-6.1-sol',source:'codex',estimatedUsd:12,pricedTokens:900,unpricedTokens:0},{model:'gpt-6.1-terra',source:'codex',estimatedUsd:3,pricedTokens:100,unpricedTokens:0}],recent30d:[]}};
 return data;
}


test('D405 the Models list uses the wider screen: aligned effort and ★ columns and a share bar in the free width',async({page})=>{
 await page.setViewportSize({width:636,height:890});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:withHistory(true,true)}))).toBe(true);
 await page.locator('[data-mfd="page:tune"]').click();
 const rows=page.locator('.mfd-page .md-list .md-row');await expect(rows.first()).toBeVisible();
 const cells=await rows.evaluateAll(list=>list.map(r=>{const x=s=>{const e=r.querySelector(s);return e?e.getBoundingClientRect():null;};return {star:x('.md-star')?.left??null,bar:x('.md-bar'),name:x('.md-n'),row:r.getBoundingClientRect(),idle:r.classList.contains('idle')};}));
 const stars=cells.map(c=>c.star).filter(v=>v!==null);
 expect(stars.length).toBeGreaterThan(2);
 for(const s of stars)expect(Math.abs(s-stars[0]),'★ column aligned').toBeLessThanOrEqual(.5);
 const used=cells.filter(c=>!c.idle);
 expect(used.length).toBe(2);
 for(const c of used){expect(c.bar.width,'share bar has room').toBeGreaterThan(40);expect(c.name.width).toBeLessThanOrEqual(88.5);}
 // The bar is drawn to the share: Sol (90%) fills more of its track than Terra (10%).
 const fill=await rows.evaluateAll(list=>list.slice(0,2).map(r=>getComputedStyle(r.querySelector('.md-bar')).getPropertyValue('--p').trim()));
 expect(fill).toEqual(['90%','10%']);
});

// macrevc-1223-1: the knob is swappable by its CSS settings alone. Whatever --knob-frames says, the page's lever position maps
// onto that strip: Max is the last frame, Low the first, every frame lies inside the sprite, and data-frame reports the drawn one.
for(const frames of [33,17])
 test(`D405 the knob frame follows the CSS frame count (${frames} frames)`,async({page})=>{
  if(frames!==33)await page.route('**/cockpit.css',async r=>{const res=await r.fetch();await r.fulfill({response:res,body:(await res.text())+`\n.dk-fad{--knob-frames:${frames}}\n`});});
  const {send,receive}=await openThrottles(page);
  // Sol High, Opus XHigh, GLM Max (top), at their rows on the tilted face.
  for(const [i,pos] of [[0,1-levelK('High')],[1,1-levelK('XHigh')],[2,1]]){
   const cap=channels(page).nth(i).locator('.fd-cap'),want=Math.round(pos*(frames-1));
   await expect.poll(()=>cap.evaluate(e=>getComputedStyle(e).getPropertyValue('--fd-frame').trim())).toBe(String(want));
   await expect(cap).toHaveAttribute('data-frame',String(want));
   const g=await cap.evaluate(e=>{const s=getComputedStyle(e),[w,h]=s.backgroundSize.split(' ').map(parseFloat);return {y:parseFloat(s.backgroundPositionY),h,tile:e.getBoundingClientRect().height};});
   expect(g.h/g.tile,'strip is frames x tile').toBeCloseTo(frames,1);
   expect(Math.abs(g.y+want*g.tile),'offset selects the frame').toBeLessThanOrEqual(.5);
   expect(-g.y+g.tile,'frame inside the strip').toBeLessThanOrEqual(g.h+.5);
  }
  // Low: Sol's real effort moves to Low through the bridge → the first frame.
  const data=throttleData();data.details.sessions[0].effort='low';
  expect(await receive(send('display',{data}))).toBe(true);
  const sol=channels(page).nth(0).locator('.fd-cap');
  await expect.poll(()=>sol.evaluate(e=>getComputedStyle(e).getPropertyValue('--fd-frame').trim()),{timeout:5000}).toBe('0');
  await expect(sol).toHaveAttribute('data-frame','0');
  expect(await sol.evaluate(e=>parseFloat(getComputedStyle(e).backgroundPositionY))).toBeCloseTo(0,1);
 });


// D405 owner feedback 11-24 on #1223 (direction 06 prototype): the slots and detent dashes are code-drawn (no bitmap), about
// 4 px wide (--slot-w), and all of them take ONE perspective from the tilted lever face: the outer slots converge towards the
// top, the detents close up towards the top, and the sprite knobs sit on the slot centre line at their row.
const slotGeometry=page=>channels(page).evaluateAll(list=>list.map(ch=>{
 const r=e=>e.getBoundingClientRect(),travel=ch.querySelector('.fd-travel'),slot=ch.querySelector('.fd-slot'),svg=slot.querySelector('svg.fd-slotsvg'),core=svg?.querySelector('.sl-core');
 const box=r(travel),pts=core?core.getAttribute('points').trim().split(/\s+/).map(p=>p.split(',').map(Number)):[];
 const tq=parseFloat(getComputedStyle(ch.closest('.dk-fad')).getPropertyValue('--tq'));
 const at=y=>{const [a,b,c,d]=pts,f=(y-a[1])/(d[1]-a[1]),l=a[0]+(d[0]-a[0])*f,rr=b[0]+(c[0]-b[0])*f;return {x:box.left+(l+rr)/2,w:rr-l};};
 const dashes=[...ch.querySelectorAll('.fd-tick')].map(t=>{const tb=r(t),be=getComputedStyle(t,'::before'),af=getComputedStyle(t,'::after'),y=tb.top-box.top;
  return {y,l:{right:tb.left-parseFloat(be.right),w:parseFloat(be.width),h:parseFloat(be.height)},r:{left:tb.left+parseFloat(af.left),w:parseFloat(af.width),h:parseFloat(af.height)},content:[be.content,af.content]};});
 const cap=ch.querySelector('.fd-cap'),cb=r(cap);
 return {box:{top:box.top,left:box.left,h:box.height},tq,slotImage:getComputedStyle(slot).backgroundImage,svg:!!svg,shade:svg?svg.querySelectorAll('.sl-shade').length:0,lip:svg?svg.querySelectorAll('.sl-lip').length:0,
  top:pts.length?at(pts[0][1]):null,bottom:pts.length?at(pts[3][1]):null,atRow:y=>null,pts,dashes,cap:{x:cb.left+cb.width/2},capRow:parseFloat(cap.style.getPropertyValue('--k')),
  slotAt:dashes.map(d=>at(d.y)),capSlot:at(parseFloat(getComputedStyle(travel).getPropertyValue('--fd-pad'))+(box.height-2*parseFloat(getComputedStyle(travel).getPropertyValue('--fd-pad')))*parseFloat(cap.style.getPropertyValue('--k')))};
}));

for(const [tier,height] of [['tall',890],['compact',640]])
 test(`D405 code-drawn slots share one tilted-face perspective (${tier})`,async({page})=>{
  await openThrottles(page,{tier,height});
  const g=await slotGeometry(page);
  for(const [i,c] of g.entries()){
   // code-drawn: an SVG slot (core, upper/inner shade, lower-lip highlight); no plate bitmap
   expect(c.svg,`slot ${i} is drawn in code`).toBe(true);expect(c.shade).toBe(2);expect(c.lip).toBe(1);
   expect(c.slotImage).not.toMatch(/plate-(night|day)\.png/);
   // about 4 px at the near (bottom) end, a little narrower at the far end
   expect(c.bottom.w).toBeGreaterThan(3.8);expect(c.bottom.w).toBeLessThan(4.3);expect(c.top.w).toBeLessThan(c.bottom.w);
  }
  // one perspective: the outer slots lean in by the same amount, mirrored; the centre slot stays upright
  const lean=g.map(c=>c.top.x-c.bottom.x);
  expect(lean[0]).toBeGreaterThan(2);expect(lean[2]).toBeLessThan(-2);expect(Math.abs(lean[0]+lean[2])).toBeLessThanOrEqual(.2);expect(Math.abs(lean[1])).toBeLessThanOrEqual(.1);
  // the detents close up towards the top: each gap is smaller than the one below it, and the effort names follow
  const rows=await page.locator('.fd-scale .sc-travel[data-gap="1"] .sc-l').evaluateAll(l=>l.map(e=>{const r=e.getBoundingClientRect();return r.top+r.height/2;}).sort((a,b)=>a-b));
  const gaps=rows.slice(1).map((y,i)=>y-rows[i]);
  for(let i=1;i<gaps.length;i++)expect(gaps[i],'detent gaps grow towards the pilot').toBeGreaterThan(gaps[i-1]);
  expect(gaps[0]/gaps.at(-1)).toBeLessThan(.97);expect(Math.min(...gaps)).toBeGreaterThanOrEqual(19.5);
  for(const [i,c] of g.entries()){
   // a pair of code-drawn dashes either side of the slot at every detent, centred on the slot at that row
   expect(c.dashes.length).toBeGreaterThan(0);
   for(const [j,d] of c.dashes.entries()){
    expect(d.content).toEqual(['""','""']);expect(d.l.h).toBeCloseTo(1.5,1);
    const sx=c.slotAt[j].x;
    expect(Math.abs((sx-d.l.right)-(d.r.left-sx)),`slot ${i} dash pair centred on the slot`).toBeLessThanOrEqual(.6);
    expect(d.r.left-sx).toBeGreaterThan(c.slotAt[j].w/2);
   }
   // the knob sprite sits on the slot centre line at its row
   expect(Math.abs(c.cap.x-c.capSlot.x),`knob ${i} on the slot line`).toBeLessThanOrEqual(.6);
  }
 });

test('D405 the slot width is one CSS setting (--slot-w)',async({page})=>{
 await page.route('**/cockpit.css',async r=>{const res=await r.fetch();await r.fulfill({response:res,body:(await res.text())+'\n.dk-fad{--slot-w:6px}\n'});});
 await openThrottles(page);
 const g=await slotGeometry(page);
 for(const c of g){expect(c.bottom.w).toBeGreaterThan(5.8);expect(c.bottom.w).toBeLessThan(6.4);}
});
