// SPDX-License-Identifier: MIT
// v1.1 calendar plugin (owner D137, D145, D293, D328; CKP-PLG-06, CKP-PLG-07; D323 custom draw): the column's next-12-hours
// strip and the 7-day week view on the plugin's big screen inside the MFD screen, both drawn through the framework's
// `draw` hook. Times are local (America/Los_Angeles here).
// Set CAL_SHOTS=<dir> to also write review screenshots.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,capture,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.use({timezoneId:'America/Los_Angeles'});
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// Pacific standard time in November 2026: local = UTC-8. Day 0 = Wednesday 11/11; now = 11:20.
const L=(day,h,m=0)=>Date.UTC(2026,10,11+day,h+8,m);
const NOW=L(0,11,20);
const shots=process.env.CAL_SHOTS;
const shot=async(page,name,target=page)=>{if(shots)await target.screenshot({path:`${shots}/${name}.png`});};
// The resource plugin (D324) is also default on; it is kept off here so the calendar's column math is its own.
const calendarOn={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:false,pinned:false}],settings:{}};
// The mockup's sample week: four subscriptions, GLM's 22:00–02:00 peak crossing midnight, own resets, a reset card and
// an announced GLM reset taking effect on Monday 11/16.
const week={version:1,peakRules:'yes',
 subs:[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}},{abbr:'CU',colour:'#eef2f6',name:{en:'Cursor',zh:'Cursor'}}],
 peaks:[{sub:0,from:L(0,5),to:L(0,11),tentative:false},{sub:2,from:L(0,22),to:L(1,2),tentative:false},{sub:0,from:L(1,5),to:L(1,11),tentative:false},{sub:2,from:L(1,22),to:L(2,2),tentative:false},{sub:0,from:L(2,5),to:L(2,11),tentative:false},{sub:0,from:L(5,5),to:L(5,11),tentative:false},{sub:2,from:L(5,22),to:L(6,2),tentative:false}],
 resets:[{sub:0,at:L(0,12,30),kind:'5h'},{sub:1,at:L(0,14,10),kind:'5h'},{sub:2,at:L(0,15,50),kind:'5h'},{sub:0,at:L(1,9),kind:'week'},{sub:1,at:L(2,6),kind:'week'}],
 spans:[{sub:0,kind:'cards',from:NOW,to:L(2,18),count:1},{sub:2,kind:'announced',from:L(-1,10),to:L(5,0),count:null}]};
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
async function open(page,{data=dataWith(4),tier='tall',locale='en',push=week,at=NOW}={}) {
 await page.clock.setFixedTime(new Date(at));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:calendarOn}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 if(push)expect(await receive(send('pluginData',{id:'calendar',data:push}))).toBe(true);
 return {send,receive};
}
const column=page=>page.locator('.eng-cols .pl-col[data-plugin="calendar"]');
const strip=page=>column(page).locator('.pl-draw .cal');
const key=page=>page.locator('.eng-keys .pl-key[data-plugin="calendar"]');
const screen=page=>page.locator('.dk-mfd .mfd-screen .pl-screen[data-plugin="calendar"]');
const weekView=page=>screen(page).locator('.pl-screen-d .cal-wk');
const deadlines=page=>page.evaluate(()=>window.__events.filter(e=>e.type==='nextDeadline').map(e=>e.deadlineUnixMs));

test('the unknown-peak footer fits on a crowded Chinese plugin page',async({page})=>{
 const {send,receive}=await open(page,{data:dataWith(9),locale:'zh-CN',push:null});
 expect(await receive(send('plugins',{plugins:{version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}}}))).toBe(true);
 await page.locator('[data-bpage="1"]').click();
 const value=column(page).locator('.pl-foot-v');
 await expect(value).toHaveAttribute('data-full','暂无高峰数据');
 await expect(value).toHaveText('暂无数据');
 await expect(column(page).locator('.pl-foot')).toHaveAttribute('aria-label','高峰 · 暂无高峰数据');
 expect(await value.evaluate(e=>e.scrollWidth<=e.clientWidth)).toBe(true);
});

