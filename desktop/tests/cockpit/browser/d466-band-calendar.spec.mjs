// SPDX-License-Identifier: MIT
// D466 (D464): the subscription band and the big screen's 日历 tab of the owner-approved calendar/time system
// (calendar-system.md, band round 3):
// - no 日历 key or Calendar column, even with the calendar plugin on; keys show the short name ("ZCode", not "ZCode / GLM
//   Synthetic plan"), with the tier only when two keys share it;
// - the range row leads with tokens (the big figure), then ≈cost, then speed (D464);
// - every subscription column has a 24 h strip at its right edge (6 pt bar, ≥ 12 pt hit area): now bar, peak block, reset
//   tick; its hover card opens to the left with "接下来" lines and "7 天日历 ›"; a click opens the 日历 tab filtered to that
//   subscription ("只看 X ✕");
// - 日历 is the fixed 5th page key; 今天 / 7天 / 30天 pick the agenda, the week grid with the day's word list, and the dated
//   list; a multi-day item is one chip, never a bar; the five keys and the Resources switch fit in en and zh.
// Built page through its normal bridge; synthetic data only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const local=(d,h,m=0)=>new Date(2026,10,d,h,m).getTime(),NOW=local(27,9,40),H=36e5,iso=t=>new Date(t).toISOString();
const PLUGINS={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
const GB=1024**3,reading=t=>({t,cpuUser:19,cpuSystem:3,load:2.4,memTotal:32*GB,memApp:Math.round(9.2*GB),memWired:Math.round(4.5*GB),memCompressed:Math.round(1.4*GB),memCached:Math.round(12.8*GB),memFree:Math.round(4.1*GB),swapUsed:0,pressure:'normal',diskTotal:494*GB,diskFree:120*GB,netIn:1_200_000,netOut:86_000});
// Codex (no time rules, weekly reset Tue 05:42, a reserve expiring in two days) and ZCode / GLM (5 h reset 13:04, the
// 22:00–02:00 peak), as in the 11-27 screenshots.
function band(){
 const data=visualFixture().data,rows=data.projection.rows;
 const z=rows[1];z.id='zai';z.name={en:'ZCode / GLM',zh:'ZCode / GLM'};z.vendorKey='glm';
 data.projection.rows=[rows[0],z];data.subscriptions=data.subscriptions.slice(0,2);data.details.subscriptions=data.details.subscriptions.slice(0,2);
 for(const row of data.projection.rows)for(const w of row.accounts[0].windows)w.resetsAt=null;
 rows[0].accounts[0].windows[1].resetsAt=iso(local(31,5,42)+24*H);
 z.accounts[0].windows[0].resetsAt=iso(local(27,13,4));
 data.details.sessions=[];
 data.details.peaks=[{rowId:'zai',startsAt:iso(local(27,22)),endsAt:iso(local(28,2)),status:'confirmed'}];
 data.details.subscriptions[0].today=[{source:'codex',observedOutputTokens:5.6e6,generationTps:56,bindingBasis:'source-wide-current-binding'}];
 data.details.subscriptions[0].resetCounts=[{kind:'tokens',count:1,expiresAt:iso(NOW+50*H)}];
 data.details.subscriptions[0].resetCards={state:'complete',count:1,truncated:false,sources:[],items:[{id:'1'.padStart(64,'0'),expiresAt:iso(NOW+50*H).replace('.000Z','Z')}]};
 return data;
}
async function open(page,{locale='zh-CN',data=band(),range}={}){
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.__posts=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__posts.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,...(range?{range}:{})},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:PLUGINS}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive,data};
}
const cols=page=>page.locator('.eng-cols > .ec[data-col]:not(.pl-col)');

