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
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,range:range??'today'},redBelow:25}))).toBe(true);
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
 await expect(page.locator('.eng-keys .ek[data-sub]').nth(1)).toHaveAttribute('data-hc',/ZCode \/ GLM/);
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

// D474 §4.2, §6.1, C25 (the calm strip): no now bar, no track; a reset is a 2 pt notch inside the rail, a peak a maker tint;
// nothing falls in 24 h: nothing is drawn. The hit area is the column's text margin wide (16 pt; 10 pt narrow) and spans the
// quota rows, never over text; a faint rail shows on column hover.
test('D466 the calm strip: no now bar, no track; a notch for a reset, a tint for a peak; the hit area is the 16 pt text margin and never over text',async({page})=>{
 await open(page);
 await expect(cols(page)).toHaveCount(2);
 for(const i of [0,1]){
  const col=cols(page).nth(i),hit=col.locator('.ec-strip');
  await expect(hit).toHaveCount(1);
  await expect(hit.locator('.st-now,.st-h,.st-mid')).toHaveCount(0);
  const [h,bar,c,range]=await Promise.all([hit.boundingBox(),hit.locator('.ec-strip-bar').boundingBox(),col.boundingBox(),col.locator('.qrow-t').boundingBox()]);
  expect(h.width).toBeCloseTo(16,0);expect(bar.width).toBeCloseTo(6,0);
  expect(h.x+h.width).toBeLessThanOrEqual(c.x+c.width+.5);
  expect(h.y+h.height).toBeLessThanOrEqual(range.y+.5);// spans the quota rows, stops at the range row
  expect(h.height).toBeGreaterThan(60);
  // No cell text runs under the strip.
  const right=await col.locator('.qtxt,.qnum').evaluateAll(es=>Math.max(...es.filter(e=>e.getClientRects().length).map(e=>e.getBoundingClientRect().right)));
  expect(right).toBeLessThanOrEqual(h.x+.5);
  // No track: the rail is invisible until the column is hovered or focused.
  expect(await hit.locator('.ec-strip-bar').evaluate(e=>getComputedStyle(e).backgroundColor)).toMatch(/rgba\(0, 0, 0, 0\)|transparent/);
 }
 const z=cols(page).nth(1).locator('.ec-strip');
 await expect(z.locator('.st-peak')).toHaveCount(1);await expect(z.locator('.st-reset')).toHaveCount(1);
 const [peak,notch,bar]=await Promise.all([z.locator('.st-peak').boundingBox(),z.locator('.st-reset').boundingBox(),z.locator('.ec-strip-bar').boundingBox()]);
 // 22:00 is 12h20 after 09:40: just past the middle of the 24 h bar. The notch is as wide as the rail and 2 pt high, inside it.
 expect((peak.y-bar.y)/bar.height).toBeGreaterThan(.48);expect((peak.y-bar.y)/bar.height).toBeLessThan(.56);
 expect(notch.width).toBeCloseTo(bar.width,0);expect(notch.height).toBeCloseTo(2,0);expect(notch.x).toBeGreaterThanOrEqual(bar.x-.5);
 expect(await z.locator('.st-peak').evaluate(e=>getComputedStyle(e).opacity)).toBe('0.38');
 // Codex has nothing timed in 24 h: nothing is drawn at all.
 await expect(cols(page).nth(0).locator('.ec-strip i')).toHaveCount(0);
 // The faint rail shows on column hover (an empty strip is still findable).
 await cols(page).nth(0).hover({position:{x:20,y:20}});
 expect(await cols(page).nth(0).locator('.ec-strip-bar').evaluate(e=>getComputedStyle(e).backgroundColor)).not.toMatch(/rgba\(0, 0, 0, 0\)|transparent/);
});