test('D328 column: the next 12 hours only; peaks, capsules with the time, the now line, one all-day line, no picker or fold',async({page})=>{
 await open(page);
 // Default on (D121) once the host knows plugins: 4 subscriptions + the calendar = 5 equal columns.
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','5');
 const col=column(page),sub=page.locator('.eng-cols .ec[data-col]').first();
 const [a,b]=[await col.boundingBox(),await sub.boundingBox()];expect(Math.abs(a.width-b.width)).toBeLessThan(2);
 await expect(key(page).locator('.ek-name')).toHaveText('Calendar');
 // D323: drawn through the framework's hook; the key, its underline (grey dashed #87939e) and the bottom line stay the framework's.
 await expect(col).toHaveAttribute('data-draw','custom');
 await expect(key(page).locator('.pl-dash')).toHaveCount(1);
 // 11:20 + 12 h: GL's 22:00–02:00 peak is next (10h40 away).
 await expect(col.locator('.pl-foot .pl-foot-l')).toHaveAttribute('data-full','Next peak');await expect(col.locator('.pl-foot .pl-foot-v')).toHaveText('in 10h40');
 const s=strip(page);
 for(const gone of ['.cal-d','.cal-pick','.cal-back','.cal-fold','.cal-more','.cal-hd'])await expect(s.locator(gone)).toHaveCount(0);
 await expect(s.locator('.cal-adr')).toHaveText(['Claude Banked · until 11/13 +1']);
 await expect(s.locator('.cal-adr')).toHaveAttribute('title',/Banked resets · until 11\/13 \+1$/);
 // 12 hours end at 23:20 on Wednesday: no midnight divider; GLM's peak is the only block, on one line.
 await expect(s.locator('.cal-mid')).toHaveCount(0);
 // G3-179: at five columns the label sheds the abbreviation before the time clips; the tooltip keeps the sentence.
 await expect(s.locator('.cal-pk b')).toHaveText(['22:00–02:00']);
 await expect(s.locator('.cal-pk')).toHaveAttribute('title',/GLM/);
 await expect(s.locator('.cal-ch')).toHaveText(['Claude 5h 12:30','Codex 5h 14:10','GLM 5h 15:50']);
 await expect(s.locator('.cal-ch.wk')).toHaveCount(0);
 const boxes=await s.locator('.cal-ch').evaluateAll(es=>es.map(e=>{const r=e.getBoundingClientRect();return [r.top,r.bottom];}));
 for(let i=1;i<boxes.length;i++)expect(boxes[i][0]).toBeGreaterThanOrEqual(boxes[i-1][1]);
 await expect(s.locator('.cal-nl')).toHaveCount(1);await expect(s.locator('.cal-nt')).toHaveText('11:20');
 // Text is 9 px at least.
 const small=await s.locator('*').evaluateAll(es=>es.filter(e=>e.childNodes.length&&[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())&&parseFloat(getComputedStyle(e).fontSize)<9).length);
 expect(small).toBe(0);
 // Everything stays inside the drawn area (above the framework's bottom line).
 const [area,foot]=[await col.locator('.pl-draw').boundingBox(),await col.locator('.pl-foot').boundingBox()];
 expect(area.y+area.height).toBeLessThanOrEqual(foot.y+0.5);
 await expect(screen(page)).toHaveCount(0);// the column's own controls never open the screen
 await shot(page,'A-strip-en',page.locator('.ck-eng'));
});

test('D328 Chinese labels, a running peak in the bottom line, and the 明 divider when midnight falls inside',async({page})=>{
 const {send,receive}=await open(page,{locale:'zh-CN'});
 await expect(column(page).locator('.pl-foot .pl-foot-l')).toHaveText('下个高峰');await expect(column(page).locator('.pl-foot .pl-foot-v')).toHaveText('10h40 后');
 await expect(strip(page).locator('.cal-adr')).toHaveText(['Claude 额外重置 至11/13 +1']);
 await expect(strip(page).locator('.cal-adr')).toHaveAttribute('title',/额外重置次数 至11\/13 \+1$/);
 await shot(page,'A-strip-zh',page.locator('.ck-eng'));
 // 23:00: GLM's peak is running (until 02:00) and the 12 h window now holds midnight.
 expect(await receive(send('tick',{nowUnixMs:String(L(0,23)),reason:'deadline'}))).toBe(true);
 await expect(column(page).locator('.pl-foot .pl-foot-l')).toHaveText('GLM 高峰中');await expect(column(page).locator('.pl-foot .pl-foot-v')).toHaveText('还剩 3h00');
 await expect(strip(page).locator('.cal-pk b')).toHaveText(['GLM 至 02:00','05:00–11:00']);
 await expect(strip(page).locator('.cal-mid b')).toHaveText(['明']);
});

