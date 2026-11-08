// SPDX-License-Identifier: MIT
// Owner build 13 (CKP-MFD, study views.js round D1): trying an effort on a fader shows "Compare · <model>" on the
// MFD: current / try / ★ columns, ability / cost / time rows, the chart, the effort keys, the website links,
// "‹ back" and the fast key. The built page through its normal bridge; synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {build13Profile,SESSION_REF} from '../build13-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,locale='en'){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:build13Profile()}))).toBe(true);
}
const sol=page=>page.locator('.fd-ch:not(.empty)').first();
const cells=page=>page.locator('.mfd-page table.cmp').evaluate(t=>[...t.rows].map(r=>[...r.cells].map(c=>c.innerText.trim().replace(/\s+/g,' '))));

test('CKP-MFD compare: a fader trial opens the comparison with three columns, three rows, chart and keys',async({page})=>{
 await open(page);
 await expect(page.locator('.mfd-page')).not.toHaveClass(/pg-compare/);
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
 await expect(screen.locator('.mfd-title')).toHaveText('Compare · Sol 6.1');
 const table=await cells(page);
 expect(table[0]).toEqual(['','Current High','Try XHigh','★ Rec Med']);
 expect(table.slice(1).map(r=>r[0])).toEqual(['Ability','Cost','Time']);
 expect(table[1].slice(1)).toEqual(['±0','+3.2','−3.0']);
 expect(table[2].slice(1)).toEqual(['×1.00','×1.68','×0.66']);
 await expect(screen.locator('svg.cmp-chart .cl')).toHaveCount(3);
 await expect(screen.locator('.cmp-lad .lad')).toHaveText(['Low','★Med','High','XHigh','Max']);
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 expect(await screen.locator('.cmp-lad').evaluate(e=>getComputedStyle(e).paddingLeft)).toBe('36px');
 // The study drops "How it's worked out" when the English header has no room for it; the compare link always shows.
 await expect(screen.locator('.cmp-header-links a').first()).toHaveText('Compare on the website ↗');
 await expect(screen.locator('.cmp-panel[data-light="blue"]')).toHaveCount(4);
 await expect(page.locator('.mfd-ok.mfd-vk .vk-back')).toHaveText('‹ Overview');
 await expect(page.locator('.mfd-ok.mfd-vk .vk-fast')).toHaveCount(1);
 await expect(page.locator('.mfd-pk')).toHaveClass(/dark/);await expect(page.locator('.mfd-pk .pk.on')).toHaveCount(0);
 // The fader shows the trial: blue indicator, ghost cap, "Try XHigh" on its LCD.
 await expect(sol(page).locator('.fd-indicator')).toHaveAttribute('data-state','try');
 await expect(sol(page).locator('.st-try')).toContainText('XHigh');
});

test('CKP-MFD compare: the effort keys move the trial, one trial at a time, and back returns to the page',async({page})=>{
 await open(page);
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await page.locator('.cmp-lad [data-mfd="try:Max"]').click();
 expect((await cells(page))[0][2]).toBe('Try Max');
 // Trying another fader replaces this trial.
 const second=page.locator('.fd-ch:not(.empty)').nth(1);
 await second.locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.mfd-title')).toHaveText('Compare · Astra');
 await expect(page.locator('.fd-indicator[data-state="try"]')).toHaveCount(1);
 await page.locator('.mfd-vk .vk-back').click();
 await expect(page.locator('.mfd-page')).toHaveClass(/pg-overview/);await expect(page.locator('.mfd-pk .pk.on')).toHaveCount(1);
 await expect(page.locator('.fd-indicator[data-state="try"]')).toHaveCount(0);
 // Esc returns too, and pressing the LCD again toggles the card.
 await sol(page).locator('.fd-strip').click();await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
 await page.keyboard.press('Escape');await expect(page.locator('.mfd-page')).toHaveClass(/pg-overview/);
 await sol(page).locator('.fd-strip').click();await sol(page).locator('.fd-strip').click();
 await expect(page.locator('.mfd-page')).toHaveClass(/pg-overview/);
});

test('CKP-MFD compare: Chinese labels match the study',async({page})=>{
 await open(page,'zh-CN');
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.mfd-title')).toHaveText('比较 · Sol 6.1');
 await expect(page.locator('.cmp-header-links a')).toHaveText(['在网站上对比 ↗','怎么算的 ↗']);
 await expect(page.locator('.mfd-vk .vk-back')).toHaveText('‹ 返回 总览');
});

test('CKP-MFD compare: the back key is named "Back …" for assistive tech, and a HUD row opens the Effort page instead',async({page})=>{
 await open(page);
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.mfd-vk .vk-back')).toHaveAttribute('aria-label',/^Back /);
 await page.locator('.hud-list .hp').first().click();
 await expect(page.locator('.mfd-page')).toHaveClass(/pg-tune/);
 await expect(page.locator('.fd-indicator[data-state="try"]')).toHaveCount(0);
 // A page key closes the view the HUD opened (study closeMfdView('page')): no stale "‹ back" line on the next page.
 await page.locator('[data-mfd="page:overview"]').click();
 await expect(page.locator('.mfd-page .mfd-back')).toHaveCount(0);
});

test('CKP-MFD compare: the title stays whole when the current effort is unknown',async({page})=>{
 await open(page);
 const astra=page.locator('.fd-ch:not(.empty)').nth(1);await astra.locator('.fd-strip').click();
 const title=page.locator('.mfd-title');await expect(title).toHaveText('Compare · Astra');
 expect(await title.evaluate(e=>e.scrollWidth<=e.clientWidth+.5)).toBe(true);
});

test('CKP-FAD-10 CKP-MFD-21: a record-line click closes the comparison and the trial, and shows the session view',async({page})=>{
 await open(page);
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
 await expect(page.locator('.fd-indicator[data-state="try"]')).toHaveCount(1);
 await page.locator(`.ck-tape .t-observed[data-session="${SESSION_REF}"]`).click();
 await expect(page.locator('.mfd-page.pg-compare')).toHaveCount(0);
 await expect(page.locator('.mfd-page.pg-where .ws-list .ws').first()).toBeVisible();
 await expect(page.locator('.fd-indicator[data-state="try"]')).toHaveCount(0);
});
