// SPDX-License-Identifier: MIT
// WP-08 (V1-FINAL §7, r5-2): model cards and the five steps of clicking a card and dragging its fader, on the built
// official page through its normal bridge; synthetic data only. CKP-FAD-50…57.
// 1 normal: the card shows use; 2 click: frame, the effort page comes in over 150 ms, page keys dim, Back · Fast below;
// 3 drag: a blue ghost follows, the real lever stays, the card reads "Try XHigh / Now High"; 4 release: the trial stays;
// 5 cancel: Esc cancels the trial (the ghost glides back in 280 ms), a second Esc returns to the page; a second click or a
// click on empty space deselects.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const effort=(e,ability,cost,star=false)=>({effort:e,label:e,star,ability,cost,time:null});
// As in ckp-fad-24-throttle: Sol ★ Med, current High; Opus ★ Med, current XHigh; GLM one effort, ★ Max (idle).
function throttleData(){
 const data=visualFixture().data;
 data.details.publication={contractVersion:1,publicationId:'0123456789abcdef01234567',publishedAt:'2026-11-12T00:00:00Z',source:'client',truncated:false,models:[
  {id:'sol',name:'Sol 6.1',developerId:'openai',recommended:'medium',efforts:[effort('low',33.9,.13),effort('medium',39.8,.25,true),effort('high',42.8,.38),effort('xhigh',46,.63),effort('max',47.5,1.06)]},
  {id:'opus',name:'Opus 5.5',developerId:'anthropic',recommended:'medium',efforts:[effort('low',45.6,1.2),effort('medium',55.4,2.9,true),effort('high',58.1,3.95),effort('xhigh',60.1,7.5),effort('max',62.4,13)]},
  {id:'glm',name:'GLM-5.3',developerId:'zhipu',recommended:'max',efforts:[effort('max',40,1,true)]},
 ]};
 data.details.sessions=[
  {sessionRef:'0000000000000001',source:'codex',subscriptionRef:null,model:'sol',effort:'high',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:05:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000002',source:'claude',subscriptionRef:null,model:'opus',effort:'xhigh',projectLabel:'desktop',lastObservedAt:'2026-10-20T14:04:00Z',state:'running',rate:null},
  {sessionRef:'0000000000000003',source:'claude',subscriptionRef:null,model:'glm',effort:'max',projectLabel:'modelPlans',lastObservedAt:'2026-10-20T14:03:00Z',state:'idle',rate:null},
 ];
 return data;
}

const NOW='2026-10-20T14:05:00Z';
const ranking=(top,total)=>({measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:top.length,totalObservedOutputTokens:total,top},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}});
// The ≈cost (estCost, WP-06) is not in the wire yet, so the bridge refuses it: until then every card shows tokens large and
// shares by tokens (V1-FINAL §7 "no public price"); the ≈$ form is covered by the unit test model-card.test.mjs.
function cardData({opusUnused=false}={}){
 const data=throttleData();
 // Sol 212M (17 %), Opus 480M (38 %), GLM 96M (8 %): shares of the 7-day total.
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,subscriptions:[],
  models:ranking([{name:'sol',observedOutputTokens:212e6,observedRequests:900,share:.17},...(opusUnused?[]:[{name:'opus',observedOutputTokens:480e6,observedRequests:900,share:.38}]),
   {name:'glm',observedOutputTokens:96e6,observedRequests:90,share:.08}],1247e6),
  tools:ranking([],0),daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};
 if(opusUnused)data.details.sessions=data.details.sessions.filter(s=>s.model!=='opus');
 return data;
}
async function open(page,{locale='en',tier='tall',reduceMotion=false,...o}={}){
 await page.setViewportSize({width:636,height:tier==='tall'?890:640});
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale,reduceMotion},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:cardData(o)}))).toBe(true);
 await expect(page.locator('.fd-ch:not(.empty)')).toHaveCount(3);
}
const card=(page,name)=>page.locator('.fd-ch:not(.empty)').filter({has:page.locator('.st-name',{hasText:name})});
// The visible text lines of a card; the effort line's two parts are spaced by layout (a flex gap), so join them with a space.
const lines=ch=>ch.locator('.fd-strip').evaluate(s=>[...s.children].filter(e=>!e.matches('.st-vend,.cd-bar,.st-pin')).map(e=>e.matches('.cd-eff')&&e.children.length?[...e.children].map(c=>c.textContent.trim()).join(' '):e.textContent.trim()));
const row=(page,level)=>page.locator(`.sc-l[data-level="${level}"]`).evaluate(e=>{const r=e.getBoundingClientRect();return r.top+r.height/2;});
const centre=l=>l.evaluate(e=>{const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};});