test('D466 no 日历 key or Calendar column with the calendar plugin on; short key names, tier only for a shared name',async({page})=>{
 const {send,receive,data}=await open(page);
 await expect(page.locator('.eng-keys .pl-key[data-plugin="calendar"],.eng-cols .pl-col[data-plugin="calendar"]')).toHaveCount(0);
 await expect(page.locator('.eng-keys .pl-key[data-plugin="resources"]')).toHaveCount(1);
 const names=page.locator('.eng-keys .ek[data-sub] .ek-name');
 await expect(names).toHaveText(['Codex','ZCode']);
 await expect(page.locator('.eng-keys .ek[data-sub]').nth(1)).toHaveAttribute('title',/ZCode \/ GLM/);
 // Two Codex subscriptions: the tier (plan) tells them apart.
 const second=structuredClone(data.projection.rows[0]);second.accounts[0].subscriptionRef='00000000000000aa';second.accounts[0].accountLocator='00000000000000aa';second.accounts[0].plan={...second.accounts[0].plan,id:'plus',name:{en:'Plus',zh:'Plus'}};
 data.projection.rows[0].accounts.push(second.accounts[0]);data.subscriptions.push({subscriptionRef:'00000000000000aa',accounts:[{tool:'codex',account:structuredClone(second.accounts[0])}]});
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(names).toHaveText(['Codex 模拟方案','Codex Plus','ZCode']);
});

test('D464 the range row: tokens are the big figure, then ≈cost, then speed',async({page})=>{
 await open(page,{locale:'en'});
 const row=cols(page).first().locator('.qrow-t');
 expect(await row.evaluate(r=>[...r.children].map(c=>c.className.split(' ')[0]))).toEqual(['qtokens','qaverage']);
 await expect(row.locator('.qtokens')).toHaveText('5.6M');
 const size=await row.evaluate(r=>[...r.children].map(c=>parseFloat(getComputedStyle(c).fontSize)));
 expect(size[0]).toBeGreaterThan(size[1]+4);
 expect(await row.evaluate(r=>r.scrollWidth<=r.clientWidth)).toBe(true);
});

test('D466 every subscription column draws its 24 h strip: now bar, peak block, reset tick; text stops before it',async({page})=>{
 await open(page);
 await expect(cols(page)).toHaveCount(2);
 for(const i of [0,1]){
  const col=cols(page).nth(i),hit=col.locator('.ec-strip');
  await expect(hit).toHaveCount(1);await expect(hit.locator('.st-now')).toHaveCount(1);
  const [h,bar,c]=await Promise.all([hit.boundingBox(),hit.locator('.ec-strip-bar').boundingBox(),col.boundingBox()]);
  expect(bar.width).toBeCloseTo(6,0);expect(h.width).toBeGreaterThanOrEqual(12);
  expect(h.x+h.width).toBeLessThanOrEqual(c.x+c.width+.5);
  // No cell text runs under the strip.
  const right=await col.locator('.qtxt,.qtokens,.qrv-c,.qrv-p').evaluateAll(es=>Math.max(...es.filter(e=>e.getClientRects().length).map(e=>e.getBoundingClientRect().right)));
  expect(right).toBeLessThanOrEqual(h.x);
 }
 const z=cols(page).nth(1).locator('.ec-strip');
 await expect(z.locator('.st-peak')).toHaveCount(1);await expect(z.locator('.st-reset')).toHaveCount(1);
 const [peak,bar]=await Promise.all([z.locator('.st-peak').boundingBox(),z.locator('.ec-strip-bar').boundingBox()]);
 // 22:00 is 12h20 after 09:40: just past the middle of the 24 h bar.
 expect((peak.y-bar.y)/bar.height).toBeGreaterThan(.48);expect((peak.y-bar.y)/bar.height).toBeLessThan(.56);
 // Codex has no rules and nothing timed in 24 h: the strip is still there, with only the now bar.
 await expect(cols(page).nth(0).locator('.ec-strip .st-peak,.ec-strip .st-reset')).toHaveCount(0);
});