test('D328 no peak rules: the column shows D293 cells and "Peak: no peak rules", not the strip',async({page})=>{
 const codexOnly={version:1,peakRules:'no',subs:[week.subs[1]],peaks:[],resets:[{sub:0,at:L(0,14,10),kind:'5h'},{sub:0,at:L(2,6),kind:'week'}],spans:[]};
 await open(page,{push:codexOnly,locale:'zh-CN'});
 const col=column(page);
 expect(await col.getAttribute('data-draw')).toBeNull();
 await expect(col.locator('.pl-draw')).toHaveCount(0);await expect(col.locator('.cal')).toHaveCount(0);
 await expect(col).toContainText('下次重置');await expect(col).toContainText('14:10');await expect(col).toContainText('2h50 后');await expect(col).toContainText('Codex 5 小时');
 await expect(col).toContainText('每周重置');
 await expect(col.locator('.pl-foot .pl-foot-l')).toHaveText('高峰');await expect(col.locator('.pl-foot .pl-foot-v')).toHaveText('没有时段规则');
 await shot(page,'D-cells-zh',page.locator('.ck-eng'));
});

test('host minute tick: the now line and the bottom line move and the picked day rolls over without page timers',async({page})=>{
 const {send,receive}=await open(page);
 // The page asks for the next whole minute (the earliest of its own deadlines and the running plugin's).
 expect((await deadlines(page)).at(-1)).toBe(String(L(0,11,21)));
 expect(await receive(send('tick',{nowUnixMs:String(L(0,11,21)),reason:'deadline'}))).toBe(true);
 await expect(strip(page).locator('.cal-nt')).toHaveText('11:21');
 await expect(column(page).locator('.pl-foot-v')).toHaveText('in 10h39');
 expect((await deadlines(page)).at(-1)).toBe(String(L(0,11,22)));
 // Pick tomorrow in the week view, then midnight passes: tomorrow is today now, so the bottom line returns to the default.
 await key(page).click();await weekView(page).locator('.wk-dh').nth(1).click();
 await expect(column(page).locator('.pl-foot-l')).toHaveText('Thu 11/12');
 expect(await receive(send('tick',{nowUnixMs:String(L(1,0,1)),reason:'deadline'}))).toBe(true);
 await expect(column(page).locator('.pl-foot-l')).not.toHaveText('Thu 11/12');
 await expect(weekView(page).locator('.wk-dh.sel')).toHaveCount(1);
 // Stopped (occluded) plugins ask for no ticks.
 expect(await receive(send('visibility',{visible:true,occluded:true,key:false}))).toBe(true);
 await expect(column(page)).toHaveAttribute('data-running','false');
});

test('glm-844-1: keyboard focus on a week day header survives the host minute tick',async({page})=>{
 const {send,receive}=await open(page);
 await key(page).click();
 const head=weekView(page).locator('.wk-dh').nth(3);await head.focus();await expect(head).toBeFocused();
 expect(await receive(send('tick',{nowUnixMs:String(L(0,11,22)),reason:'deadline'}))).toBe(true);
 await expect(weekView(page).locator('.wk-nt')).toHaveText('11:22');
 await expect(weekView(page).locator('.wk-dh').nth(3)).toBeFocused();
});

