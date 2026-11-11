// SPDX-License-Identifier: MIT
// v1.1 cockpit plugin framework (owner D121, D124, D126, D127): plugin columns in the engine table, the empty-slot
// "+" menu, pin to page 1, and the start/stop lifecycle (only while the cockpit is open and the column is shown).
// Uses the framework's placeholder plugin; the real plugins bring their own specs.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// The calendar plugin is default-on (D121); these framework specs keep it off so only the placeholder is laid out.
const calendarOff={id:'calendar',enabled:false,pinned:false};
const on=(pinned=false,settings={})=>({version:1,entries:[{id:'placeholder',enabled:true,pinned},calendarOff],settings:{placeholder:settings}});
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
const panel=page=>page.locator('.eng-cols .pl-col[data-plugin="placeholder"] .pl-panel');

test('D124 layout rule: columns = max(3, subscriptions + plugins), at most 6, plugins after subscriptions',async({page})=>{
 const {send,receive}=await open(page,dataWith(1),on());
 // [subscriptions, slots with the plugin, plugin shown]
 for(const [count,slots,shown] of [[1,3,true],[2,3,true],[3,4,true],[4,5,true],[5,6,true],[6,6,false]]){
  expect(await receive(send('display',{data:dataWith(count)}))).toBe(true);
  await expect(page.locator('.eng-keys'),`${count} subscriptions`).toHaveAttribute('data-slots',String(slots));
  await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(count);
  await expect(page.locator('.eng-keys .pl-key')).toHaveCount(shown?1:0);
  await expect(page.locator('.eng-cols .pl-col')).toHaveCount(shown?1:0);
  await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(slots-count-(shown?1:0));
  if(shown){
   // The plugin column follows the last subscription and carries the double seam; its key has no vendor strip or digit.
   expect(await page.evaluate(()=>{const cols=[...document.querySelectorAll('.eng-cols > *')];const i=cols.findIndex(c=>c.classList.contains('pl-col'));return cols.slice(0,i).every(c=>c.matches('.ec[data-col]'))&&cols.slice(i+1).every(c=>c.matches('.ec-bay'));})).toBe(true);
   await expect(page.locator('.eng-cols .pl-col')).toHaveClass(/pl-first/);
   await expect(page.locator('.eng-keys .pl-key .bl, .eng-keys .pl-key .ki')).toHaveCount(0);
   await expect(page.locator('.eng-keys .pl-key .pl-icon svg')).toHaveCount(1);
   await expect(page.locator('.eng-keys .pl-key .ek-name')).toHaveText('Placeholder');
   await expect(page.getByRole('button',{name:'Remove Placeholder'})).toBeVisible();
  }
 }
 // Off (no host state or turned off): the v1 table, with "+" on the empty slots.
 expect(await receive(send('plugins',{plugins:{version:1,entries:[calendarOff],settings:{}}}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(2)}))).toBe(true);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','3');
 await expect(page.locator('.eng-keys .ek-bay')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
});

test('pin keeps the plugin on page 1 even with many subscriptions; unpinned plugins only fill free slots',async({page})=>{
 const {send,receive}=await open(page,dataWith(6),on(false));
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 expect(await receive(send('plugins',{plugins:on(true)}))).toBe(true);
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(5);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 await page.getByRole('button',{name:'Page 2'}).click();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 // Seven subscriptions, unpinned: the plugin takes a free slot on the last page.
 expect(await receive(send('plugins',{plugins:on(false)}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(7)}))).toBe(true);
 await page.getByRole('button',{name:'Page 1'}).click();
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 await page.getByRole('button',{name:'Page 2'}).click();
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(1);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 // A shortcut digit still selects subscriptions only.
 await page.keyboard.press('1');
 await expect(page.locator('.eng-keys .ek[data-sub]').first()).toHaveAttribute('aria-pressed','true');
});

