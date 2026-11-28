// SPDX-License-Identifier: MIT
// Calendar plugin after D466: the calendar is the big screen's fixed 日历 page (calendar-page.ts). The plugin stays
// registered (saved states, the Settings mirror) but is page-only: no column, no key, no "+" menu entry; a host request
// to open its screen opens the 日历 page. The old 12 h column strip and plugin week screen (D328, D406, CKP-PLG-07,
// G3-179) are gone with it; the D466 specs cover the strip and the page. Times are local (America/Los_Angeles here).
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.use({timezoneId:'America/Los_Angeles'});
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// Pacific standard time in November 2026: local = UTC-8. Day 0 = Wednesday 11/11; now = 11:20.
const L=(day,h,m=0)=>Date.UTC(2026,10,11+day,h+8,m);
const NOW=L(0,11,20);
// The resource plugin (D324) is also default on; it is kept off here so only the calendar is in play.
const calendarOn={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:false,pinned:false}],settings:{}};
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
async function open(page,{data=dataWith(2),plugins=calendarOn}={}) {
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(plugins)expect(await receive(send('plugins',{plugins}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}

test('D466 the enabled calendar takes no column, no key and no "+" menu entry; a host screen request opens the 日历 page',async({page})=>{
 const {send,receive}=await open(page);
 await expect(page.locator('.eng-cols .pl-col[data-plugin="calendar"]')).toHaveCount(0);
 await expect(page.locator('.eng-keys .pl-key[data-plugin="calendar"]')).toHaveCount(0);
 await page.locator('[data-add-subscription]').first().click();
 await expect(page.locator('.pl-menu')).toHaveCount(1);
 await expect(page.locator('.pl-menu [data-pm-plugin="calendar"]')).toHaveCount(0);
 await page.keyboard.press('Escape');
 // The widget card's "Cockpit screen ›" for the calendar now lands on the fixed page, with no Overview switch.
 expect(await receive(send('pluginScreen',{id:'calendar'}))).toBe(true);
 await expect(page.locator('.mfd-pk .pk[data-mfd="page:calendar"]')).toHaveClass(/\bon\b/);
 await expect(page.locator('.mfd-page.pg-calendar .cal-page')).toHaveCount(1);
 await expect(page.locator('.mfd-pk .pk-seg')).toBeHidden();
 await expect(page.locator('.pl-screen[data-plugin="calendar"]')).toHaveCount(0);
});

test('an older host (no plugin state) still shows the v1 table: default-on plugins wait for the host',async({page})=>{
 await open(page,{plugins:null});
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','3');
});