// n synthetic subscriptions (the width spec's fixture): 6 columns in 中文 are narrow (91 pt).
function many(n){
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];data.details.forecasts=[];data.details.resetEvents=[];data.details.sessions=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0'),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref,accountLocator:ref,valueState:'current',observedAt:iso(NOW-3*60000),lastFailure:null});a.plan.name=null;a.windows=a.windows.slice(0,2);
  Object.assign(a.windows[0],{current:true,validUntil:iso(NOW+600*60000),resetsAt:iso(NOW+2*H),remainingPercent:80});
  Object.assign(a.windows[1],{current:true,validUntil:iso(NOW+600*60000),resetsAt:iso(NOW+100*H),remainingPercent:53});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref,today:[{...detail.today[0],source:row.id}]});
 }
 data.details.peaks=[];
 return data;
}
test('D466 a narrow column: a 10 pt hit area and a 3 pt rail, still left of the text; the 2 h reset is a notch inside it',async({page})=>{
 await open(page,{data:many(6)});
 await expect(cols(page)).toHaveCount(6);
 await expect(page.locator('.eng-lcd')).toHaveClass(/cls-narrow/);
 const col=cols(page).nth(2),hit=col.locator('.ec-strip');
 const [h,bar]=await Promise.all([hit.boundingBox(),hit.locator('.ec-strip-bar').boundingBox()]);
 expect(h.width).toBeCloseTo(10,0);expect(bar.width).toBeCloseTo(3,0);
 const right=await col.locator('.qtxt,.qnum').evaluateAll(es=>Math.max(...es.filter(e=>e.getClientRects().length).map(e=>e.getBoundingClientRect().right)));
 expect(right).toBeLessThanOrEqual(h.x+.5);
 await expect(hit.locator('.st-reset')).toHaveCount(1);
});

