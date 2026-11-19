// SPDX-License-Identifier: MIT
// WP-11 (V1-FINAL §4, §8.6, §11, §12): the alert list the ALERT lamp opens, on the built page through its normal bridge,
// synthetic data only.
// - ALR-50: every red, amber and unreadable row is the shared sentence (tests/shared/alert-sentences.json), the same
//   words on the overview line and in the list.
// - ALR-51: red and amber light the lamp; blue and grey are list-only. A stale reading is grey, never blue.
// - CKP-MFD-55: title "提醒 · N"; two lines per row; red, amber, blue, grey, tightest first; "没有提醒" when empty.
// - CKP-MFD-56: a row selects its subscription and returns; a grey row opens Settings › Subscriptions; Esc, the back
//   key or a second lamp press return to the page the list came from.
// - CKP-MFD-57: opening the list acknowledges: no blink, the lamp stays lit.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=Date.parse('2026-11-18T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString().replace('.000Z','Z');
async function open(page,data,locale='en'){
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(typeof raw==='string'?JSON.parse(raw):raw);}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const actions=page=>page.evaluate(()=>window.sent.filter(m=>m.type==='action'));
/** Rows: Codex, Claude Code, Cursor, Gemini CLI. Every window comfortable unless a scenario says otherwise. */
function calm(){
 const data=visualFixture().data;
 for(const row of data.projection.rows)for(const w of row.accounts[0].windows){w.remainingPercent=90;w.resetsAt=iso(600);}
 data.details.forecasts=[];data.details.resetEvents=[];
 return data;
}
const win=(data,i,j=0)=>data.projection.rows[i].accounts[0].windows[j];
function busy(){
 const data=calm();
 win(data,0).remainingPercent=20;win(data,0).resetsAt=iso(210);                        // red: Codex 5h 20%
 win(data,1).remainingPercent=10;win(data,1).resetsAt=iso(60);                         // red, tighter: Claude Code 5h 10%
 const g=data.projection.rows[3],ga=g.accounts[0];win(data,3).remainingPercent=60;win(data,3).resetsAt=iso(300);
 data.details.forecasts=[{source:g.id,subscriptionRef:ga.subscriptionRef,windowId:ga.windows[0].id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-2)}];
 data.details.resetEvents=[{version:1,id:'synthetic-reset',provider:'openai',rowId:data.projection.rows[0].id,status:'confirmed',publishedAt:iso(-60),expiresAt:iso(600),source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const c=data.projection.rows[2].accounts[0];c.valueState='none';c.windows=[];c.lastFailure={at:iso(-1),code:'not_signed_in'};
 return data;
}
const lamp=page=>page.locator('[data-caution]');
const rows=page=>page.locator('.pg-alerts .mfd-alerts.all > li');

test('CKP-MFD-55 / ALR-50 / ALR-51 the list: title, order, two lines, the shared sentence',async({page})=>{
 await open(page,busy());
 await expect(lamp(page)).toHaveClass(/\bred\b/);
 await expect(page.locator('.ec.tint-red')).not.toHaveCount(0);await expect(page.locator('.ec.tint-amber')).not.toHaveCount(0);
 // ALR-50: the overview line is the same sentence as the list row.
 await expect(page.locator('.pg-overview .mfd-alerts li').first()).toContainText('Claude Code 5h 10% · resets in 1h00');
 await lamp(page).click();
 await expect(page.locator('.pg-alerts .al-head')).toHaveText('Alerts · 5');
 await expect(rows(page)).toHaveCount(5);
 expect(await rows(page).evaluateAll(li=>li.map(x=>x.className.split(' ')[0]))).toEqual(['al-red','al-red','al-amber','al-blue','al-grey']);
 await expect(rows(page).nth(0).locator('.al-l1')).toHaveText('Claude Code 5h 10% · resets in 1h00');
 await expect(rows(page).nth(1).locator('.al-l1')).toHaveText('Codex 5h 20% · resets in 3h30');
 await expect(rows(page).nth(2).locator('.al-l1')).toHaveText('Gemini CLI 5h 60% · out ~40m · resets in 5h00');
 await expect(rows(page).nth(4).locator('.al-l1')).toHaveText('Cursor no reading · not signed in');
 await expect(rows(page).nth(4).locator('.al-l2')).toHaveText('Open Settings ›');
});

test('CKP-MFD-55 the Chinese list uses the same words as the shared table',async({page})=>{
 await open(page,busy(),'zh-CN');
 await lamp(page).click();
 await expect(page.locator('.pg-alerts .al-head')).toHaveText('提醒 · 5');
 await expect(rows(page).nth(0).locator('.al-l1')).toHaveText('Claude Code 5小时 10% · 1h00 后重置');
 await expect(rows(page).nth(2).locator('.al-l1')).toHaveText('Gemini CLI 5小时 60% · 约40m用完 · 5h00 后重置');
 await expect(rows(page).nth(4).locator('.al-l1')).toHaveText('Cursor 读不到 · 未登录');
 await expect(rows(page).nth(4).locator('.al-l2')).toHaveText('去设置 ›');
});

test('CKP-MFD-55 an unlit lamp still opens the list; with nothing to show it says so',async({page})=>{
 await open(page,calm());
 await expect(lamp(page)).not.toHaveClass(/\blit\b/);
 await lamp(page).click();
 await expect(page.locator('.pg-alerts .al-head')).toHaveText('Alerts · 0');
 await expect(page.locator('.pg-alerts .mfd-alerts.all li.al-none')).toHaveText('No alerts');
 await lamp(page).click();
 await expect(page.locator('.pg-alerts')).toHaveCount(0);
});

test('ALR-51 grey and stale rows never light the lamp or wash a column',async({page})=>{
 const data=calm(),c=data.projection.rows[2].accounts[0];c.valueState='none';c.windows=[];c.lastFailure={at:iso(-1),code:'timeout'};
 const s=data.projection.rows[1].accounts[0];s.valueState='retained';s.observedAt=iso(-120);
 await open(page,data);
 await expect(lamp(page)).not.toHaveClass(/\b(lit|red|amber)\b/);
 await expect(page.locator('.ec[data-col]')).not.toHaveCount(0);
 await expect(page.locator('.ec.tint-red,.ec.tint-amber')).toHaveCount(0);
 await lamp(page).click();
 await expect(page.locator('.pg-alerts .mfd-alerts.all li.al-blue')).toHaveCount(0);
 await expect(page.locator('.pg-alerts .mfd-alerts.all li.al-grey')).toHaveCount(2);
});

test('CKP-MFD-56 a row selects its subscription and returns; a grey row opens Settings › Subscriptions',async({page})=>{
 const data=busy();await open(page,data);
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 await lamp(page).click();
 await rows(page).nth(4).locator('button').click();
 expect((await actions(page)).at(-1)).toMatchObject({action:'openSettingsSubscriptions'});
 await expect(page.locator('.pg-alerts')).toBeVisible();
 await rows(page).nth(1).locator('button').click();
 expect((await actions(page)).at(-1)).toMatchObject({action:'scopeSelect',key:data.projection.rows[0].accounts[0].subscriptionRef});
 await expect(page.locator('.pg-alerts')).toHaveCount(0);
 await expect(page.getByRole('button',{name:'Subscription',exact:true})).toHaveAttribute('aria-pressed','true');
});

test('CKP-MFD-56 Esc, the back key and a second lamp press each return to the page the list came from',async({page})=>{
 await open(page,busy());
 await page.getByRole('button',{name:'Subscription',exact:true}).click();
 for(const close of [()=>page.keyboard.press('Escape'),()=>page.locator('.pg-alerts [data-mfd="back"]').click(),()=>lamp(page).click()]){
  await lamp(page).click();await expect(page.locator('.pg-alerts')).toBeVisible();
  await close();
  await expect(page.locator('.pg-alerts')).toHaveCount(0);
  await expect(page.getByRole('button',{name:'Subscription',exact:true})).toHaveAttribute('aria-pressed','true');
 }
});

test('CKP-MFD-57 opening the list acknowledges: the lamp stops blinking and stays lit',async({page})=>{
 const data=calm(),{send,receive}=await open(page,data);
 win(data,0).remainingPercent=60;win(data,0).resetsAt=iso(300);
 const r=data.projection.rows[0],a=r.accounts[0];
 data.details.forecasts=[{source:r.id,subscriptionRef:a.subscriptionRef,windowId:a.windows[0].id,runsOutAt:iso(40),pace:'tight',basis:'recent-rate',observedAt:iso(-2)}];
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp(page)).toHaveClass(/\bflash\b/);
 await lamp(page).click();
 await expect(lamp(page)).not.toHaveClass(/\bflash\b/);await expect(lamp(page)).toHaveClass(/\bamber\b/);
 await page.keyboard.press('Escape');
 // The same problem with drifting numbers does not blink again; escalation to red does.
 win(data,0).remainingPercent=55;expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp(page)).not.toHaveClass(/\bflash\b/);
 win(data,0).remainingPercent=20;expect(await receive(send('display',{data}))).toBe(true);
 await expect(lamp(page)).toHaveClass(/\bflash\b/);await expect(lamp(page)).toHaveClass(/\bred\b/);
});

