// SPDX-License-Identifier: MIT
// GLM batch of G1 cockpit journeys against the built page, driven through its
// normal bridge with synthetic data. IDs reference the requirements registry;
// only the IDs travel in code and PRs. Tests marked with test.fail() document
// clauses the built page does not implement yet (empty fader bays, absent HUD
// and update payload, device- or native-measured seams); they flip by removing
// the annotation once the product lands.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

async function open(page,data=visualFixture().data) {
 await page.addInitScript(()=>{window.__g1Messages=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__g1Messages.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}

// ---- Entry ----

test('CKP-ENTRY-02 holding ignition opens like a press',async({page})=>{
 test.fail(); // ignition lives on the native dock; the built page has no ignition seam yet.
 await open(page);
 expect(await page.locator('[data-ignition],.ignition,[data-ignition-hold]').count()).toBe(1);
});

test('CKP-ENTRY-06 opening is usable within the quick-open budget',async({page})=>{
 test.fail(); // the open budget is host-measured on device; no web seam reports it yet.
 const {receive,send}=await open(page);
 expect(await page.evaluate(()=>window.__cockpitOpenMs)).toBeLessThanOrEqual(300);
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
});

// ---- Faders: the v1 bridge carries no publication payload, so every channel
// ---- renders as an empty bay; these document the clauses per surface.

test('CKP-FAD-01 one fader per model, three per bank, banks paged with arrows',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-ch:not(.empty)').count()).toBe(3);
 expect(await page.locator('.fd-bank [data-bank]').count()).toBe(2);
});

test('CKP-FAD-02 faders order in use, recommended, then others; long press pins',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-strip[data-strip]').count()).toBe(3);
 await page.locator('.fd-strip[data-strip]').first().dispatchEvent('pointerdown');
 await page.waitForTimeout(600);
 expect(await page.locator('.fd-ch[data-pinned]').count()).toBe(1);
});

test('CKP-FAD-03 LCD vendor strip sits on the top edge, split per subscription',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-strip .st-vend b').count()).toBeGreaterThan(0);
});

test('CKP-FAD-04 five effort bars with published heights, current white, trial blue, star gold',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-strip .eb').count()).toBe(15);
 expect(await page.locator('.fd-strip .st-star').count()).toBeGreaterThan(0);
});

test('CKP-FAD-05 LCD state value shows the current effort and the star multiple',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-strip .st-val').count()).toBe(3);
});

test('CKP-FAD-06 trial value prints the blue try label with a muted current multiple',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-ch.trying').count()).toBe(1);
});

test('CKP-FAD-07 gold notch marks the recommendation and detents stay spaced on the travel',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-marks .fd-rec').count()).toBe(3);
 const travel=await page.locator('.fd-travel').first().boundingBox();
 expect(travel.height).toBeGreaterThanOrEqual(100);
});

test('CKP-FAD-08 session LEDs sit above each fader in vendor colour',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-leds .fd-indicator i').count()).toBeGreaterThan(0);
});

test('CKP-FAD-09 a trial sets a blue ghost cap while the real cap stays',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 expect(await page.locator('.fd-ghost:not([hidden])').count()).toBe(1);
 expect(await page.locator('.fd-cap:not([hidden])').count()).toBe(3);
});

test('CKP-FAD-10 closing ends the trial and the ghost glides back into the cap',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 const {send,receive}=await open(page);
 expect(await page.locator('.fd-ch.trying').count()).toBe(1);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 expect(await page.locator('.fd-ghost:not([hidden])').count()).toBe(0);
});

test('CKP-FAD-11 a real fast session lights the LCD lamp; fast toggles from the screen key',async({page})=>{
 test.fail(); // empty bays: the fast lamp and its screen key are not rendered yet.
 await open(page);
 expect(await page.locator('.fd-strip .st-fast').count()).toBe(1);
 expect(await page.locator('.mfd-ok [data-opt="fast"]').count()).toBe(1);
});

test('CKP-FAD-12 faders glide on scope switch and effort change',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 await open(page);
 const glide=await page.evaluate(()=>getComputedStyle(document.querySelector('.fd-travel')).transitionDuration);
 expect(glide).toContain('0.28s');
});