// macrev2-1291-3: the card is reachable by ordinary pointer travel from the strip to its "7 天日历 ›" link (no gap that closes it).
for(const locale of ['zh-CN','en'])test(`D466 strip hover: the card opens to the left, stays open while the pointer travels to its link, and the link opens the filtered week (${locale})`,async({page})=>{
 const {send,receive}=await open(page,{locale});
 const zh=locale==='zh-CN',z=cols(page).nth(1).locator('.ec-strip');
 await z.hover();
 const card=page.locator('.ec-next');
 await expect(card).toBeVisible();
 await expect(card.locator('.h')).toHaveText(zh?'ZCode · 接下来 24 小时':'ZCode · next 24 hours');
 await expect(card.locator('.ln.now')).toContainText(zh?'闲时':'Off-peak');
 await expect(card).toContainText('13:04');await expect(card).toContainText('22:00–02:00');
 const [c,s]=await Promise.all([card.boundingBox(),z.boundingBox()]);
 expect(c.x+c.width).toBeLessThanOrEqual(s.x+.5);
 expect(s.x-(c.x+c.width)).toBeLessThanOrEqual(0.5);// no gap between the strip and the card
 // Stepped, trusted travel from the strip to the link: the card never closes on the way.
 const link=card.locator('.ln.link'),l=await link.boundingBox();
 const from={x:s.x+s.width/2,y:s.y+s.height/2},to={x:l.x+l.width/2,y:l.y+l.height/2};
 for(let i=1;i<=24;i++){await page.mouse.move(from.x+(to.x-from.x)*i/24,from.y+(to.y-from.y)*i/24);await expect(page.locator('.ec-next')).toHaveCount(1);}
 await link.click();
 await expect(page.locator('.mfd-pk .pk[data-mfd="page:calendar"]')).toHaveAttribute('aria-pressed','true');
 const asked=await page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='rangeSelect').map(m=>m.key));
 expect(asked.at(-1)).toBe('7d');
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(page.locator('.pg-calendar .cal-chip')).toHaveText(zh?'只看 ZCode✕':'Only ZCode✕');
 // Codex: nothing in 24 h, so the card says so and lists what comes after.
 await page.mouse.move(2,2);
 await page.locator('.mfd-pk .pk[data-mfd="page:overview"]').click();
 await cols(page).nth(0).locator('.ec-strip').hover();
 await expect(page.locator('.ec-next .ln.quiet')).toHaveText(zh?'没有重置，也没有高峰':'Nothing in the next 24 h');
});
// D474 §7.3 (G-d): Tab walks the band column by column: a column's cells top to bottom, its range and reserve rows, then its strip, then
// the next column. Arrows move across rows and columns. Enter on a strip opens its filtered calendar.
test('D466 keyboard: Tab walks the band column by column and ends each column on its strip; arrows move across; Enter opens the calendar',async({page})=>{
 await open(page);
 await cols(page).nth(0).locator('.qcell[tabindex="0"]').first().focus();
 const stops=[];
 for(let i=0;i<14;i++){
  stops.push(await page.evaluate(()=>{const e=document.activeElement,c=e.closest('.ec[data-col]');if(!c)return null;
   return {col:[...document.querySelectorAll('.eng-cols > .ec[data-col]')].indexOf(c),kind:e.classList.contains('ec-strip')?'strip':e.classList.contains('qcell')?'cell':e.classList.contains('qrow-t')?'range':e.classList.contains('qrow-r')?'reserve':'other'};}));
  await page.keyboard.press('Tab');
 }
 const seq=stops.filter(Boolean);
 const firstStrip=seq.findIndex(x=>x.kind==='strip');
 expect(firstStrip).toBeGreaterThan(1);
 expect(seq.slice(0,firstStrip+1).every(x=>x.col===0),'column 0 is walked completely before column 1').toBe(true);
 expect(seq[firstStrip+1].col).toBe(1);
 expect(seq.slice(0,firstStrip).every(x=>x.kind!=='strip'),'the strip comes after the cells').toBe(true);
 // Arrows: Right moves to the same row of the next column; Down to the next item of the column.
 const a=cols(page).nth(0).locator('.qcell[data-row="second"]');await a.focus();
 await page.keyboard.press('ArrowRight');
 expect(await page.evaluate(()=>{const e=document.activeElement;return [[...document.querySelectorAll('.eng-cols > .ec[data-col]')].indexOf(e.closest('.ec')),e.dataset.row];})).toEqual([1,'second']);
 await page.keyboard.press('ArrowLeft');await page.keyboard.press('ArrowDown');
 expect(await page.evaluate(()=>[[...document.querySelectorAll('.eng-cols > .ec[data-col]')].indexOf(document.activeElement.closest('.ec')),document.activeElement.dataset.row??document.activeElement.className.split(' ')[1]])).toEqual([0,expect.anything()]);
 // Enter on a strip: the filtered calendar.
 await cols(page).nth(1).locator('.ec-strip').focus();
 await expect(page.locator('.ec-next')).toBeVisible();
 await page.keyboard.press('Enter');
 await expect(page.locator('.mfd-pk .pk[data-mfd="page:calendar"]')).toHaveAttribute('aria-pressed','true');
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
 // The filter chip is local to 日历 (audit 16): it asks for no header scope change, and the band keeps its own highlight.
 expect(await page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='scopeSelect').length)).toBe(0);
 await expect(page.locator('.eng-keys .ek[aria-pressed="true"]')).toHaveCount(0);
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
 const opened=await widths();expect(opened).toHaveLength(5);expect(new Set(opened).size).toBe(1);
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
});

// The banked reset's chip stays on its issue day after its news clock; it turns muted (the calendar is a record).
test('D466 the banked reset chip on the week retires with its news clock and stays on its day, muted',async({page})=>{
 const data=band(),at=local(27,0,29);
 data.details.resetEvents=[{version:1,id:'codex-banked-1127',provider:'openai',rowId:'codex',kind:'reset_credit',status:'confirmed',publishedAt:iso(at-H),confirmedAt:iso(at),expiresAt:iso(at+28*24*H),source:{kind:'publication',publicationId:'0123456789abcdef01234567'}}];
 const {send,receive}=await open(page,{data,range:'7d'});
 await page.locator('.mfd-pk .pk[data-mfd="page:calendar"]').click();
 await expect(page.locator('.pg-calendar .w7-chip.credit.news')).toHaveCount(1);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+30*60_000),reason:'deadline'}))).toBe(true);
 await expect(page.locator('.pg-calendar .w7-chip.credit.news')).toHaveCount(0);
 await expect(page.locator('.pg-calendar .w7-chip.credit.past')).toHaveCount(1);
});