test('lifecycle: the plugin runs only while the cockpit is open and its column is on the shown page',async({page})=>{
 const {send,receive}=await open(page,dataWith(7),on(false,{intervalSeconds:5}));
 const reading=value=>send('pluginData',{id:'placeholder',data:{value}});
 // Page 1 has no room: not shown, never started, and host readings are refused.
 await expect(panel(page)).toHaveCount(0);
 expect(await receive(reading(1))).toBe(false);
 await page.getByRole('button',{name:'Page 2'}).click();
 await expect(panel(page)).toHaveAttribute('data-running','true');
 expect(await receive(reading(7))).toBe(true);
 await expect(panel(page)).toHaveAttribute('data-value','7');
 expect(await receive(send('pluginData',{id:'placeholder',data:{value:'x'}}))).toBe(false);
 expect(await receive(send('pluginData',{id:'unknown',data:{value:1}}))).toBe(false);
 // Occluded: stopped, readings refused; the same panel keeps its value and resumes when visible again.
 expect(await receive(send('visibility',{visible:true,occluded:true,key:false}))).toBe(true);
 await expect(panel(page)).toHaveAttribute('data-running','false');
 expect(await receive(reading(8))).toBe(false);
 // Visible but not key still counts as open.
 expect(await receive(send('visibility',{visible:true,occluded:false,key:false}))).toBe(true);
 await expect(panel(page)).toHaveAttribute('data-running','true');
 // A repaint (new reading) keeps the same panel and its history.
 expect(await receive(send('display',{data:dataWith(7)}))).toBe(true);
 await expect(panel(page)).toHaveAttribute('data-value','7');
 await expect(panel(page)).toHaveAttribute('data-running','true');
 // Page away: stopped.
 await page.getByRole('button',{name:'Page 1'}).click();
 await expect(page.locator('.pl-panel')).toHaveCount(0);
 expect(await receive(reading(9))).toBe(false);
 await page.getByRole('button',{name:'Page 2'}).click();
 await expect(panel(page)).toHaveAttribute('data-value','7');
 // A settings change from the host redraws the panel.
 expect(await receive(send('plugins',{plugins:on(false,{intervalSeconds:3})}))).toBe(true);
 await expect(panel(page).locator('.pp-h em')).toHaveText('3 s');
 // Removed with ×: stopped, the column turns back into a "+" slot and the host gets the edit.
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 await page.getByRole('button',{name:'Remove Placeholder'}).click();
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 expect(await pluginEdits(page)).toEqual([{version:1,entries:[{id:'placeholder',enabled:false,pinned:false},calendarOff],settings:{placeholder:{intervalSeconds:3}}}]);
 // Cleared readings stop everything.
 expect(await receive(send('plugins',{plugins:on(false)}))).toBe(true);
 await expect(panel(page)).toHaveAttribute('data-running','true');
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
 await expect(page.locator('.pl-panel')).toHaveCount(0);
 // The host samples exactly what the page reports as running, on every change and never more.
 expect(await running(page)).toEqual([[],['placeholder'],[],['placeholder'],[],['placeholder'],[],['placeholder'],[]]);
});

test('"+" menu: detected tools first, then all subscriptions; plugins below; Add places the plugin',async({page})=>{
 const {send,receive}=await open(page,dataWith(1,[['grok','off'],['gemini-cli','needs_consent']]));
 const plus=page.locator('.eng-keys .ek-bay').first();
 await expect(plus).toHaveAttribute('aria-label','＋ Add a subscription');
 await plus.click();
 const menu=page.getByRole('menu',{name:'Add to the engine table'});await expect(menu).toBeVisible();
 await expect(menu.locator('.pm-h')).toHaveText(['Connect a subscription','Add a plugin']);
 await expect(menu.locator('.pm-connect .pm-n')).toHaveText(['gemini-cli','grok']);
 await expect(menu.locator('.pm-connect em')).toHaveText(['Detected','Not connected']);
 await expect(menu.locator('[data-pm-all]')).toHaveText('All subscriptions…');
 await expect(menu.locator('[data-pm-plugin="placeholder"]')).toContainText('Add');
 // Escape closes and returns focus; a connect item asks the host for Settings, as the empty slot did before.
 await page.keyboard.press('Escape');await expect(menu).toHaveCount(0);await expect(plus).toBeFocused();
 await plus.click();await menu.locator('[data-pm-row="gemini-cli"]').click();
 expect(await page.evaluate(()=>window.__events.filter(e=>e.type==='action').map(e=>e.action))).toEqual(['openSettings']);
 await plus.click();await menu.locator('[data-pm-plugin="placeholder"]').click();
 await expect(menu).toHaveCount(0);
 await expect(page.locator('.eng-cols .pl-col[data-plugin="placeholder"]')).toHaveCount(1);
 await expect(panel(page)).toHaveAttribute('data-running','true');
 // This host never sent plugin state, so the page keeps the edit to itself (an older host would reject the action).
 expect(await pluginEdits(page)).toEqual([]);expect(await running(page)).toEqual([]);
 await page.locator('.eng-keys .ek-bay').first().click();
 await expect(menu.locator('[data-pm-plugin="placeholder"]')).toBeDisabled();
 await expect(menu.locator('[data-pm-plugin="placeholder"]')).toContainText('✓ Added');
 // Chinese labels.
 await page.keyboard.press('Escape');
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN',redBelow:25}))).toBe(true);
 await page.locator('.eng-keys .ek-bay').first().click();
 await expect(page.locator('.pl-menu .pm-h')).toHaveText(['连接订阅','添加插件']);
 await expect(page.locator('.eng-keys .pl-key .ek-name')).toHaveText('占位插件');
});

test('host plugin state is validated: a bad message is refused and changes nothing',async({page})=>{
 const {send,receive}=await open(page,dataWith(2),on());
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
 for(const plugins of [{version:2,entries:[],settings:{}},{version:1,entries:[{id:'placeholder',enabled:false,pinned:true}],settings:{}},{version:1,entries:[],settings:{},extra:true}])
  expect(await receive(send('plugins',{plugins}))).toBe(false);
 expect(await receive(send('plugins',{plugins:on(),extra:1}))).toBe(false);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(1);
});
