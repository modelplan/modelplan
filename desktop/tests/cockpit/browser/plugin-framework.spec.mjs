// SPDX-License-Identifier: MIT
// Cockpit plugin framework (owner D121, D124, D293; CKP-PLG-50…53): plugin keys and columns in the subscription grammar,
// the column-count rule, pin to page 1, the right-click Remove, the big screen opened from the key, the empty-slot "+"
// menu and the lifecycle (only while the cockpit is open and the column is shown). Entered through the normal bridge.
// Uses the framework's placeholder plugin; the real plugins bring their own specs.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// The calendar (D121) and resource (D324) plugins are default on; these framework specs keep them off so only the
// placeholder is laid out.
const calendarOff={id:'calendar',enabled:false,pinned:false};
const RES_OFF={id:'resources',enabled:false,pinned:false};
const on=(pinned=false,settings={})=>({version:1,entries:[{id:'placeholder',enabled:true,pinned},calendarOff,RES_OFF],settings:{placeholder:settings}});
/** `count` connected subscriptions, plus tools found but not connected. */
function dataWith(count,unconnected=[]) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 for(const [i,[id,state]] of unconnected.entries()){const row=structuredClone(seed);row.id=id;row.name={en:id,zh:id};row.order=50+i;row.state=state;row.accounts=[];data.projection.rows.push(row);}
 return data;
}
async function open(page,data,plugins) {
 await page.clock.setFixedTime(new Date('2026-11-04T12:00:00Z'));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(plugins)expect(await receive(send('plugins',{plugins}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const pluginEdits=page=>page.evaluate(()=>window.__events.filter(e=>e.type==='action'&&e.action==='pluginsEdit').map(e=>e.plugins));
const running=page=>page.evaluate(()=>window.__events.filter(e=>e.type==='action'&&e.action==='pluginsRunning').map(e=>e.ids));
const column=page=>page.locator('.eng-cols .pl-col[data-plugin="placeholder"]');
const key=page=>page.locator('.eng-keys .pl-key[data-plugin="placeholder"]');

test('CKP-PLG-52 columns = subscriptions + plugins, at least 3, at most 6 a page, plugins after subscriptions',async({page})=>{
 const {send,receive}=await open(page,dataWith(1),on());
 // [subscriptions, slots with the plugin, plugin shown]
 for(const [count,slots,shown] of [[1,3,true],[2,3,true],[3,4,true],[4,5,true],[5,6,true],[6,6,false]]){
  expect(await receive(send('display',{data:dataWith(count)}))).toBe(true);
  await expect(page.locator('.eng-keys'),`${count} subscriptions`).toHaveAttribute('data-slots',String(slots));
  await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(count);
  await expect(page.locator('.eng-keys .pl-key')).toHaveCount(shown?1:0);
  await expect(page.locator('.eng-cols .pl-col')).toHaveCount(shown?1:0);
  await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(slots-count-(shown?1:0));
  if(shown)expect(await page.evaluate(()=>{const cols=[...document.querySelectorAll('.eng-cols > *')];const i=cols.findIndex(c=>c.classList.contains('pl-col'));return cols.slice(0,i).every(c=>c.matches('.ec[data-col]'))&&cols.slice(i+1).every(c=>c.matches('.ec-bay'));})).toBe(true);
 }
 // Off (turned off by the host): the v1 table, with "+" on the empty slots.
 expect(await receive(send('plugins',{plugins:{version:1,entries:[calendarOff,RES_OFF],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(2)}))).toBe(true);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','3');
 await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
});

test('CKP-PLG-50 the plugin key is a subscription key: same box and white name, line icon in the mark box, dashed underline, no ×',async({page})=>{
 const data=dataWith(2);data.projection.rows[0].vendorKey='openai';
 await open(page,data,on());
 const geometry=await page.evaluate(()=>{
  const sub=document.querySelector('.eng-keys .ek[data-sub] .lamp').closest('.ek'),plug=document.querySelector('.eng-keys .pl-key');
  const box=e=>{const r=e.getBoundingClientRect();return {w:Math.round(r.width*2)/2,h:Math.round(r.height*2)/2,top:Math.round(r.top*2)/2};};
  const type=e=>{const s=getComputedStyle(e);return {size:s.fontSize,weight:s.fontWeight,colour:s.color,family:s.fontFamily};};
  const line=e=>{const s=getComputedStyle(e);const r=e.getBoundingClientRect();return {image:s.backgroundImage,h:r.height,bottom:Math.round(e.parentElement.getBoundingClientRect().bottom-r.bottom)};};
  return {key:[box(sub),box(plug)],mark:[sub,plug].map(k=>{const m=k.querySelector('.lamp'),r=m.getBoundingClientRect();return {w:m.offsetWidth,h:m.offsetHeight,centre:Math.round(r.top+r.height/2)};}),name:[type(sub.querySelector('.ek-name')),type(plug.querySelector('.ek-name'))],
   line:[line(sub.querySelector('.bl')),line(plug.querySelector('.bl'))],plugColour:plug.querySelector('.bl').style.getPropertyValue('--v'),iconStroke:getComputedStyle(plug.querySelector('.lamp')).color,
   text:plug.textContent,inner:plug.querySelectorAll('button').length};
 });
 expect(geometry.key[1]).toEqual(geometry.key[0]);
 // The icon sits in the vendor mark's layout box (the mark's own glyph scale is not part of the box).
 expect(geometry.mark[1]).toEqual(geometry.mark[0]);
 expect(geometry.name[1]).toEqual(geometry.name[0]);
 // Same underline position and height; the plugin's is dashed in the colour the plugin declares, the subscription's solid.
 expect(geometry.line[1].h).toBe(geometry.line[0].h);expect(geometry.line[1].bottom).toBe(geometry.line[0].bottom);
 expect(geometry.line[0].image).toBe('none');expect(geometry.line[1].image).toContain('repeating-linear-gradient');
 expect(geometry.plugColour).toBe('#87939e');
 expect(geometry.iconStroke).toBe(geometry.name[0].colour);
 expect(geometry.text).not.toContain('×');expect(geometry.inner).toBe(0);
 await expect(page.locator('.eng-keys .pl-key .ki')).toHaveCount(0);
 await expect(page.getByRole('button',{name:/Remove/})).toHaveCount(0);
 await expect(key(page).locator('.ek-name')).toHaveText('Placeholder');
 // Removal lives in the right-click menu (and Settings).
 await key(page).click({button:'right'});
 const menu=page.getByRole('menu',{name:'Placeholder plugin menu'});await expect(menu).toBeVisible();
 await expect(menu.getByRole('menuitem')).toHaveText(['Remove from the cockpit']);
 await page.keyboard.press('Escape');await expect(menu).toHaveCount(0);
 await key(page).focus();await page.keyboard.press('Shift+F10');await expect(menu).toBeVisible();
 await menu.getByRole('menuitem').click();
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 expect(await pluginEdits(page)).toEqual([{version:1,entries:[{id:'placeholder',enabled:false,pinned:false},calendarOff,RES_OFF],settings:{placeholder:{}}}]);
});

test('CKP-PLG-51 the plugin column has no inner frame; its cells use the Other-cell grammar and align with subscription rows',async({page})=>{
 const {send,receive}=await open(page,dataWith(2),on(false,{intervalSeconds:5}));
 for(const value of [20,35,61])expect(await receive(send('pluginData',{id:'placeholder',data:{value}}))).toBe(true);
 const cell=column(page).locator('.pl-cell[data-row="0"]');
 await expect(cell.locator('.pl-tag')).toHaveText('Last value');
 await expect(cell.locator('.qnum')).toHaveText('61%');
 await expect(cell.locator('.qtxt')).toHaveText('every 5 s');
 await expect(cell.locator('.pl-bar i')).toHaveCount(1);
 await expect(cell.locator('.pl-trend path')).toHaveCount(1);
 await expect(column(page).locator('.pl-foot')).toHaveText('Framework');
 const shape=await page.evaluate(()=>{
  const sub=document.querySelector('.eng-cols .ec[data-col]'),plug=document.querySelector('.eng-cols .pl-col');
  const tops=c=>[...c.children].map(e=>Math.round(e.getBoundingClientRect().top));
  const frames=[plug,...plug.querySelectorAll('*')].filter(e=>{const s=getComputedStyle(e);return s.boxShadow!=='none'||['Top','Right','Bottom','Left'].some(side=>s['border'+side+'Style']!=='none'&&parseFloat(s['border'+side+'Width'])>0&&!e.classList.contains('qrow-t'));}).map(e=>e.className);
  const sizes=(c,sel)=>{const e=c.querySelector(sel);if(!e)return null;const s=getComputedStyle(e);return {size:s.fontSize,family:s.fontFamily};};
  const bar=plug.querySelector('.pl-bar').getBoundingClientRect(),fill=plug.querySelector('.pl-bar i').getBoundingClientRect();
  return {sub:tops(sub),plug:tops(plug),frames,num:[sizes(sub,'.qnum'),sizes(plug,'.qnum')],side:[sizes(sub,'.qtxt'),sizes(plug,'.qtxt')],fill:Math.round(fill.width/bar.width*100),segments:plug.querySelectorAll('.pl-bar i').length};
 });
 // Rows line up with the subscription column (three cells, the bottom line), and nothing draws a frame inside it.
 expect(shape.plug).toEqual(shape.sub);
 expect(shape.frames).toEqual([]);
 expect(shape.num[1]).toEqual(shape.num[0]);expect(shape.side[1]).toEqual(shape.side[0]);
 // The bar is continuous (one fill), not the quota's ten segments.
 expect(shape.fill).toBe(61);expect(shape.segments).toBe(1);
});

test('CKP-PLG-52 pin keeps the plugin on page 1 with many subscriptions; unpinned plugins only fill free slots',async({page})=>{
 const {send,receive}=await open(page,dataWith(6),on(false));
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 expect(await receive(send('plugins',{plugins:on(true)}))).toBe(true);
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(5);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 await page.getByRole('button',{name:'Next subscriptions'}).click();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 // Seven subscriptions, unpinned: the plugin takes a free slot on the last page.
 expect(await receive(send('plugins',{plugins:on(false)}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(7)}))).toBe(true);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 await page.getByRole('button',{name:'Next subscriptions'}).click();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 // A shortcut digit still selects subscriptions only.
 await page.keyboard.press('1');
 await expect(page.locator('.eng-keys .ek[data-sub]').first()).toHaveAttribute('aria-pressed','true');
});

test('CKP-PLG-53 clicking the plugin key opens its big screen inside the big-screen area; faders and page keys stay uncovered',async({page})=>{
 const {send,receive}=await open(page,dataWith(2),on());
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:42}}))).toBe(true);
 await key(page).click();
 const screen=page.getByRole('region',{name:'Placeholder plugin screen'});await expect(screen).toBeVisible();
 await expect(key(page)).toHaveAttribute('aria-expanded','true');
 await expect(screen.locator('dd')).toHaveText(['42%','every 10 s']);
 const layout=await page.evaluate(()=>{
  const r=e=>e.getBoundingClientRect(),s=r(document.querySelector('.pl-screen')),well=r(document.querySelector('.mfd-screen'));
  const overlaps=b=>!(b.right<=s.left||b.left>=s.right||b.bottom<=s.top||b.top>=s.bottom);
  const blockers=[...document.querySelectorAll('.dk-fad,.mfd-pk,.mfd-pk .pk')].filter(e=>overlaps(r(e))).map(e=>e.className);
  // D387: the Overview key is the switch while a screen is open (its tabs stand in for it); the other page keys must stay uncovered.
  const keys=[...document.querySelectorAll('.mfd-pk .pk:not([hidden]),.mfd-pk .pk-seg:not([hidden]) [role=tab]')].map(k=>{const b=r(k);return document.elementFromPoint(b.left+b.width/2,b.top+b.height/2)===k||k.contains(document.elementFromPoint(b.left+b.width/2,b.top+b.height/2));});
  const fader=document.querySelector('.dk-fad'),fb=r(fader),hit=document.elementFromPoint(fb.left+fb.width/2,fb.top+fb.height/2);
  return {inside:s.left>=well.left-0.5&&s.right<=well.right+0.5&&s.top>=well.top-0.5&&s.bottom<=well.bottom+0.5,blockers,keys,fader:!!hit&&fader.contains(hit)};
 });
 expect(layout).toEqual({inside:true,blockers:[],keys:layout.keys.map(()=>true),fader:true});
 expect(layout.keys.length).toBeGreaterThan(0);
 // A new reading redraws the open screen; the key toggles it; Escape closes it and returns focus to the key.
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:43}}))).toBe(true);
 await expect(screen.locator('dd').first()).toHaveText('43%');
 await key(page).click();await expect(screen).toHaveCount(0);
 await key(page).click();await expect(screen).toBeVisible();
 await page.keyboard.press('Escape');await expect(screen).toHaveCount(0);await expect(key(page)).toBeFocused();
 // Pressing a page key goes to that page and closes the plugin screen.
 await key(page).click();await expect(screen).toBeVisible();
 await page.locator('.mfd-pk .pk').nth(1).click();
 await expect(screen).toHaveCount(0);
 await expect(page.locator('.mfd-pk .pk').nth(1)).toHaveClass(/\bon\b/);
});