test('D466 strip hover: the card opens to the left with "接下来" lines and "7 天日历 ›"',async({page})=>{
 await open(page);
 const z=cols(page).nth(1).locator('.ec-strip');
 await z.hover();
 const card=page.locator('.ec-next');
 await expect(card).toBeVisible();
 await expect(card.locator('.h')).toHaveText('ZCode · 接下来 24 小时');
 await expect(card.locator('.ln.now')).toContainText('闲时');
 await expect(card).toContainText('13:04');await expect(card).toContainText('5 小时额度重置');await expect(card).toContainText('22:00–02:00');
 await expect(card.locator('.ln.link')).toHaveText('7 天日历 ›');
 const [c,s]=await Promise.all([card.boundingBox(),z.boundingBox()]);
 expect(c.x+c.width).toBeLessThanOrEqual(s.x+.5);
 // Codex: nothing in 24 h, so the card says so and lists what comes after.
 await cols(page).nth(0).locator('.ec-strip').hover();
 await expect(card.locator('.ln.quiet')).toHaveText('没有重置，也没有高峰');await expect(card).toContainText('之后');await expect(card).toContainText('每周额度重置');
});

for(const via of ['strip','link'])test(`D466 ${via}: opens the 日历 tab filtered to that subscription, "只看 X ✕" shows all again`,async({page})=>{
 const {send,receive}=await open(page);
 const z=cols(page).nth(1).locator('.ec-strip');
 if(via==='strip')await z.click({position:{x:2,y:60}});// the hit area is wider than the visible bar
 else{await z.hover();await page.locator('.ec-next .ln.link').click();}
 const tab=page.locator('.mfd-pk .pk[data-mfd="page:calendar"]');
 await expect(tab).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.mfd-pk .pk-seg')).toBeHidden();// a fixed page, not a plugin screen: no "‹ 总览 │ 日历" switch
 const asked=await page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='rangeSelect').map(m=>m.key));
 expect(asked.at(-1)).toBe('7d');
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 const chip=page.locator('.pg-calendar .cal-chip');
 await expect(chip).toHaveText('只看 ZCode✕');
 await expect(page.locator('.pg-calendar .cal-wk7')).toBeVisible();
 // Only ZCode: its daily peak blocks, its 13:04 chip; nothing of Codex.
 await expect(page.locator('.pg-calendar .w7-pk').first()).toBeVisible();
 await expect(page.locator('.pg-calendar .w7-rc.resetWeek')).toHaveCount(0);
 await chip.click();
 await expect(page.locator('.pg-calendar .cal-chip')).toHaveText('全部订阅');
 await expect(page.locator('.pg-calendar .w7-rc.resetWeek')).not.toHaveCount(0);
});

test('D466 the 日历 tab follows the range switch: 24 h agenda, week grid with the day list, dated list; multi-day = one chip',async({page})=>{
 const {send,receive}=await open(page);
 await page.locator('.mfd-pk .pk[data-mfd="page:calendar"]').click();
 const cal=page.locator('.pg-calendar .cal-page');
 await expect(cal).toHaveAttribute('data-view','today');
 await expect(cal.locator('.cal-ag .ag-lane')).toHaveCount(2);
 await expect(cal.locator('.ag-w').first()).toContainText('现在 09:40');
 await expect(cal.locator('.ag-words')).toContainText('22:00–02:00');await expect(cal.locator('.ag-words')).toContainText('回到闲时');
 await expect(cal.locator('.cal-later')).toContainText('每周额度重置');
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(cal).toHaveAttribute('data-view','7d');
 await expect(cal.locator('.w7-dh')).toHaveCount(7);await expect(cal.locator('.w7-dh.today')).toHaveCount(1);
 // The reserve expiring in two days is one chip on its expiry day, never a bar across the week.
 await expect(cal.locator('.w7-chip.reserve')).toHaveCount(1);
 const chip=await cal.locator('.w7-chip.reserve').boundingBox(),day=await cal.locator('.w7-dh').nth(2).boundingBox();
 expect(chip.width).toBeLessThanOrEqual(day.width+.5);expect(chip.x).toBeGreaterThanOrEqual(day.x-1);
 await expect(cal.locator('.wk-adr.bar')).toHaveCount(0);
 // The picked day as words, all-day items first; picking another day moves the list.
 await expect(cal.locator('.w7-lh')).toContainText('今天');
 await cal.locator('.w7-dh').nth(2).click();
 await expect(cal.locator('.w7-li').first()).toContainText('储备到期');
 expect(await receive(send('shell',{...shell,range:'30d'}))).toBe(true);
 await expect(cal).toHaveAttribute('data-view','30d');
 await expect(cal.locator('.cal-30 .c30-li')).not.toHaveCount(0);
 await expect(cal.locator('.cal-30')).toContainText('每周额度重置');await expect(cal.locator('.cal-30')).not.toContainText('高峰');
});