// macrev2 11-19 finding 1: the producer drops the Dock surface from a signed-out or unreadable tool row (cli/internal/rows
// build.go), so the row is not a cockpit member; its grey line still reaches the alert list. A row with no surface stays hidden.
test('ALR-51 / CKP-MFD-56 a signed-out row the producer kept off the Dock still gets its grey list row, and no tab or column',async({page})=>{
 const data=calm(),row=data.projection.rows[2],hidden=data.projection.rows[3];
 row.surfaces=['menu','settings'];row.state='needs_action';row.reason={...row.reason,code:'not_signed_in'};
 const c=row.accounts[0];c.valueState='none';c.windows=[];c.lastFailure={at:iso(-1),code:'not_signed_in'};
 hidden.surfaces=[];const h=hidden.accounts[0];h.valueState='none';h.windows=[];h.lastFailure={at:iso(-1),code:'not_signed_in'};
 await open(page,data);
 await expect(page.locator('.ec[data-col]')).toHaveCount(2);
 await lamp(page).click();
 await expect(page.locator('.pg-alerts .al-head')).toHaveText('Alerts · 1');
 await expect(rows(page).nth(0).locator('.al-l1')).toHaveText('Cursor no reading · not signed in');
 await expect(rows(page).nth(0).locator('.al-l2')).toHaveText('Open Settings ›');
 await rows(page).nth(0).click();
 expect((await actions(page)).map(a=>a.action)).toContain('openSettingsSubscriptions');
});

