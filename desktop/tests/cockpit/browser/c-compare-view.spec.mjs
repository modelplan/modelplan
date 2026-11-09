// SPDX-License-Identifier: MIT
// Owner build 13 (CKP-MFD, study views.js round D1): trying an effort on a fader shows "Compare · <model>" on the
// MFD: current / try / ★ columns, ability / cost / time rows, the chart, the effort keys, the website links,
// "‹ back" and the fast key. The built page through its normal bridge; synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {readFileSync} from 'node:fs';
import {build13Profile,SESSION_REF} from '../build13-fixture.mjs';
// Cut from the real /v1/client shape (data.speedTiers), the same file the module-level unit test reads.
// The producer's wire tier drops the client-only reviewedAt, so the delivered cut does too.
const speedTiers=JSON.parse(readFileSync(new URL('../unit/client-speed-tiers.fixture.json',import.meta.url),'utf8')).data.speedTiers.map(({reviewedAt,...tier})=>tier);

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,locale='en',tiers=false){
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 const data=build13Profile();
 if(tiers){ // Published ids as /v1/client carries them (the tiers match a model by its published id), plus the tiers.
  const ids={'gpt-6.1-sol':'sol-6.1','gpt-6-astra':'astra-unlisted','gpt-6-luna':'luna','gpt-6.1-terra':'auto:openai:51617927bdb7d656'},fix=m=>({...m,id:ids[m.id]??m.id});
  data.details.publication={...data.details.publication,models:data.details.publication.models.map(fix),speedTiers:structuredClone(speedTiers)};
  data.details.publishedModels=data.details.publishedModels.map(fix);
  for(const x of data.details.sessions)x.model=ids[x.model]??x.model;
  // A second running session, on Terra, so its comparison has a current effort to measure the trial against.
  data.details.sessions.push({...data.details.sessions[0],sessionRef:'00000000000000c2',model:ids['gpt-6.1-terra'],effort:'medium'});
 }
 expect(await receive(send('display',{data}))).toBe(true);
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

// CKP-FAD-11 through the ordinary bridge: the publication carries speedTiers; no session is needed for the key.
test('CKP-FAD-11 fast key: a published speed tier lights the LCD lamp and the Off|On key; no tier keeps it dark; an unstated ratio keeps the key with the time unknown',async({page})=>{
 await open(page,'en',true);
 const fader=name=>page.locator('.fd-ch:not(.empty)').filter({hasText:name}).first();
 const trial=async name=>{const f=fader(name);await f.locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();return f;};
 const back=()=>page.locator('.mfd-vk .vk-back').click();
 const key=page.locator('.mfd-vk button.vk-fast');
 // Overview: a model with a tier shows the fast lamp on its LCD (off until a fast session or trial), one without shows none.
 await expect(fader('Sol').locator('.fd-indicator')).toHaveAttribute('data-fast-mode','off');
 await expect(fader('Astra').locator('.fd-indicator')).not.toHaveAttribute('data-fast-mode',/.*/);
 // Tier with a stated ratio: the key shows Off|On, toggles, and the trial lamp follows.
 const sol=await trial('Sol');
 await expect(key).toHaveCount(1);await expect(key).toContainText(/off/i);await expect(key).toContainText(/on/i);
 await expect(key).toHaveAttribute('aria-pressed','false');
 const before=(await cells(page))[3];
 await key.click();await expect(key).toHaveAttribute('aria-pressed','true');
 await expect(sol.locator('.fd-indicator')).toHaveAttribute('data-fast-mode','try');
 const after=(await cells(page))[3];expect(after).not.toEqual(before);
 await key.click();await expect(key).toHaveAttribute('aria-pressed','false');
 await back();
 // A model the published tiers do not list (Astra here carries an id they do not name) keeps the key dark.
 await trial('Astra');
 await expect(page.locator('.mfd-vk button.vk-fast')).toHaveCount(0);
 await expect(page.locator('.mfd-vk span.vk-fast')).toHaveClass(/off/);
 await back();
 // Unstated ratio (Terra): the key shows, switching it on leaves the time unknown instead of a made-up number.
 await trial('Terra');
 await expect(key).toHaveCount(1);await expect(key).toContainText(/off/i);
 const tBefore=await cells(page);expect(tBefore[3][2]).toBe('×1.50');expect(tBefore[2][2]).toBe('×1.60');
 await key.click();await expect(key).toHaveAttribute('aria-pressed','true');
 const tAfter=await cells(page);expect(tAfter[3][2]).toBe('—');expect(tAfter[2][2]).toBe('×4.00'); // time unknown, cost still the subscription ratio
});

test('CKP-FAD-11 fast key: Chinese key reads 关｜开',async({page})=>{
 await open(page,'zh-CN',true);
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 const key=page.locator('.mfd-vk button.vk-fast');
 await expect(key).toContainText('关');await expect(key).toContainText('开');
});