test('CKP-FAD-50/55 cards: use large (tokens until ≈cost exists), share bar in the subscription colour, "212M 17%", effort line; one session lamp under "Sessions"',async({page})=>{
 await open(page);
 const sol=card(page,'Sol 6.1');
 await expect(sol.locator('.fd-strip')).toHaveAttribute('data-card','normal');
 expect(await lines(sol)).toEqual(['Sol 6.1','212M','212M 17%','High Med']); // ★ is a drawn glyph
 await expect(sol.locator('.cd-rec .g-star')).toHaveCount(1);
 await expect(sol.locator('.eb')).toHaveCount(0); // CKP-FAD-04 superseded: no ability bars
 const bar=await sol.locator('.cd-bar').evaluate(e=>({w:getComputedStyle(e,'::before').width,full:e.getBoundingClientRect().width,colour:getComputedStyle(e,'::before').backgroundColor}));
 expect(parseFloat(bar.w)/bar.full).toBeCloseTo(212/1247,1);expect(bar.colour).not.toBe('rgba(0, 0, 0, 0)');
 // Opus current XHigh, ★ Med: "XHigh ★Med" is 10 characters → "XHigh".
 expect((await lines(card(page,'GLM-5.3')))[1]).toBe('96M');
 expect((await lines(card(page,'Opus 5.5'))).at(-1)).toBe('XHigh');
 // Lamps: Sol and Opus run (lit, in the subscription colour), GLM is idle but used (dim). The row label reads Sessions.
 await expect(page.locator('.fd-scale .sc-led')).toHaveText('Sessions');
 await expect(sol.locator('.fd-indicator')).toHaveAttribute('data-state','live');
 await expect(card(page,'GLM-5.3').locator('.fd-indicator')).toHaveAttribute('data-state','used');
 // No card line overflows its card, tall and short (CKP-FAD-57: lines tighten, never overlap).
 for(const tier of ['tall','compact']){
  if(tier==='compact')await open(page,{tier});
  const bad=await page.locator('.fd-ch:not(.empty) .fd-strip').evaluateAll(list=>list.flatMap(s=>{const box=s.getBoundingClientRect(),kids=[...s.children].filter(e=>!e.matches('.st-vend,.st-pin')).map(e=>e.getBoundingClientRect());
   return kids.flatMap((r,i)=>[...(r.right>box.right+.5||r.bottom>box.bottom+.5?['out']:[]),...(i&&r.top<kids[i-1].bottom-.5?['overlap']:[])]);}));
  expect(bad,tier).toEqual([]);
 }
});

test('CKP-FAD-51 unused and zh: dimmed card "未使用 / ★Med", dashed lever',async({page})=>{
 await open(page,{locale:'zh-CN',opusUnused:true});
 const opus=card(page,'Opus 5.5');
 await expect(opus.locator('.fd-strip')).toHaveAttribute('data-card','unused');
 expect(await lines(opus)).toEqual(['Opus 5.5','未使用','Med']);
 await expect(opus.locator('.fd-cap')).toHaveClass(/\bunused\b/);
 await expect(opus.locator('.fd-indicator')).toHaveAttribute('data-state','off');
 expect((await lines(card(page,'Sol 6.1')))[1]).toBe('212M');
 await expect(page.locator('.fd-scale .sc-led')).toHaveText('会话');
});