for(const locale of ['zh-CN','en'])test(`D466 five page keys and the Resources switch fit without clipping (${locale})`,async({page})=>{
 const {send,receive}=await open(page,{locale});
 const keys=page.locator('.dk-mfd .mfd-pk > .pk');
 await expect(keys).toHaveCount(5);
 expect(await keys.evaluateAll(ks=>ks.map(k=>k.dataset.mfd))).toEqual(['page:overview','page:sub','page:tune','page:where','page:calendar']);
 const clipped=()=>page.evaluate(()=>[...document.querySelectorAll('.dk-mfd .mfd-pk > .pk:not([hidden]) span, .dk-mfd .mfd-pk .pk-seg:not([hidden]) [role=tab]')].filter(e=>e.getClientRects().length&&e.scrollWidth>e.clientWidth+.5).map(e=>e.textContent));
 const widths=()=>page.evaluate(()=>[...document.querySelectorAll('.dk-mfd .mfd-pk > .pk, .dk-mfd .mfd-pk > .pk-seg')].filter(e=>!e.hidden&&e.getClientRects().length).map(e=>Math.round(e.getBoundingClientRect().width)));
 expect(await clipped()).toEqual([]);
 const none=await widths();expect(none).toHaveLength(5);expect(new Set(none).size).toBe(1);
 expect(await receive(send('pluginData',{id:'resources',data:{samples:[reading(NOW-5000),reading(NOW)]}}))).toBe(true);
 await page.locator('.eng-keys .pl-key[data-plugin="resources"]').click();
 await expect(page.locator('.dk-mfd .mfd-pk .pk-seg')).toBeVisible();
 expect(await clipped()).toEqual([]);
 const open=await widths();expect(open).toHaveLength(5);expect(new Set(open).size).toBe(1);
 const fit=await page.evaluate(()=>{const s=document.querySelector('.mfd-pk .pk-seg').getBoundingClientRect();return [...document.querySelectorAll('.mfd-pk .pk-seg [role=tab]')].every(h=>{const r=h.getBoundingClientRect();return r.left>=s.left-.5&&r.right<=s.right+.5;});});
 expect(fit).toBe(true);
});

// macrevb-1290-2 on the 日历 tab: the agenda's news line reads the same clock as the key dot, so both go at the look
// deadline; the banked reset's chip then stays on its day, muted (the calendar is a record).
test('D466 the agenda news line and the key dot retire together at the look deadline',async({page})=>{
 const data=band(),at=local(27,0,29);
 data.details.resetEvents=[{version:1,id:'codex-banked-1127',provider:'openai',rowId:'codex',kind:'reset_credit',status:'confirmed',publishedAt:iso(at-H),confirmedAt:iso(at),expiresAt:iso(at+28*24*H),source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const {send,receive}=await open(page,{data});
 await page.locator('.mfd-pk .pk[data-mfd="page:calendar"]').click();
 const news=page.locator('.pg-calendar .cal-news');
 await expect(news).toHaveCount(1);await expect(news).toContainText('+1');await expect(news).toHaveAttribute('data-news','codex-banked-1127#confirmed');
 await expect(page.locator('.eng-keys .ek[data-sub] .ek-news')).toHaveCount(1);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+30*60_000),reason:'deadline'}))).toBe(true);
 await expect(page.locator('.pg-calendar .cal-news')).toHaveCount(0);
 await expect(page.locator('.eng-keys .ek[data-sub] .ek-news')).toHaveCount(0);
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(page.locator('.pg-calendar .w7-chip.credit.past')).toHaveCount(1);
});