test('CKP-PLG-07 week view opens from the key inside the MFD screen only; the key, Close, Esc and a page key close it',async({page})=>{
 await open(page);
 const col=column(page),k=key(page);
 await k.click();
 const o=screen(page),w=weekView(page);await expect(o).toBeVisible();await expect(w).toBeVisible();
 await expect(o).toHaveAttribute('data-draw','custom');
 // glm-844-2: the expanded state sits on the key (a button), never on the column's role=group.
 await expect(k).toHaveAttribute('aria-expanded','true');
 await expect(col).toHaveAttribute('role','group');expect(await col.getAttribute('aria-expanded')).toBeNull();
 // Inside the screen, never over the faders, the page keys or the option keys.
 const [ob,sb]=[await o.boundingBox(),await page.locator('.dk-mfd .mfd-screen').boundingBox()];
 expect(ob.x>=sb.x&&ob.y>=sb.y&&ob.x+ob.width<=sb.x+sb.width+0.5&&ob.y+ob.height<=sb.y+sb.height+0.5).toBe(true);expect(ob.width).toBeGreaterThan(sb.width-6);
 for(const sel of ['.dk-mfd .mfd-pk','.dk-mfd .mfd-ok','.fd-chs']){const r=await page.locator(sel).boundingBox();expect(r.y+r.height<=ob.y+0.5||r.y>=ob.y+ob.height-0.5||r.x+r.width<=ob.x+0.5,sel).toBe(true);}
 const pk=await page.locator('.dk-mfd .mfd-pk .pk').nth(1).boundingBox();
 expect(await page.evaluate(([x,y])=>!!document.elementFromPoint(x,y)?.closest('.mfd-pk'),[pk.x+pk.width/2,pk.y+pk.height/2])).toBe(true);
 // The framework's title bar; the plugin draws the body below it.
 // D413: no title row; the switch names the screen (short name, full name as its tooltip).
 await expect(o.locator('.pl-screen-h')).toHaveCount(0);await expect(page.locator('.mfd-pk .pk-seg .cur')).toHaveText('Cal');await expect(page.locator('.mfd-pk .pk-seg .cur')).toHaveAttribute('title','Calendar');
 await expect(w.locator('.wk-dh b')).toHaveText(['11','12','13','14','15','16','17']);
 await expect(w.locator('.wk-dh.we')).toHaveCount(2);await expect(w.locator('.wk-col.we')).toHaveCount(2);
 await expect(w.locator('.wk-dh.today')).toHaveCount(1);
 // D328: all-day in one row; the announced direct reset is a ↻ chip on its effective day only; capsules show the time (solid 5 h, hollow weekly).
 await expect(w.locator('.wk-adr')).toHaveText([/Claude Banked/,'↻']);
 await expect(w.locator('.wk-adr.mark')).toHaveCount(1);
 expect(await w.locator('.wk-ad').evaluate(e=>e.getBoundingClientRect().height)).toBeLessThan(20);
 await expect(w.locator('.wk-ch')).toHaveText(['12:30','14:10','15:50','09:00','06:00']);
 await expect(w.locator('.wk-ch.wk')).toHaveCount(2);
 await expect(w.locator('.wk-ch').first()).toHaveAttribute('title',/Claude · Claude 5h reset 12:30/);
 await expect(w.locator('.wk-nt')).toHaveText('11:20');
 // Whole day fitted: no scrolling.
 expect(await w.locator('.wk-sc').evaluate(e=>e.scrollHeight<=e.clientHeight+1)).toBe(true);
 await shot(page,'E3-week-fit',page.locator('.ck-deck'));
 // The key again closes.
 await k.click();await expect(o).toHaveCount(0);await expect(k).toHaveAttribute('aria-expanded','false');
 // The Overview tab of the switch (D387: no Close button)
 await k.click();await page.getByRole('tab',{name:/Overview|总览/}).click();await expect(o).toHaveCount(0);
 // Esc (focus returns to the key)
 await k.click();await expect(o).toBeVisible();await page.keyboard.press('Escape');await expect(o).toHaveCount(0);await expect(k).toBeFocused();
 // An MFD page key closes it and shows that page.
 await k.click();await expect(o).toBeVisible();
 await page.locator('.dk-mfd .mfd-pk .pk').nth(2).click();
 await expect(o).toHaveCount(0);
 await expect(page.locator('.dk-mfd .mfd-pk .pk').nth(2)).toHaveAttribute('aria-pressed','true');
});