test('CKP-PLG-53 a page key activated from the keyboard (Enter or Space) also closes the plugin screen',async({page})=>{
 await open(page,dataWith(2),on());
 const screen=page.locator('.pl-screen');
 for(const [i,press] of [[1,'Enter'],[2,' ']]){
  await key(page).click();await expect(screen).toBeVisible();
  await page.locator('.mfd-pk .pk').nth(i).focus();await page.keyboard.press(press===' '?'Space':press);
  await expect(page.locator('.mfd-pk .pk').nth(i)).toHaveClass(/\bon\b/);
  await expect(screen,`page key ${i} by ${press}`).toHaveCount(0);
  await expect(key(page)).toHaveAttribute('aria-expanded','false');
 }
});

test('CKP-PLG-53 a reading updates the open plugin screen in place: the focused screen tab stays mounted and focused',async({page})=>{
 const {send,receive}=await open(page,dataWith(2),on());
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:10}}))).toBe(true);
 await key(page).click();
 const close=page.locator('.mfd-pk .pk-seg [role=tab][aria-selected=true]');await close.focus();await expect(close).toBeFocused();
 await page.evaluate(()=>{window.__close=document.querySelector('.mfd-pk .pk-seg [role=tab][aria-selected=true]');});
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:11}}))).toBe(true);
 await expect(page.locator('.pl-screen dd').first()).toHaveText('11%');
 await expect(close).toBeFocused();
 expect(await page.evaluate(()=>window.__close===document.querySelector('.mfd-pk .pk-seg [role=tab][aria-selected=true]')&&window.__close.isConnected)).toBe(true);
 // A repaint (new display) and a host settings change redraw the screen in place too.
 expect(await receive(send('display',{data:dataWith(2)}))).toBe(true);
 expect(await receive(send('plugins',{plugins:on(false,{intervalSeconds:4})}))).toBe(true);
 await expect(page.locator('.pl-screen dd').last()).toHaveText('every 4 s');
 await expect(close).toBeFocused();
 // Removal in Settings (host state turns it off) closes the screen.
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'placeholder',enabled:false,pinned:false},calendarOff,RES_OFF],settings:{}}}))).toBe(true);
 await expect(page.locator('.pl-screen')).toHaveCount(0);
});

