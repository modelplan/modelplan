// SPDX-License-Identifier: MIT
// WP-21 lane B, spec 3: which subscriptions the cockpit shows. CKP-SHELL-36: the cockpit shows exactly the widget's members
// (rows with the "dock" surface), in the widget's saved order, minus the ones Settings hides. CKP-SHELL-37: with no widget
// member the record strip and the faders still show. G3-63 / G3-64: the cockpit's models are the members' own models.
// On the built page through its normal bridge, synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,data){
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// Every row of the fixture is a widget member; `fewer` keeps the first n rows.
function fixture(rows=3){
 const {data}=visualFixture();
 data.projection.rows=data.projection.rows.slice(0,rows);
 const keep=new Set(data.projection.rows.flatMap(r=>r.accounts.map(a=>a.subscriptionRef)).filter(Boolean));
 data.subscriptions=data.subscriptions.filter(s=>keep.has(s.subscriptionRef));
 for(const r of data.projection.rows)r.surfaces=['dock','menu','settings'];
 return data;
}
const keys=page=>page.locator('.eng-keys .ek[data-sub]');
const memberKeys=page=>keys(page).evaluateAll(es=>es.map(e=>e.dataset.scope));
const columns=page=>page.locator('.eng-cols .ec[data-col]:not(.pl-col)');
const lit=page=>page.evaluate(()=>[...document.querySelectorAll('.eng-keys .ek[data-sub]')].filter(k=>k.getAttribute('aria-pressed')==='true'||k.classList.contains('on')).map(k=>k.dataset.scope));

test('CKP-SHELL-36 the cockpit shows one key and one column per widget member, and none for a row without the dock surface',async({page})=>{
 const data=fixture(3),menuOnly=structuredClone(data.projection.rows[0]);
 menuOnly.id='synthetic-menu-only';menuOnly.name={en:'Menu only',zh:'仅菜单'};menuOnly.surfaces=['menu','settings'];menuOnly.accounts.forEach(a=>{a.subscriptionRef=null;a.accountLocator=null;});
 data.projection.rows.push(menuOnly);
 const {send,receive}=await open(page,data);
 const members=data.projection.rows.filter(r=>r.surfaces.includes('dock')).reduce((n,r)=>n+r.accounts.length,0);
 await expect(keys(page)).toHaveCount(members);await expect(columns(page)).toHaveCount(members);
 await expect(page.locator('.eng-keys')).not.toContainText('Menu only');
 await expect(page.locator('.hud')).not.toContainText('Menu only');
 // The widget gaining the dock surface for that row adds exactly one member; the next delivery shows it.
 const next=structuredClone(data);next.projection.rows.at(-1).surfaces=['dock','menu','settings'];
 expect(await receive(send('display',{data:next}))).toBe(true);
 await expect(keys(page)).toHaveCount(members+next.projection.rows.at(-1).accounts.length);
});

test('CKP-SHELL-36 the saved widget order is the cockpit order; unnamed members follow in the emitted order; unknown keys are ignored',async({page})=>{
 const {send,receive}=await open(page,fixture(3));
 const emitted=await memberKeys(page);expect(emitted.length).toBe(3);
 const reversed=[...emitted].reverse();
 expect(await receive(send('appearance',{...appearance,memberOrder:reversed}))).toBe(true);
 await expect.poll(()=>memberKeys(page)).toEqual(reversed);
 // The number keys follow the shown order, not the emitted one.
 await page.keyboard.press('1');await expect.poll(()=>lit(page)).toEqual([reversed[0]]);
 // Naming only the last emitted member moves it first; the others keep their emitted order after it.
 expect(await receive(send('appearance',{...appearance,memberOrder:[emitted[2],'not-a-member']}))).toBe(true);
 await expect.poll(()=>memberKeys(page)).toEqual([emitted[2],emitted[0],emitted[1]]);
 // No saved order: back to the emitted order.
 expect(await receive(send('appearance',{...appearance,memberOrder:[]}))).toBe(true);
 await expect.poll(()=>memberKeys(page)).toEqual(emitted);
});

test('CKP-SHELL-36 a member hidden in Settings loses its key and column, the number keys skip it, and it returns in its own place',async({page})=>{
 const {send,receive}=await open(page,fixture(3));
 const emitted=await memberKeys(page);
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[emitted[0]]}))).toBe(true);
 await expect.poll(()=>memberKeys(page)).toEqual([emitted[1],emitted[2]]);
 await expect(columns(page)).toHaveCount(2);
 await page.keyboard.press('1');await expect.poll(()=>lit(page)).toEqual([emitted[1]]);
 // Hiding the selected member returns the cockpit to All.
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[emitted[0],emitted[1]]}))).toBe(true);
 await expect(page.locator('#cockpit')).toHaveAttribute('data-scope','all');
 await expect.poll(()=>memberKeys(page)).toEqual([emitted[2]]);
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[]}))).toBe(true);
 await expect.poll(()=>memberKeys(page)).toEqual(emitted);
});

test('CKP-SHELL-37 with no widget member the record strip and the faders are still shown, with the empty-engine line',async({page})=>{
 const data=fixture(2);
 for(const r of data.projection.rows)r.surfaces=['menu','settings'];
 await open(page,data);
 await expect(keys(page)).toHaveCount(0);
 await expect(page.locator('.ck-eng .ec-empty')).toHaveCount(1);
 for(const sel of ['.ck-tape','.dk-mfd .fd-chs','.hud','.ck-head [data-settings]'])await expect(page.locator(sel),sel).toBeVisible();
 // The faders keep their channels (empty bays), never collapse.
 expect(await page.locator('.dk-mfd .fd-ch').count()).toBeGreaterThan(0);
});

test('CKP-SHELL-37 G3-63 G3-64 every member hidden in Settings leaves the strip and the faders; a member showing again fills them',async({page})=>{
 const data=fixture(2),{send,receive}=await open(page,data);
 const emitted=await memberKeys(page);
 expect(await receive(send('appearance',{...appearance,hiddenMembers:emitted}))).toBe(true);
 await expect(keys(page)).toHaveCount(0);
 for(const sel of ['.ck-tape','.dk-mfd .fd-chs'])await expect(page.locator(sel),sel).toBeVisible();
 await expect(page.locator('.dk-mfd .fd-ch:not(.empty)'),'a hidden member brings no model fader').toHaveCount(0);
 expect(await receive(send('appearance',{...appearance,hiddenMembers:[emitted[1]]}))).toBe(true);
 await expect(keys(page)).toHaveCount(1);
 expect(await page.locator('.dk-mfd .fd-ch:not(.empty)').count()).toBeGreaterThan(0);
});