// macrev2 11-19 finding 3: a partial or truncated card list never shows an exact count.
test('CKP-MFD-55 a partial reset-card list says resets are available without a count',async({page})=>{
 const data=busy(),detail=data.details.subscriptions[0];
 detail.resetCards={state:'partial',count:2,truncated:false,sources:[{observedAt:iso(-5),source:'saved_login'}],items:[{id:'1'.padStart(64,'0'),expiresAt:iso(60*30)}]};
 await open(page,data);await lamp(page).click();
 const text=await rows(page).locator('.al-l2').allTextContents();
 expect(text.join('|')).toContain('Resets available');
 expect(text.join('|')).not.toMatch(/\b1 reset available\b/);
});

// macrev2 11-19 finding 4: a refresh that re-sorts the list keeps keyboard focus on the same alert, never on another subscription.
test('CKP-MFD-56 a refresh that re-sorts the list keeps focus on the same alert, or drops it',async({page})=>{
 const data=calm();win(data,0).remainingPercent=15;win(data,1).remainingPercent=22;
 const {send,receive}=await open(page,data);await lamp(page).click();
 await expect(rows(page).nth(1).locator('.al-l1')).toContainText('Claude Code');
 await rows(page).nth(1).locator('button').focus();
 win(data,1).remainingPercent=10;expect(await receive(send('display',{data}))).toBe(true);
 await expect(rows(page).nth(0).locator('.al-l1')).toContainText('Claude Code');
 expect(await page.evaluate(()=>document.activeElement?.closest('li')?.textContent??'')).toContain('Claude Code');
 win(data,1).remainingPercent=90;expect(await receive(send('display',{data}))).toBe(true);
 expect(await page.evaluate(()=>document.activeElement?.closest('li')?.textContent??'')).not.toContain('Codex');
});