test('CKP-PLG-07 zoom: ⌘+ / pinch to about 8 h with a scrollbar and edge hints; every open starts fitted',async({page})=>{
 await open(page);
 const k=key(page),w=weekView(page);
 await k.click();await w.locator('.wk-dh').first().focus();
 for(let i=0;i<3;i++)await page.keyboard.press('Meta+=');
 await expect(w).toHaveClass(/zoom/);
 await expect(w.locator('.wk-zoom')).toHaveText('Zoomed · ⌘− to fit');
 const sc=w.locator('.wk-sc');
 expect(await sc.evaluate(e=>Math.round(e.scrollHeight/e.clientHeight))).toBe(3);// 24 h / 8 h
 // Centred on now; peaks and chips outside the view are hinted at the column edges.
 await expect(w.locator('.wk-hints i.down').first()).toHaveText('↓ GLM 5h 15:50');
 await expect(w.locator('.wk-hints i.down',{hasText:'↓ GLM peak 22:00'})).toHaveCount(2);
 await expect(w.locator('.wk-pk b').first()).toHaveText('Claude peak');
 await shot(page,'E3-week-zoom',page.locator('.ck-deck'));
 await sc.evaluate(e=>{e.scrollTop=0;e.dispatchEvent(new Event('scroll'));});
 await expect(w.locator('.wk-hints i.down').first()).toBeVisible();
 // ⌘− steps back out; ⌘0 fits.
 await page.keyboard.press('Meta+-');expect(await sc.evaluate(e=>Math.round(e.scrollHeight/e.clientHeight*10))).toBe(20);
 await page.keyboard.press('Meta+0');await expect(w).toHaveClass(/fit/);
 // Pinch (ctrl + wheel) zooms in.
 await sc.hover();await page.keyboard.down('Control');await page.mouse.wheel(0,-40);await page.keyboard.up('Control');
 await expect(w).toHaveClass(/zoom/);
 // Close and reopen: whole day again.
 await page.keyboard.press('Escape');await expect(screen(page)).toHaveCount(0);await k.click();
 await expect(w).toHaveClass(/fit/);await expect(w.locator('.wk-zoom')).toBeHidden();
});

test('D328 a day pressed in the week view swaps the column\'s bottom line to that day\'s events',async({page})=>{
 await open(page,{locale:'zh-CN'});
 const w=weekView(page),foot=column(page).locator('.pl-foot');
 await key(page).click();
 await expect(page.locator('.mfd-pk .pk-seg .cur')).toHaveText('日历');
 await w.locator('.wk-dh').nth(1).click();
 await expect(w.locator('.wk-dh').nth(1)).toHaveAttribute('aria-pressed','true');
 await expect(foot.locator('.pl-foot-l')).toHaveText('11/12 周四');await expect(foot.locator('.pl-foot-v')).toHaveText('Claude 高峰 05:00 · Claude 周 09:00 · GLM 高峰 22:00');
 await w.locator('.wk-col').nth(4).click({position:{x:10,y:20}});
 await expect(foot.locator('.pl-foot-l')).toHaveText('11/15 周日');await expect(foot.locator('.pl-foot-v')).toHaveText('暂无');
 // The strip itself does not change (it is always the next 12 hours) and the screen stays open.
 // G3-179: the abbreviation dropped (the time is the fact); the tooltip still names GLM.
 await expect(strip(page).locator('.cal-pk b')).toHaveText(['22:00–02:00']);
 await expect(strip(page).locator('.cal-pk')).toHaveAttribute('title',/GLM/);
 await expect(screen(page)).toBeVisible();
 // Today restores the default line.
 await w.locator('.wk-dh').first().click();
 await expect(foot.locator('.pl-foot-l')).toHaveAttribute('data-full','下个高峰');
});