test('lifecycle: the plugin runs only while the cockpit is open and its column is on the shown page',async({page})=>{
 const {send,receive}=await open(page,dataWith(7),on(false,{intervalSeconds:5}));
 const reading=value=>send('pluginData',{id:'placeholder',data:{value}});
 // Page 1 has no room: not shown, never started, and host readings are refused.
 await expect(column(page)).toHaveCount(0);
 expect(await receive(reading(1))).toBe(false);
 await page.getByRole('button',{name:'Next subscriptions'}).click();
 await expect(column(page)).toHaveAttribute('data-running','true');
 expect(await receive(reading(7))).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveText('7');
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:'x'}}))).toBe(false);
 expect(await receive(send('pluginData',{id:'unknown',data:{value:1}}))).toBe(false);
 // Occluded: stopped, readings refused; the plugin keeps its value and resumes when visible again.
 expect(await receive(send('visibility',{visible:true,occluded:true,key:false}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','false');
 expect(await receive(reading(8))).toBe(false);
 // Visible but not key still counts as open.
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','true');
 // A repaint (new reading) keeps the plugin's own state.
 expect(await receive(send('display',{data:dataWith(7)}))).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveText('7');
 await expect(column(page)).toHaveAttribute('data-running','true');
 // Page away: stopped.
 await page.getByRole('button',{name:'Previous subscriptions'}).click();
 await expect(page.locator('.pl-col')).toHaveCount(0);
 expect(await receive(reading(9))).toBe(false);
 await page.getByRole('button',{name:'Next subscriptions'}).click();
 await expect(column(page).locator('.qvalue')).toHaveText('7');
 // A settings change from the host redraws the column.
 expect(await receive(send('plugins',{plugins:on(false,{intervalSeconds:3})}))).toBe(true);
 await expect(column(page).locator('.qtxt')).toHaveText('every 3 s');
 // Removed from the right-click menu: stopped, the column turns back into a "+" slot and the host gets the edit.
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await key(page).click({button:'right'});await page.getByRole('menuitem',{name:'Remove from the cockpit'}).click();
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 expect(await pluginEdits(page)).toEqual([{version:1,entries:[{id:'placeholder',enabled:false,pinned:false},calendarOff,RES_OFF],settings:{placeholder:{intervalSeconds:3}}}]);
 // Cleared readings stop everything.
 expect(await receive(send('plugins',{plugins:on(false)}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','true');
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
 await expect(page.locator('.pl-col')).toHaveCount(0);
 // The host samples exactly what the page reports as running, on every change and never more.
 expect(await running(page)).toEqual([[],['placeholder'],[],['placeholder'],[],['placeholder'],[],['placeholder'],[]]);
});

test('macrev2-1104-2 a privacy clear drops host readings: the next generation shows no old value until a fresh reading',async({page})=>{
 const {send,receive}=await open(page,dataWith(1),on(true));
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:42}}))).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveText('42');
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
 await expect(page.locator('.pl-col')).toHaveCount(0);
 // The native host re-sends its state after the clear, then the new generation renders before any reading.
 expect(await receive(send('plugins',{viewRevision:'4',plugins:on(true)}))).toBe(true);
 expect(await receive(send('display',{viewRevision:'4',data:dataWith(1)}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','true');
 await expect(column(page).locator('.qvalue')).toHaveCount(0);
 expect(await receive(send('pluginData',{viewRevision:'4',id:'placeholder',data:{value:7}}))).toBe(true);
 await expect(column(page).locator('.qvalue')).toHaveText('7');
 // A reading kept from before the clear would have made a trend of two points; only the fresh one is there.
 await expect(column(page).locator('.pl-trend')).toHaveCount(0);
});

test('#1104 a host pluginScreen message opens an enabled plugin\'s big screen and leaves an open one open',async({page})=>{
 const {send,receive}=await open(page,dataWith(1));
 const screen=page.locator('.dk-mfd .mfd-screen .pl-screen[data-plugin="placeholder"]');
 expect(await receive(send('pluginScreen',{id:'placeholder'}))).toBe(false);
 expect(await page.evaluate(()=>window.modelPlanCockpit.reject())).toBe('pluginScreen.refused');
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'placeholder',enabled:false,pinned:false}],settings:{}}}))).toBe(true);
 expect(await receive(send('pluginScreen',{id:'placeholder'}))).toBe(false);
 await expect(screen).toHaveCount(0);
 expect(await receive(send('plugins',{plugins:on(true)}))).toBe(true);
 expect(await receive(send('pluginScreen',{id:'placeholder'}))).toBe(true);
 await expect(screen).toHaveCount(1);
 expect(await receive(send('pluginScreen',{id:'placeholder'}))).toBe(true);
 await expect(screen).toHaveCount(1);
 expect(await receive(send('pluginScreen',{id:'Bad id'}))).toBe(false);
 expect(await receive(send('pluginScreen',{id:'placeholder',extra:1}))).toBe(false);
 await expect(screen).toHaveCount(1);
});