test('CKP-FAD-13 narrow viewports shrink the LCD and grow the travel',async({page})=>{
 test.fail(); // empty bays: no publication arrives through the v1 bridge.
 const {send,receive}=await open(page);
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
 const lcd=await page.locator('.fd-strip').first().boundingBox(),travel=await page.locator('.fd-travel').first().boundingBox();
 expect(travel.height).toBeGreaterThan(lcd.height);
 expect(lcd.height).toBeLessThan(40);
});

// ---- Multi-function display ----

test('CKP-MFD-09 the update row sits last on the overview and confirms in place',async({page})=>{
 test.fail(); // no update payload exists in the v1 bridge, so no update row renders.
 await open(page);
 const last=await page.evaluate(()=>{const p=document.querySelector('.mfd-page');return {cls:p.lastElementChild.className,text:p.lastElementChild.textContent};});
 expect(last.text).toMatch(/↑/);
 expect(last.cls).toMatch(/update|ov-update/);
 expect(await page.locator('.mfd-page [data-mfd="install"],.mfd-page [data-mfd="later"],.mfd-page [data-mfd="whatsnew"]').count()).toBe(3);
});

test('CKP-MFD-24 website links stay small, user-invoked, and anchor explanations',async({page})=>{
 test.fail(); // the explanation links render only on pages the built screen cannot fill.
 const {send,receive}=await open(page);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await page.locator('.sa-list .sa').first().click();
 const link=page.locator('.sp-h .website-link').first();
 await expect(link).toHaveAttribute('href',/\/plans\?seller=/);
 expect(await page.locator('.tune-links .website-link').count()).toBeGreaterThanOrEqual(1);
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 expect(await page.locator('.website-link').evaluateAll(nodes=>nodes.every(n=>n.rel==='noopener noreferrer'))).toBe(true);
});

// ---- Porthole ----

test('CKP-PORT-01 porthole shows shipped stills and never constructs a field renderer',async({page})=>{
 await page.addInitScript(()=>{window.__fieldContexts=[];const get=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(...args){window.__fieldContexts.push(String(args[0]));return get.apply(this,args);};});
 const {send,receive}=await open(page);
 const still=await page.evaluate(()=>getComputedStyle(document.querySelector('.ck-portrow'),'::before').backgroundImage);
 expect(still).toContain('canopy-890');
 await page.locator('.ek[data-sub]').first().click();
 for(const key of ['Subscription','Effort','Breakdown'])await page.getByRole('button',{name:key,exact:true}).click();
 expect(await page.evaluate(()=>window.__fieldContexts.length)).toBe(0);
 await expect(page.locator('canvas')).toHaveCount(0);
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
 expect(await page.evaluate(()=>window.__fieldContexts.length)).toBe(0);
});

test('CKP-PORT-02 rocket badges are blurred stills with no readable third-party mark',async({page})=>{
 test.fail(); // the badge stills are not shipped in the built page yet.
 await open(page);
 expect(await page.locator('.ck-port [data-badge],.hud img,.ck-field img').count()).toBe(8);
});

test('CKP-PORT-03 the default HUD is one screen of 180x160 at its window-local origin',async({page})=>{
 test.fail(); // the built HUD is the summary strip, not the projected screen yet.
 await open(page);
 const hud=await page.locator('.hud').boundingBox(),root=await page.locator('#cockpit').boundingBox();
 expect(hud.width).toBeCloseTo(180,0);expect(hud.height).toBeCloseTo(160,0);
 expect(hud.x-root.x).toBeCloseTo(76,0);expect(hud.y-root.y).toBeCloseTo(24,0);
});

test('CKP-PORT-04 the HUD lists the first six chart models with complete labels',async({page})=>{
 test.fail(); // the built HUD is the summary strip, not the projected screen yet.
 await open(page);
 expect(await page.locator('.hud svg').count()).toBe(1);
 expect(await page.locator('.hud [data-hud-name]').count()).toBe(6);
 await expect(page.locator('.hud [data-hud-name]').last()).not.toContainText('…');
});

test('CKP-PORT-05 the compact profile HUD is one strip of 216x30 at its origin',async({page})=>{
 test.fail(); // the compact profile hides the HUD entirely in the built page.
 const {send,receive}=await open(page);
 expect(await receive(send('shell',{...shell,tier:'compact'}))).toBe(true);
 const hud=await page.locator('.hud').boundingBox(),root=await page.locator('#cockpit').boundingBox();
 expect([hud.width,hud.height]).toEqual([216,30]);
 expect(hud.x-root.x).toBeCloseTo(58,0);expect(hud.y-root.y).toBeCloseTo(9,0);
});