test('calendar data is checked against the plugin shape and size bound; the display data is shaped on the page',async({page})=>{
 const data=dataWith(2);
 // The user's own 5-hour reset from the current session window; nothing pushed by the host.
 const deadline=new Date(NOW+3600e3).toISOString();
 for(const row of data.projection.rows)for(const a of row.accounts){a.valueState='current';a.freshUntil=deadline;for(const w of a.windows){w.current=true;w.validUntil=deadline;w.resetsAt=new Date(L(0,13)).toISOString();}}
 const {send,receive}=await open(page,{data,push:null});
 const s=strip(page);
 // No peak data yet (D328): the D293 cells show the reset; the strip is not drawn.
 await expect(column(page).locator('.pl-draw')).toHaveCount(0);
 await expect(column(page)).toContainText(/13:00in 1h40(Codex|Tool \d) 5h/);
 // Bad shapes and oversized data are refused and change nothing.
 const bad=[{...week,extra:1},{...week,version:2},{...week,peaks:[{sub:9,from:NOW,to:null,tentative:false}]},{...week,resets:[{sub:0,at:NOW,kind:'month'}]},{...week,subs:[{...week.subs[0],colour:'red'}]},{...week,resets:Array.from({length:65},()=>({sub:0,at:NOW,kind:'5h'}))}];
 for(const d of bad)expect(await receive(send('pluginData',{id:'calendar',data:d}))).toBe(false);
 // Over the 16 KiB bound: refused before the shape check runs.
 const big={...week,subs:[{...week.subs[0],name:{en:'x'.repeat(20000),zh:'y'}}]};
 expect(await receive(send('pluginData',{id:'calendar',data:big}))).toBe(false);
 await expect(column(page)).toContainText(/13:00in 1h40(Codex|Tool \d) 5h/);
 // A valid host push takes over from the page's own shaping.
 expect(await receive(send('pluginData',{id:'calendar',data:week}))).toBe(true);
 await expect(s.locator('.cal-ch')).toHaveCount(3);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(s.locator('.cal-ch')).toHaveCount(3);
});

test('an older host (no plugin state) still shows the v1 table: default-on plugins wait for the host',async({page})=>{
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.webkit={messageHandlers:{cockpit:{postMessage(){}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance,shell,redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(2)}))).toBe(true);
 await expect(page.locator('.eng-cols .pl-col')).toHaveCount(0);
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','3');
});

// --- macrevc-844 findings -----------------------------------------------------------------------------------------
test('macrevc-844-2: a cleared host reading does not come back when the next display arrives (host-fed takeover ends at the barrier)',async({page})=>{
 const {send,receive}=await open(page);
 await expect(strip(page).locator('.cal-ch')).toHaveCount(3);
 expect(await receive(send('clear',{viewRevision:'4'}))).toBe(true);
 expect(await receive(send('display',{viewRevision:'4',data:dataWith(4)}))).toBe(true);
 const col=column(page);
 await expect(col.locator('.cal-ch')).toHaveCount(0);
 await expect(col).not.toContainText('GL');
 // The new display is shaped afresh (no peak feed in this older-engine sample: unknown, never "No rules").
 await expect(col.locator('.pl-foot .pl-foot-v')).toHaveText('No data');
});

test('macrevc-844-3: a peak through the fall-back repeated hour is a visible block in the week view',async({page})=>{
 const at=Date.parse('2026-11-01T10:00:00-08:00');
 const fall={...week,peaks:[{sub:2,from:Date.parse('2026-11-01T01:30:00-07:00'),to:Date.parse('2026-11-01T01:15:00-08:00'),tentative:false}],resets:[],spans:[]};
 await open(page,{at,push:fall});
 await key(page).click();
 const block=weekView(page).locator('.wk-pk');
 await expect(block).toHaveCount(1);
 const style=await block.evaluate(e=>({h:parseFloat(e.style.height),t:parseFloat(e.style.top),box:e.getBoundingClientRect().height}));
 expect(style.h).toBeGreaterThan(0);expect(style.box).toBeGreaterThan(2);
 expect(Math.abs(style.t-1.5/24*100)).toBeLessThan(0.1);
});