test('"+" menu: detected tools first, then all subscriptions; plugins below (never the framework placeholder); Add places the plugin',async({page})=>{
 const calendarColumn=page.locator('.eng-cols .pl-col[data-plugin="calendar"]'),calendarKey=page.locator('.eng-keys .pl-key[data-plugin="calendar"]');
 const {send,receive}=await open(page,dataWith(1,[['grok','off'],['gemini-cli','needs_consent']]));
 const plus=page.locator('.eng-keys .ek-bay').first();
 await expect(plus).toHaveAttribute('aria-label','＋ Add a subscription');
 await plus.click();
 const menu=page.getByRole('menu',{name:'Add to the engine table'});await expect(menu).toBeVisible();
 await expect(menu.locator('.pm-h')).toHaveText(['Connect a subscription','Add a plugin']);
 await expect(menu.locator('.pm-connect .pm-n')).toHaveText(['gemini-cli','grok']);
 await expect(menu.locator('.pm-connect .pm-st')).toHaveText(['Detected','Not connected']);
 await expect(menu.locator('[data-pm-all]')).toHaveText('All subscriptions…');
 // Owner 11-21: the placeholder is a framework fixture; no user-facing list offers it. The shipped plugins are offered.
 await expect(menu.locator('[data-pm-plugin="placeholder"]')).toHaveCount(0);
 await expect(menu.locator('[data-pm-plugin]')).toHaveCount(2);
 await expect(menu.locator('[data-pm-plugin="calendar"]')).toContainText('Add');
 // Escape closes and returns focus; a connect item asks the host for Settings > Subscriptions (CKP-ENG-24).
 await page.keyboard.press('Escape');await expect(menu).toHaveCount(0);await expect(plus).toBeFocused();
 await plus.click();await menu.locator('[data-pm-row="gemini-cli"]').click();
 expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['openSettingsSubscriptions']);
 await plus.click();await menu.locator('[data-pm-plugin="calendar"]').click();
 await expect(menu).toHaveCount(0);
 await expect(calendarColumn).toHaveCount(1);
 await expect(calendarColumn).toHaveAttribute('data-running','true');
 // This host never sent plugin state, so the page keeps the edit to itself (an older host would reject the action).
 expect(await pluginEdits(page)).toEqual([]);expect(await running(page)).toEqual([]);
 await page.locator('.eng-keys .ek-bay').first().click();
 await expect(menu.locator('[data-pm-plugin="calendar"]')).toBeDisabled();
 await expect(menu.locator('[data-pm-plugin="calendar"]')).toContainText('✓ Added');
 // Chinese labels.
 await page.keyboard.press('Escape');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN',redBelow:25}))).toBe(true);
 await page.locator('.eng-keys .ek-bay').first().click();
 await expect(page.locator('.pl-menu .pm-h')).toHaveText(['连接一个订阅','添加一个插件']);
 await expect(calendarKey.locator('.ek-name')).toHaveText('日历');
});

test('host plugin state is validated: a bad message is refused and changes nothing',async({page})=>{
 const {send,receive}=await open(page,dataWith(2),on());
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 for(const plugins of [{version:2,entries:[],settings:{}},{version:1,entries:[{id:'placeholder',enabled:false,pinned:true}],settings:{}},{version:1,entries:[],settings:{},extra:true}])
  expect(await receive(send('plugins',{plugins}))).toBe(false);
 expect(await receive(send('plugins',{plugins:on(),extra:1}))).toBe(false);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
});