// ---- macrev2-1291-4..7: the calendar's data, through the normal bridge ------------------------------------------------------
const event=(o)=>({version:1,provider:'openai',rowId:'codex',status:'announced',publishedAt:iso(NOW-H),expiresAt:iso(NOW+20*24*H),source:{kind:'publication',publicationId:'0123456789abcdef01234567'},...o});
const weekChips=(page,sel)=>page.locator(`.pg-calendar ${sel}`);
async function toWeek(page,{send,receive,locale}={}){
 await page.locator('.mfd-pk .pk[data-mfd="page:calendar"]').click();
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(page.locator('.pg-calendar .cal-wk7')).toBeVisible();
 void locale;
}

// macrev2-1291-7: no 16-subscription transport cap on the fixed page: the last bank's last column has its strip, its own filtered
// calendar, and its lane in Today.
test('macrev2-1291-7 with 17 subscriptions the last column still has its strip, opens its own filtered calendar, and Today has 17 lanes',async({page})=>{
 const {send,receive}=await open(page,{data:many(17)});
 for(let i=0;i<2;i++)await page.locator('[data-bpage="1"]').click();
 await expect(page.locator('.eng-pgn')).toHaveText('3/3');
 const last=cols(page).last();
 await expect(last.locator('.ec-strip')).toHaveCount(1);
 await last.locator('.ec-strip').click();
 await expect(page.locator('.mfd-pk .pk[data-mfd="page:calendar"]')).toHaveAttribute('aria-pressed','true');
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(page.locator('.pg-calendar .cal-chip')).toHaveText('只看 订阅17✕');
 await page.locator('.pg-calendar .cal-chip').click();
 expect(await receive(send('shell',{...shell,range:'today'}))).toBe(true);
 await expect(page.locator('.pg-calendar .cal-ag .ag-lane')).toHaveCount(17);
});

// macrev2-1291-4: a published peak is plan-wide for its row: every subscription on it has the peak in its strip and agenda.
test('macrev2-1291-4 two ZCode accounts share one published peak: both strips and both filtered weeks carry it',async({page})=>{
 const data=band(),zrow=data.projection.rows[1];
 const second=structuredClone(zrow.accounts[0]);second.subscriptionRef='00000000000000bb';second.accountLocator='00000000000000bb';
 zrow.accounts.push(second);data.subscriptions.push({subscriptionRef:'00000000000000bb',accounts:[{tool:'zai',account:structuredClone(second)}]});
 data.details.subscriptions.push({...structuredClone(data.details.subscriptions[1]),subscriptionRef:'00000000000000bb'});
 const {send,receive}=await open(page,{data});
 await expect(cols(page)).toHaveCount(3);
 const counts=await cols(page).evaluateAll(cs=>cs.map(c=>c.querySelectorAll('.ec-strip .st-peak').length));
 expect(counts,'Codex has none; both ZCode accounts have the peak').toEqual([0,1,1]);
 await cols(page).nth(2).locator('.ec-strip').click();
 expect(await receive(send('shell',{...shell,range:'7d'}))).toBe(true);
 await expect(page.locator('.pg-calendar .w7-pk').first()).toBeVisible();
});