test('CKP-FAD-54 the five steps, with their timings',async({page})=>{
 await open(page);
 const sol=card(page,'Sol 6.1'),strip=sol.locator('.fd-strip'),travel=sol.locator('[role=slider]'),ghost=sol.locator('.fd-ghost'),lever=sol.locator('.fd-cap');
 // 1 normal: use on the card, the user's page on the screen.
 const normal=await lines(sol);
 await expect(page.locator('.mfd-page.pg-overview')).toHaveCount(1);
 const frame=await lever.getAttribute('data-frame');
 // 2 click: frame, content unchanged; the effort page comes in over 150 ms; page keys dim; Back · Fast below.
 await strip.click();
 await expect(sol).toHaveClass(/\bsel\b/);
 expect(await lines(sol)).toEqual(normal);
 const screen=page.locator('.mfd-page.pg-compare');
 await expect(screen).toHaveCount(1);
 expect(await screen.evaluate(e=>{const s=getComputedStyle(e);return [s.animationName,s.animationDuration];})).toEqual(['cd-page-in','0.15s']);
 await expect(page.locator('.mfd-pk')).toHaveClass(/\bdark\b/);
 await expect(page.locator('.mfd-vk .vk-back')).toHaveCount(1);
 expect(await page.locator('#cockpit').getAttribute('data-sel-model')).toBe('sol');
 // 3 drag to XHigh: the blue ghost follows the pointer; the real lever does not move.
 const t=await centre(travel),high=await row(page,'High'),xhigh=await row(page,'XHigh');
 await page.mouse.move(t.x,high);await page.mouse.down();await page.mouse.move(t.x,(high+xhigh)/2+1,{steps:3});
 await expect(ghost).toBeVisible();await expect(ghost).toHaveClass(/\bdrag\b/);
 expect(await lever.getAttribute('data-frame')).toBe(frame);
 await page.mouse.move(t.x,xhigh+2,{steps:2});await page.mouse.up(); // released near XHigh: snaps to it
 await expect(travel).toHaveAttribute('data-trial','XHigh');
 await expect(strip).toHaveAttribute('data-card','try');
 expect(await lines(sol)).toEqual(['Sol 6.1','Try XHigh','Now High','Trying']);
 expect(await lever.getAttribute('data-frame')).toBe(frame);
 // 4 release: nothing changes; the trial stays.
 await page.waitForTimeout(400);
 await expect(strip).toHaveAttribute('data-card','try');await expect(screen).toHaveCount(1);
 // 5 cancel: the first Esc cancels only the trial (stays on the effort page); the ghost glides back over 280 ms, then hides.
 await page.keyboard.press('Escape');
 await expect(strip).toHaveAttribute('data-card','normal');
 await expect(page.locator('.mfd-page.pg-compare')).toHaveCount(1);
 expect(await ghost.evaluate(e=>({back:e.classList.contains('back'),d:getComputedStyle(e).transitionDuration}))).toEqual({back:true,d:expect.stringContaining('0.28s')});
 await expect(ghost).toBeHidden({timeout:2000});
 // The second Esc returns to the page underneath and deselects; the page keys come back.
 await page.keyboard.press('Escape');
 await expect(page.locator('.mfd-page.pg-overview')).toHaveCount(1);
 await expect(page.locator('.fd-ch.sel')).toHaveCount(0);
 await expect(page.locator('.mfd-pk')).not.toHaveClass(/\bdark\b/);
 expect(await page.locator('#cockpit').getAttribute('data-sel-model')).toBeNull();
});

test('CKP-FAD-54 a second click on the card, or a click on empty fader space, deselects; one model at a time',async({page})=>{
 await open(page);
 const sol=card(page,'Sol 6.1'),opus=card(page,'Opus 5.5');
 await sol.locator('.fd-strip').click();await expect(sol).toHaveClass(/\bsel\b/);
 await opus.locator('.fd-strip').click(); // another card = the first is deselected
 await expect(page.locator('.fd-ch.sel')).toHaveCount(1);await expect(opus).toHaveClass(/\bsel\b/);
 await opus.locator('.fd-strip').click();
 await expect(page.locator('.fd-ch.sel')).toHaveCount(0);await expect(page.locator('.mfd-page.pg-compare')).toHaveCount(0);
 await sol.locator('.fd-strip').click();await expect(page.locator('.mfd-page.pg-compare')).toHaveCount(1);
 const leds=await sol.locator('.fd-leds').evaluate(e=>{const r=e.getBoundingClientRect();return {x:r.left+4,y:r.top+r.height/2};});
 await page.mouse.click(leds.x,leds.y); // the lamp row beside the lamp: empty space
 await expect(page.locator('.fd-ch.sel')).toHaveCount(0);await expect(page.locator('.mfd-page.pg-compare')).toHaveCount(0);
});

test('CKP-FAD-54 Reduce Motion: the effort page switches without the fade and the ghost does not glide',async({page})=>{
 await open(page,{reduceMotion:true});
 const sol=card(page,'Sol 6.1');
 await sol.locator('.fd-strip').click();
 expect(await page.locator('.mfd-page.pg-compare').evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
 await sol.locator('[role=slider]').focus();await page.keyboard.press('ArrowUp');
 await expect(sol.locator('.fd-strip')).toHaveAttribute('data-card','try');
 await page.keyboard.press('Escape');
 expect(await sol.locator('.fd-ghost').evaluate(e=>getComputedStyle(e).transitionProperty)).not.toContain('top');
 await expect(sol.locator('.fd-ghost')).toBeHidden({timeout:2000});
});