test('CKP-PORT-06 a HUD row click opens the effort page and hover highlights its rocket',async({page})=>{
 test.fail(); // the built HUD is the summary strip, not the projected screen yet.
 const {receive,send}=await open(page);
 expect(await page.locator('.hud .hm-row').count()).toBe(6);
 await page.locator('.hud .hm-row').first().click();
 expect(await page.locator('.mfd-page.pg-tune').count()).toBe(1);
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
});

test('CKP-PORT-07 one shared selection feeds the HUD, small field and effort page',async({page})=>{
 test.fail(); // the small field renders nothing: selection content is not built yet.
 await open(page);
 expect(await page.evaluate(()=>document.querySelectorAll('.ck-field [data-field-row]').length)).toBeGreaterThanOrEqual(1);
});

test('CKP-PORT-08 the mini chart plots one star point per model with a gold frontier',async({page})=>{
 test.fail(); // the built HUD is the summary strip, not the projected screen yet.
 await open(page);
 expect(await page.locator('.hud svg .frontier').count()).toBe(1);
 expect(await page.locator('.hud svg [data-star]').count()).toBeGreaterThanOrEqual(3);
});

test('CKP-PORT-09 the shutter is centred on the strip and closing swaps canopy for slab',async({page})=>{
 const {send,receive}=await open(page);
 const head=await page.locator('.ck-head').boundingBox(),shutter=await page.locator('[data-shutter]').boundingBox();
 expect(shutter.x+shutter.width/2).toBeCloseTo(head.x+head.width/2,0);
 const eng=await page.locator('.ck-eng').boundingBox(),tape=await page.locator('.ck-tape').boundingBox();
 expect(await receive(send('shell',{...shell,profile:'closed'}))).toBe(true);
 await expect(page.locator('.ck-portrow')).toBeHidden();
 await expect(page.locator('.s6-closed-cap')).toBeVisible();
 const engClosed=await page.locator('.ck-eng').boundingBox(),tapeClosed=await page.locator('.ck-tape').boundingBox();
 expect(engClosed.height).toBeCloseTo(eng.height,6);expect(tapeClosed.height).toBeCloseTo(tape.height,6);
 expect(await page.evaluate(()=>document.getElementById('cockpit').style.getPropertyValue('--body-h'))).toBe('691px');
});

test('CKP-PORT-10 glass turns solid and borderless under Reduce Transparency',async({page})=>{
 // HUD B's own projected-scrim geometry is expected-failing under CKP-PORT-03;
 // this asserts the glass-solidity substance the built page implements.
 const {send,receive}=await open(page);
 expect(await receive(send('appearance',{...appearance,reduceTransparency:true}))).toBe(true);
 await expect(page.locator('.hud.solid')).toHaveCount(1);
 const scrim=await page.evaluate(()=>{const s=getComputedStyle(document.querySelector('.hud'));return {blur:s.backdropFilter,border:s.borderTopWidth,bg:s.backgroundImage};});
 expect(scrim.blur).toBe('none');expect(scrim.border).toBe('0px');
 expect(scrim.bg).toMatch(/radial-gradient\([^)]*rgb\(\d+, \d+, \d+\)/);
});

// ---- Shell ----

test('CKP-SHELL-15 one gunmetal finish transfers over the open metal',async({page})=>{
 test.fail(); // the built page applies no colour transfer; the art ships unfiltered.
 await open(page);
 const filter=await page.evaluate(()=>getComputedStyle(document.querySelector('.ck-shell .hull-lower')).filter);
 expect(filter).toBe('saturate(0.12) brightness(0.78)');
});

test('CKP-SHELL-19 open cycles stay within the U11a budget and memory returns after close',async({page})=>{
 test.fail(); // CPU and memory budgets are device measurements; no web seam reports them.
 const {receive,send}=await open(page);
 const unbounded=await page.evaluate(()=>{
  const found=[];
  for(const animation of document.getAnimations())if(!Number.isFinite(animation.effect.getTiming().iterations))found.push('unbounded runtime effect');
  return found;
 });
 expect(unbounded).toEqual([]);
 expect(await page.evaluate(()=>window.__u11aBudget)).toBe('object');
 expect(await receive(send('display',{data:visualFixture().data}))).toBe(true);
});