test('macrevc-844-4/5/6: unknown peaks, a partial card count and an unknown card expiry are never shown as facts',async({page})=>{
 const noRulesNoCards={...week,peakRules:'unknown',peaks:[],resets:[{sub:0,at:L(0,14,10),kind:'5h'}],spans:[{sub:0,kind:'cards',from:NOW,to:null,count:null}]};
 await open(page,{push:noRulesNoCards});
 const col=column(page);
 await expect(col.locator('.pl-foot .pl-foot-v')).toHaveText('No data');
 await expect(col).not.toContainText('No rules');
 await expect(col).not.toContainText(/1969|1970|12\/31|×/);
 await key(page).click();
 const bar=weekView(page).locator('.wk-adr');
 await expect(bar).toHaveCount(1);
 await expect(weekView(page)).not.toContainText(/1969|1970|12\/31/);
});

test('macrevc-844-8: through the bridge, the earliest card expiring at the host tick leaves the live cards shown without a total or date',async({page})=>{
 const data=dataWith(4),iso=t=>new Date(t).toISOString(),first=NOW+60_000,later=NOW+3*3_600_000;
 data.details=capture().details;data.details.peaks=[];data.details.resetEvents=[];
 Object.assign(data.details.subscriptions[0].resetCards,{state:'partial',truncated:true,count:65,earliestExpiresAt:iso(first),items:Array.from({length:64},(_,i)=>({id:String(i).padStart(64,'a'),expiresAt:iso(i?later:first)}))});
 const {send,receive}=await open(page,{data,push:null});
 await expect(column(page)).toContainText('Banked');await expect(column(page)).toContainText(/until \d+\/\d+/);
 expect(await receive(send('tick',{nowUnixMs:String(NOW+120_000),reason:'deadline'}))).toBe(true);
 await expect(column(page)).toContainText('Banked');
 await expect(column(page)).not.toContainText(/×|until|\d+\/\d+/);
});

// D375: names, not codes; the big time; two distinct moments (or one); colour always beside the name.
const bothOn={version:1,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:true,pinned:false}],settings:{}};
async function openWith(page,{count,push,locale='zh-CN',at=NOW,plugins=bothOn}) {
 await page.clock.setFixedTime(new Date(at));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,tier:'tall'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins}))).toBe(true);
 expect(await receive(send('display',{data:dataWith(count)}))).toBe(true);
 expect(await receive(send('pluginData',{id:'calendar',data:push}))).toBe(true);
 return {send,receive};
}
test('D375 3 columns, no peak rules: big time, the subscription colour mark with its full name, no code',async({page})=>{
 const codexOnly={version:1,peakRules:'no',subs:[week.subs[1]],peaks:[],resets:[{sub:0,at:L(0,14,10),kind:'5h'},{sub:0,at:L(2,6),kind:'week'}],spans:[]};
 const {send,receive}=await openWith(page,{count:1,push:codexOnly});
 const col=column(page);
 await expect(col.locator('.pl-big')).toHaveText(['14:10','06:00']);
 await expect(col.locator('.pl-sub .pl-subt')).toHaveText(['Codex 5 小时','Codex 每周 · 11/13 周五']);
 await expect(col.locator('.pl-sub .pl-sw').first()).toHaveCSS('background-color','rgb(106, 168, 255)');
 expect(await col.innerText()).not.toMatch(/\b(CX|CL|GL|CU)\b/);
 await expect(col.locator('.pl-foot .pl-foot-v')).toHaveText('没有时段规则');
 await shot(page,'N-3col-no-rules-zh',page.locator('.ck-eng'));
 // The next reset is the weekly one (nothing to read for the 5 h window): written once.
 const only={...codexOnly,resets:[{sub:0,at:L(0,12,30),kind:'week'}]};
 expect(await receive(send('pluginData',{id:'calendar',data:only}))).toBe(true);
 await expect(col.locator('.pl-big')).toHaveText(['12:30']);
 await expect(col.locator('.pl-sub .pl-subt')).toHaveText(['Codex 每周']);
 await shot(page,'N-3col-same-moment-zh',page.locator('.ck-eng'));
});
test('D375 3 columns with a peak day strip, and 6 columns: names beside colours, the window dropped when narrow',async({page})=>{
 const two={...week,subs:[week.subs[1],week.subs[2]],peaks:[{sub:1,from:L(0,22),to:L(1,2),tentative:false}],resets:[{sub:0,at:L(0,23,10),kind:'5h'},{sub:1,at:L(0,21,40),kind:'5h'}],spans:[]};
 await openWith(page,{count:2,push:two,locale:'zh-CN',plugins:{...bothOn,entries:[{id:'calendar',enabled:true,pinned:false},{id:'resources',enabled:false,pinned:false}]}});
 await expect(strip(page).locator('.cal-ch')).toHaveText(['Codex 5h 23:10','GLM 5h 21:40']);
 await expect(strip(page).locator('.cal-pk b')).toHaveText(['GLM 22:00–02:00']);
 await shot(page,'N-3col-peaks-zh',page.locator('.ck-eng'));
});
test('D375 6 columns: chips drop the window, keep the name',async({page})=>{
 await openWith(page,{count:4,push:week,locale:'zh-CN'});
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','6');
 await expect(strip(page).locator('.cal-ch')).toHaveText(['Claude 12:30','Codex 14:10','GLM 15:50']);
 expect(await strip(page).innerText()).not.toMatch(/\b(CX|CL|GL|CU)\b/);
 await shot(page,'N-6col-zh',page.locator('.ck-eng'));
});

