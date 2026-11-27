// SPDX-License-Identifier: MIT
// D466 (calendar and time system, owner 2026-11-26; extends DOCK-3.7-05 to every cockpit surface):
// - a quota cell shows only its own facts: no announcement, and "已重置 · 等读数" is gone everywhere;
// - a confirmed banked reset shows as the reserve's blue "+1" and the key's solid blue dot, an announcement as a hollow
//   dot; the alert list bullets them with the same dot and gives other rows no bullet;
// - all of it lives on one news clock: 30 min after the first look (the cockpit open), at most 24 h; the page asks the
//   host for a tick at that moment and drops it then (fake clock, no page timers).
// Built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,27,9,24).getTime(),MIN=60_000,H=36e5,iso=t=>new Date(t).toISOString();
async function open(page,data,locale='zh-CN',{hidden,plugins,news}={}){
 await page.addInitScript(()=>{window.__posts=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__posts.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell,redBelow:25,...(hidden?{hiddenMembers:hidden}:{})}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(plugins)expect(await receive(send('plugins',{plugins}))).toBe(true);
 if(news)expect(await receive(send('news',{items:news}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
// Codex: a banked reset confirmed at 00:29 today, with its event expiry weeks away (the 11-27 screenshots).
function banked(status='confirmed',kind='reset_credit'){
 const data=visualFixture().data,row=data.projection.rows[0];
 const at=new Date(2026,10,27,0,29).getTime();
 data.details.resetEvents=[{version:1,id:'codex-banked-1127',provider:'openai',rowId:row.id,kind,status,publishedAt:iso(at-H),...(status==='confirmed'?{confirmedAt:iso(at)}:{}),expiresAt:iso(at+28*24*H),source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 data.details.subscriptions[0].resetCounts=[{kind:'tokens',count:1,expiresAt:iso(NOW+29*24*H)}];
 // No running session: the next whole minute is then no deadline, so the reported one is the news clock's.
 data.details.sessions=[];
 return data;
}
const key=page=>page.locator('.eng-keys .ek[data-sub]').first(),col=page=>page.locator('.eng-cols .ec[data-col]').first();

test('D466 a confirmed banked reset: solid key dot and reserve +1, never a cell announcement',async({page})=>{
 await open(page,banked());
 await expect(key(page).locator('.ek-news')).toHaveCount(1);await expect(key(page).locator('.ek-news')).toHaveClass(/\bsolid\b/);
 await expect(col(page).locator('.qrow-r .qrv-plus')).toHaveText('+1');
 await expect(col(page).locator('.qrow-r .qrv-c')).toHaveText('重置 1 次');
 // The weekly cell keeps its own reading; no announcement in any cell, no "已重置" anywhere on the page.
 await expect(col(page).locator('.qcell[data-row="second"] .qvalue')).toHaveText('40');
 expect(await page.locator('#cockpit').innerText()).not.toMatch(/已重置|等读数/);
 for(const cell of await page.locator('.qcell .qtxt').all())expect(await cell.getAttribute('data-full')).not.toMatch(/已重置|等读数/);
});
test('D466 the news clock ends 30 min after the look: dot, +1 and alert line go; the page asked for that tick',async({page})=>{
 const {send,receive}=await open(page,banked());
 await page.locator('[data-caution]').click();
 const line=page.locator('.pg-alerts .mfd-alerts.all li.al-blue');
 await expect(line).toHaveCount(1);await expect(line.locator('i.al-dot.solid')).toHaveCount(1);
 const deadline=await page.evaluate(()=>window.__posts.filter(m=>m.type==='nextDeadline').map(m=>m.deadlineUnixMs));
 expect(deadline.at(-1)).toBe(String(NOW+30*MIN));
 expect(await receive(send('tick',{nowUnixMs:String(NOW+29*MIN),reason:'deadline'}))).toBe(true);
 await expect(key(page).locator('.ek-news')).toHaveCount(1);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+30*MIN),reason:'deadline'}))).toBe(true);
 await expect(key(page).locator('.ek-news')).toHaveCount(0);
 await expect(col(page).locator('.qrv-plus')).toHaveCount(0);
 await expect(col(page).locator('.qrow-r .qrv-c')).toHaveText('重置 1 次');
 await expect(page.locator('.pg-alerts .mfd-alerts.all li.al-blue')).toHaveCount(0);
});
test('D466 an announcement is a hollow dot on the key and in the list; other rows carry no bullet',async({page})=>{
 const data=banked('announced','direct_reset');data.projection.rows[1].accounts[0].windows[0].remainingPercent=10;
 await open(page,data);
 await expect(key(page).locator('.ek-news')).toHaveClass(/\bhollow\b/);
 await expect(col(page).locator('.qrv-plus')).toHaveCount(0);
 await page.locator('[data-caution]').click();
 await expect(page.locator('.pg-alerts li.al-blue i.al-dot.hollow')).toHaveCount(1);
 await expect(page.locator('.pg-alerts li.al-red')).toHaveCount(1);
 await expect(page.locator('.pg-alerts li.al-red i.al-dot')).toHaveCount(0);
 expect(await page.locator('.pg-alerts li.al-red .al-row > i').first().innerText()).toBe('');
});
test('D466 unseen news is capped at 24 h after its start even with the cockpit hidden',async({page})=>{
 const data=banked();const confirmedAt=new Date(2026,10,27,0,29).getTime();
 data.details.resetEvents[0].confirmedAt=iso(NOW-24*H-MIN);// confirmed more than 24 h ago
 await open(page,data);
 await expect(key(page).locator('.ek-news')).toHaveCount(0);await expect(col(page).locator('.qrv-plus')).toHaveCount(0);
 expect(confirmedAt).toBeLessThan(NOW);
});

// macrevb-1290-1: news whose only subscription is hidden is drawn nowhere, so no look is recorded and none is posted to
// the host's shared clock; shown again, the dot appears and its clock starts then.
test('macrevb-1290-1 hidden subscription: no look and no newsLook; shown again, the clock starts then',async({page})=>{
 const data=banked();const ref=data.projection.rows[0].accounts[0].subscriptionRef;
 const {send,receive}=await open(page,data,'zh-CN',{hidden:[ref],news:[]});// a host with the shared clock, no answers yet
 const looks=()=>page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='newsLook'));
 await expect(page.locator('.eng-keys .ek[data-sub]')).toHaveCount(3);
 await expect(page.locator('.ek-news')).toHaveCount(0);
 expect(await looks()).toEqual([]);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+40*MIN),reason:'deadline'}))).toBe(true);
 expect(await looks()).toEqual([]);
 // Shown again at 10:04: the news is drawn and its look starts now, so it lasts until 10:34.
 const shown=NOW+40*MIN;await page.clock.setFixedTime(new Date(shown));
 expect(await receive(send('appearance',{...appearance,locale:'zh-CN'}))).toBe(true);
 await expect(key(page).locator('.ek-news.solid')).toHaveCount(1);
 expect((await looks()).map(m=>m.events)).toEqual([[{id:'codex-banked-1127',status:'confirmed'}]]);
 const last=await page.evaluate(()=>window.__posts.filter(m=>m.type==='nextDeadline').at(-1)?.deadlineUnixMs);
 expect(last).toBe(String(shown+30*MIN));
});
// macrevb-1290-2: one clock lookup per event on every surface. At the look deadline the calendar's all-day line, the key
// dot, the reserve +1 and the alert row all go together; the reserve count stays.
test('macrevb-1290-2 the calendar line, key dot, +1 and alert row retire at the same tick',async({page})=>{
 const {send,receive}=await open(page,banked(),'zh-CN',{plugins:{version:1,entries:[{id:'calendar',enabled:true,pinned:false}],settings:{}}});
 const line=page.locator('.pl-col[data-plugin="calendar"] .cal-adr');
 await expect(line).toHaveCount(1);await expect(line).toContainText('+1');
 await expect(key(page).locator('.ek-news')).toHaveCount(1);await expect(col(page).locator('.qrv-plus')).toHaveCount(1);
 await expect(page.locator('.pg-overview .mfd-alerts li.al-blue')).toHaveCount(1);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+30*MIN),reason:'deadline'}))).toBe(true);
 await expect(line).toHaveCount(0);
 await expect(key(page).locator('.ek-news')).toHaveCount(0);await expect(col(page).locator('.qrv-plus')).toHaveCount(0);
 await expect(page.locator('.pg-overview .mfd-alerts li.al-blue')).toHaveCount(0);
 await expect(col(page).locator('.qrow-r .qrv-c')).toHaveText('重置 1 次');
});