// macrev2-1291-5: a banked reset is a reserve event: one all-day chip on its issue day, never a timed chip; an official window
// that spans days sits on its start day with its range in the words; every known reserve expiry is its own chip.
test('macrev2-1291-5 a scheduled banked reset is an all-day chip on its issue day, not a timed chip',async({page})=>{
 const data=band();
 data.details.resetEvents=[event({id:'credit-sched',kind:'reset_credit',schedule:{from:iso(local(28,13)),through:iso(local(28,15)),precision:'window'}})];
 const ctx=await open(page,{data});await toWeek(page,ctx);
 await expect(weekChips(page,'.w7-chip.credit')).toHaveCount(1);
 await expect(weekChips(page,'.w7-rc.credit')).toHaveCount(0);
 const [chip,day]=await Promise.all([weekChips(page,'.w7-chip.credit').boundingBox(),page.locator('.pg-calendar .w7-dh').nth(1).boundingBox()]);
 expect(chip.x).toBeGreaterThanOrEqual(day.x-1);expect(chip.x+chip.width).toBeLessThanOrEqual(day.x+day.width+1);
});
test('macrev2-1291-5 a multi-day official window sits on its start day with its range in the words, not at its midpoint',async({page})=>{
 const data=band();
 data.details.resetEvents=[event({id:'official-span',kind:'direct_reset',schedule:{from:iso(local(28,10)),through:iso(local(30,10)),precision:'window'}})];
 const ctx=await open(page,{data});await toWeek(page,ctx);
 await page.locator('.pg-calendar .w7-dh').nth(1).click();// the start day (28th)
 const li=page.locator('.pg-calendar .w7-li',{hasText:'官方额度重置'});
 await expect(li).toHaveCount(1);await expect(li).toContainText('官方额度重置');await expect(li).toContainText('至 11/30');await expect(li.locator('b')).toHaveText('10:00');
 await page.locator('.pg-calendar .w7-dh').nth(2).click();// the midpoint day (29th) has nothing
 await expect(page.locator('.pg-calendar .w7-li',{hasText:'官方额度重置'})).toHaveCount(0);
});
test('macrev2-1291-5 every known reserve expiry is its own chip in the week; a partial inventory invents no later date',async({page})=>{
 const data=band();
 data.details.subscriptions[0].resetCards={state:'complete',count:2,truncated:false,sources:[],items:[{id:'1'.padStart(64,'0'),expiresAt:iso(NOW+50*H)},{id:'2'.padStart(64,'0'),expiresAt:iso(NOW+100*H)}]};
 const ctx=await open(page,{data});await toWeek(page,ctx);
 await expect(weekChips(page,'.w7-chip.reserve')).toHaveCount(2);
 // Partial: only its own earliest expiry is known.
 data.details.subscriptions[0].resetCards={state:'partial',count:2,truncated:true,earliestExpiresAt:iso(NOW+50*H),sources:[],items:[{id:'1'.padStart(64,'0'),expiresAt:iso(NOW+50*H)}]};
 expect(await ctx.receive(ctx.send('display',{data}))).toBe(true);
 await expect(weekChips(page,'.w7-chip.reserve')).toHaveCount(1);
});

// macrev2-1291-6: a dense all-day day keeps the grid and the picked day's list usable and every item reachable.
test('macrev2-1291-6 seven all-day items on one day: two chip lines at most, a +N chip, and the day list keeps its height with every item',async({page})=>{
 const data=band();
 data.details.resetEvents=Array.from({length:7},(_,i)=>event({id:`dense-${i}`,kind:'direct_reset',schedule:{from:iso(local(27,0)),through:iso(local(27,0)),precision:'date'}}));
 const ctx=await open(page,{data});await toWeek(page,ctx);
 const ad=page.locator('.pg-calendar .w7-ad');
 expect((await ad.boundingBox()).height).toBeLessThanOrEqual(32);
 await expect(page.locator('.pg-calendar .w7-more')).toHaveText('+6');
 const list=page.locator('.pg-calendar .w7-list');
 expect((await list.boundingBox()).height).toBeGreaterThanOrEqual(40);
 await expect(list.locator('.w7-li',{hasText:'官方额度重置'})).toHaveCount(7);
 const grid=await page.locator('.pg-calendar .w7-body').boundingBox();expect(grid.height).toBeGreaterThan(60);
 await page.locator('.pg-calendar .w7-more').click();
 await expect(page.locator('.pg-calendar .w7-dh.sel')).toHaveAttribute('data-day','0');
});