test('D406 banked resets: an undated +1 chip on its published day, a dated one on its own day, a direct reset is ↻ not +1',async({page})=>{
 const push={...week,spans:[{sub:1,kind:'credit',from:NOW,to:null,count:1},{sub:0,kind:'credit',from:L(3,8),to:L(3,8),count:1},{sub:2,kind:'announced',from:NOW,to:null,count:null}]};
 const {send,receive}=await open(page,{push,locale:'zh-CN'});
 await key(page).click();
 const w=weekView(page);
 await expect(w.locator('.wk-adr.chip')).toHaveText(['+1','+1','↻']);
 const left=async n=>(await w.locator('.wk-adr.chip').nth(n).boundingBox()).x;
 const heads=await w.locator('.wk-dh').evaluateAll(es=>es.map(e=>e.getBoundingClientRect()));
 const day=x=>heads.findIndex(h=>x>=h.x-1&&x<h.x+h.width);
 expect([day(await left(0)),day(await left(1)),day(await left(2))]).toEqual([0,3,0]);
 await expect(w.locator('.wk-adr.chip.direct.pending')).toHaveAttribute('title',/预告重置/);
 await expect(w.locator('.wk-adr.chip.credit').first()).toHaveAttribute('title',/\+1 额外重置/);
 await expect(w.locator('.wk-adr.chip.credit')).toHaveCount(2);
 await expect(w.locator('.wk-adr.chip.direct.pending')).toHaveText('↻');
 await expect(w.locator('.wk-adr.chip.direct')).not.toContainText('+1');
 await shot(page,'reset-chip',screen(page));
});

test('D406 a reset-card notice published 2 days ago is not placed on today in the week; the column line still carries it',async({page})=>{
 const push={...week,spans:[{sub:1,kind:'credit',from:L(-2,9),to:null,count:1}]};
 await open(page,{push});
 await expect(strip(page).locator('.cal-adr')).toHaveText(/Codex \+1 Banked reset/);
 await key(page).click();
 await expect(weekView(page).locator('.wk-adr.chip')).toHaveCount(0);
});

test('D406 review: with no peak rules a current reset notice still gets the all-day line; announced is dashed, confirmed solid',async({page})=>{
 const codexOnly={...week,peakRules:'no',subs:[week.subs[1]],peaks:[],resets:[{sub:0,at:L(0,14,10),kind:'5h'}],spans:[{sub:0,kind:'credit',from:L(-2,9),to:null,count:1}]};
 await open(page,{push:codexOnly});
 await expect(strip(page).locator('.cal-adr')).toHaveText(/\+1 Banked reset/);
 const two={...codexOnly,spans:[{sub:0,kind:'credit',from:NOW,to:null,count:1},{sub:0,kind:'creditConfirmed',from:L(1,9),to:L(1,9),count:1}]};
 await page.evaluate(()=>0);
 const {send,receive}=await open(page,{push:two});
 await key(page).click();
 await expect(weekView(page).locator('.wk-adr.chip.credit.pending')).toHaveCount(1);
 await expect(weekView(page).locator('.wk-adr.chip.credit:not(.pending)')).toHaveCount(1);
});
