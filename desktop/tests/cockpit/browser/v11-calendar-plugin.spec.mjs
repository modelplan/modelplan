// SPDX-License-Identifier: MIT
// v1.1 calendar plugin (owner D137, D138, D140, D141, D145; CKP-PLG-06, CKP-PLG-07): the column's day view and the
// 7-day week view that opens as a temporary overlay inside the MFD screen. Times are local (America/Los_Angeles here).
// Set CAL_SHOTS=<dir> to also write review screenshots.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
test.use({timezoneId:'America/Los_Angeles'});
test.beforeEach(async({page})=>excludePortholeFlicker(page));

// Pacific standard time in November 2026: local = UTC-8. Day 0 = Wednesday 11/11; now = 11:20.
const L=(day,h,m=0)=>Date.UTC(2026,10,11+day,h+8,m);
const NOW=L(0,11,20);
const shots=process.env.CAL_SHOTS;
const shot=async(page,name,target=page)=>{if(shots)await target.screenshot({path:`${shots}/${name}.png`});};
const calendarOn={version:1,entries:[{id:'calendar',enabled:true,pinned:false}],settings:{}};
// The mockup's sample week: four subscriptions, GLM's 22:00–02:00 peak crossing midnight, own resets, a reset card and
// an announced GLM reset taking effect on Monday 11/16.
const week={version:1,
 subs:[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}},{abbr:'CU',colour:'#eef2f6',name:{en:'Cursor',zh:'Cursor'}}],
 peaks:[{sub:0,from:L(0,5),to:L(0,11),tentative:false},{sub:2,from:L(0,22),to:L(1,2),tentative:false},{sub:0,from:L(1,5),to:L(1,11),tentative:false},{sub:2,from:L(1,22),to:L(2,2),tentative:false},{sub:0,from:L(2,5),to:L(2,11),tentative:false},{sub:0,from:L(5,5),to:L(5,11),tentative:false},{sub:2,from:L(5,22),to:L(6,2),tentative:false}],
 resets:[{sub:0,at:L(0,12,30),kind:'5h'},{sub:1,at:L(0,14,10),kind:'5h'},{sub:2,at:L(0,15,50),kind:'5h'},{sub:0,at:L(1,9),kind:'week'},{sub:1,at:L(2,6),kind:'week'}],
 spans:[{sub:0,kind:'cards',from:NOW,to:L(2,18),count:1},{sub:2,kind:'announced',from:L(-1,10),to:L(5,0),count:null}]};
function dataWith(count) {
 const data=sample(),seed=data.projection.rows[1];
 data.projection.rows=[data.projection.rows[0],...Array.from({length:count-1},(_,i)=>{const row=structuredClone(seed);row.id=`tool-${i+2}`;row.name={en:`Tool ${i+2}`,zh:`工具 ${i+2}`};row.order=i+2;return row;})];
 return data;
}
async function open(page,{data=dataWith(4),tier='tall',locale='en',push=week}={}) {
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.__events=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__events.push(JSON.parse(raw));}}}};});
 if(tier==='compact')await page.setViewportSize({width:636,height:640});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,tier},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('plugins',{plugins:calendarOn}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 if(push)expect(await receive(send('pluginData',{id:'calendar',data:push}))).toBe(true);
 return {send,receive};
}
const strip=page=>page.locator('.eng-cols .pl-col[data-plugin="calendar"] .pl-panel');
const overlay=page=>page.locator('.dk-mfd .mfd-screen .pl-ovl[data-plugin="calendar"]');
const deadlines=page=>page.evaluate(()=>window.__events.filter(e=>e.type==='nextDeadline').map(e=>e.deadlineUnixMs));

test('CKP-PLG-06 day view: picker with dots, all-day lane, 36 h axis from now, peaks, own resets, now line, folded line',async({page})=>{
 await open(page);
 // Default on (D121) once the host knows plugins: 4 subscriptions + the calendar = 5 equal columns.
 await expect(page.locator('.eng-keys')).toHaveAttribute('data-slots','5');
 const col=page.locator('.eng-cols .pl-col[data-plugin="calendar"]'),sub=page.locator('.eng-cols .ec[data-col]').first();
 const [a,b]=[await col.boundingBox(),await sub.boundingBox()];expect(Math.abs(a.width-b.width)).toBeLessThan(2);
 await expect(page.locator('.eng-keys .pl-key .ek-name')).toHaveText('Calendar');
 const s=strip(page);
 await expect(s.locator('.cal-d b')).toHaveText(['11','12','13']);
 await expect(s.locator('.cal-d s.on')).toHaveCount(3);
 await expect(s.locator('.cal-d').first()).toHaveAttribute('aria-pressed','true');
 await expect(s.locator('.cal-ts')).toHaveText('Now 11:20');
 await expect(s.locator('.cal-adr')).toHaveText(['CL reset card · until 11/13','GL announced reset · 11/16']);
 await expect(s.locator('.cal-adr.line')).toHaveClass(/before/);await expect(s.locator('.cal-adr.line')).toHaveClass(/after/);
 // 11:20 + 36 h = Thu 23:20: one midnight divider, GLM's peak crosses it as one block, CL's Thursday peak below.
 await expect(s.locator('.cal-mid b')).toHaveText(['Thu 11/12']);
 await expect(s.locator('.cal-pk b')).toHaveText(['GL peak','CL peak','GL peak']);
 await expect(s.locator('.cal-pk').first()).toHaveAttribute('title','GL peak 22:00–02:00');
 const [glm,mid]=[await s.locator('.cal-pk').first().boundingBox(),await s.locator('.cal-mid').boundingBox()];
 expect(glm.y).toBeLessThan(mid.y);expect(glm.y+glm.height).toBeGreaterThan(mid.y);
 await expect(s.locator('.cal-ch')).toHaveText(['CL 5h 12:30','CX 5h 14:10','GL 5h 15:50','CL weekly Tmr 09:00']);
 // Chips never overlap.
 const boxes=await s.locator('.cal-ch').evaluateAll(es=>es.map(e=>{const r=e.getBoundingClientRect();return [r.top,r.bottom];}));
 for(let i=1;i<boxes.length;i++)expect(boxes[i][0]).toBeGreaterThanOrEqual(boxes[i-1][1]);
 await expect(s.locator('.cal-nl')).toHaveCount(1);
 // Beyond 36 h: Codex's weekly reset Friday 06:00, then the announced GLM reset: one folded line, a press lists both.
 await expect(s.locator('.cal-fold')).toHaveText('▾ 11/13 CX weekly 06:00 · +1');
 await s.locator('.cal-fold').click();
 await expect(s.locator('.cal-more li')).toHaveText(['11/13 CX weekly 06:00','11/16 GL announced reset · 11/16']);
 await expect(overlay(page)).toHaveCount(0);// the fold is the plugin's own control, not the expand click
 await shot(page,'A-strip-en',page.locator('.ck-eng'));
});

test('CKP-PLG-06 Chinese labels and the 明 day view (00–24 with ↺ 现在)',async({page})=>{
 await open(page,{locale:'zh-CN'});
 const s=strip(page);
 await expect(s.locator('.cal-d i')).toHaveText(['今','明','后']);
 await expect(s.locator('.cal-ts')).toHaveText('现在 11:20');
 await expect(s.locator('.cal-adr')).toHaveText(['CL 重置卡 至11/13','GL 预告重置 · 11/16 生效']);
 await expect(s.locator('.cal-ch').last()).toHaveText('CL 周重置 明09:00');
 await expect(s.locator('.cal-fold')).toHaveText('▾ 11/13 CX 周重置 06:00 · +1');
 await shot(page,'A-strip-zh',page.locator('.ck-eng'));
 await s.getByRole('button',{name:'11/12 周四'}).click();
 await expect(s).toHaveAttribute('data-view','1');
 await expect(s.locator('.cal-ts')).toHaveText('11/12 周四');
 await expect(s.locator('.cal-back')).toHaveText('↺ 现在');
 await expect(s.locator('.cal-nl')).toHaveCount(0);
 await expect(s.locator('.cal-mid')).toHaveCount(0);
 // GLM's Wednesday-night peak continues into Thursday; Thursday's own 22:00 one runs past the end of the day.
 await expect(s.locator('.cal-pk b')).toHaveText(['GL 高峰（续）','CL 高峰','GL 高峰']);
 await expect(s.locator('.cal-ch')).toHaveText(['CL 周重置 09:00']);
 await expect(s.locator('.cal-g i').first()).toHaveText(/^0[36]$/);
 await shot(page,'C-strip-tomorrow-zh',page.locator('.ck-eng'));
 await s.locator('.cal-back').click();
 await expect(s).toHaveAttribute('data-view','now');await expect(s.locator('.cal-ts')).toHaveText('现在 11:20');
 // Neither picker press nor ↺ opened the overlay.
 await expect(overlay(page)).toHaveCount(0);
});

test('host minute tick: the now line moves and the day rolls over without page timers',async({page})=>{
 const {send,receive}=await open(page);
 // The page asks for the next whole minute (the earliest of its own deadlines and the running plugin's).
 expect((await deadlines(page)).at(-1)).toBe(String(L(0,11,21)));
 expect(await receive(send('tick',{nowUnixMs:String(L(0,11,21)),reason:'deadline'}))).toBe(true);
 const s=strip(page);
 await expect(s.locator('.cal-ts')).toHaveText('Now 11:21');
 expect((await deadlines(page)).at(-1)).toBe(String(L(0,11,22)));
 // Pick tomorrow, then midnight passes: tomorrow is today now, so the strip returns to the now view.
 await s.locator('.cal-d').nth(1).click();await expect(s).toHaveAttribute('data-view','1');
 expect(await receive(send('tick',{nowUnixMs:String(L(1,0,1)),reason:'deadline'}))).toBe(true);
 await expect(s).toHaveAttribute('data-view','now');
 await expect(s.locator('.cal-d b')).toHaveText(['12','13','14']);
 await expect(s.locator('.cal-ts')).toHaveText('Now 00:01');
 // Stopped (occluded) plugins ask for no ticks.
 expect(await receive(send('visibility',{visible:true,occluded:true,key:false}))).toBe(true);
 expect(await page.evaluate(()=>window.modelPlanCockpit&&document.querySelector('.pl-panel[data-plugin="calendar"]').dataset.running)).toBe('false');
});

test('CKP-PLG-07 week overlay opens inside the MFD screen only; plugin click, ×, Esc, back and a page key close it',async({page})=>{
 await open(page);
 const col=page.locator('.eng-cols .pl-col[data-plugin="calendar"]');
 await col.locator('.cal-ax').click();
 const o=overlay(page);await expect(o).toBeVisible();
 await expect(col).toHaveAttribute('aria-expanded','true');
 // Inside the screen, never over the faders, the page keys or the option keys.
 const [ob,sb]=[await o.boundingBox(),await page.locator('.dk-mfd .mfd-screen').boundingBox()];
 expect(ob.x>=sb.x&&ob.y>=sb.y&&ob.x+ob.width<=sb.x+sb.width+0.5&&ob.y+ob.height<=sb.y+sb.height+0.5).toBe(true);expect(ob.width).toBeGreaterThan(sb.width-6);
 for(const sel of ['.dk-mfd .mfd-pk','.dk-mfd .mfd-ok','.fd-chs']){const r=await page.locator(sel).boundingBox();expect(r.y+r.height<=ob.y+0.5||r.y>=ob.y+ob.height-0.5||r.x+r.width<=ob.x+0.5,sel).toBe(true);}
 const pk=await page.locator('.dk-mfd .mfd-pk .pk').nth(1).boundingBox();
 expect(await page.evaluate(([x,y])=>!!document.elementFromPoint(x,y)?.closest('.mfd-pk'),[pk.x+pk.width/2,pk.y+pk.height/2])).toBe(true);
 await expect(o.locator('.po-t')).toHaveText('Calendar · 7 days');
 await expect(o.locator('.po-back')).toHaveText('‹ Back to Overview');
 await expect(o.locator('.wk-dh b')).toHaveText(['11','12','13','14','15','16','17']);
 await expect(o.locator('.wk-dh.we')).toHaveCount(2);await expect(o.locator('.wk-col.we')).toHaveCount(2);
 await expect(o.locator('.wk-dh.today')).toHaveCount(1);
 await expect(o.locator('.wk-adr')).toHaveCount(2);
 await expect(o.locator('.wk-ch')).toHaveText(['CL 5h 12:30','CX 5h 14:10','GL 5h 15:50','CL wk 09:00','CX wk 06:00']);
 await expect(o.locator('.wk-nt')).toHaveText('11:20');
 // Whole day fitted: no scrolling.
 expect(await o.locator('.wk-sc').evaluate(e=>e.scrollHeight<=e.clientHeight+1)).toBe(true);
 await shot(page,'E3-week-fit',page.locator('.ck-deck'));
 // Plugin click again closes.
 await col.locator('.cal-ax').click();await expect(o).toHaveCount(0);await expect(col).toHaveAttribute('aria-expanded','false');
 // ×
 await col.locator('.cal-ax').click();await o.locator('.po-x').click();await expect(o).toHaveCount(0);
 // Esc (and focus returns to the column)
 await col.locator('.cal-ax').click();await page.keyboard.press('Escape');await expect(o).toHaveCount(0);await expect(col).toBeFocused();
 // ‹ Back
 await col.locator('.cal-ax').click();await o.locator('.po-back').click();await expect(o).toHaveCount(0);
 // An MFD page key closes it and shows that page.
 await col.locator('.cal-ax').click();await expect(o).toBeVisible();
 await page.locator('.dk-mfd .mfd-pk .pk').nth(2).click();
 await expect(o).toHaveCount(0);
 await expect(page.locator('.dk-mfd .mfd-pk .pk').nth(2)).toHaveAttribute('aria-pressed','true');
 // The faders stayed usable with the overlay open: open again and press a fader bank key area (no overlay change).
 await col.locator('.cal-ax').click();await expect(o.locator('.po-back')).toHaveText('‹ Back to Effort');
 // Keyboard: the column is a control (Enter toggles).
 await page.keyboard.press('Escape');await col.focus();await page.keyboard.press('Enter');await expect(o).toBeVisible();await page.keyboard.press('Enter');
});

test('CKP-PLG-07 zoom: ⌘+ / pinch to about 8 h with a scrollbar and edge hints; every open starts fitted',async({page})=>{
 await open(page);
 const col=page.locator('.eng-cols .pl-col[data-plugin="calendar"]'),o=overlay(page);
 await col.locator('.cal-ax').click();
 for(let i=0;i<3;i++)await page.keyboard.press('Meta+=');
 await expect(o.locator('.po-b')).toHaveClass(/zoom/);
 await expect(o.locator('.po-st')).toHaveText('Zoomed · ⌘− to fit');
 const sc=o.locator('.wk-sc');
 expect(await sc.evaluate(e=>Math.round(e.scrollHeight/e.clientHeight))).toBe(3);// 24 h / 8 h
 // Centred on now; peaks and chips outside the view are hinted at the column edges.
 await expect(o.locator('.wk-hints i.down').first()).toHaveText('↓ GL 5h 15:50');
 await expect(o.locator('.wk-hints i.down',{hasText:'↓ GL peak 22:00'})).toHaveCount(2);
 await expect(o.locator('.wk-pk b').first()).toHaveText('CL peak');
 await shot(page,'E3-week-zoom',page.locator('.ck-deck'));
 await sc.evaluate(e=>{e.scrollTop=0;e.dispatchEvent(new Event('scroll'));});
 await expect(o.locator('.wk-hints i.down').first()).toBeVisible();
 // ⌘− steps back out; ⌘0 fits.
 await page.keyboard.press('Meta+-');expect(await sc.evaluate(e=>Math.round(e.scrollHeight/e.clientHeight*10))).toBe(20);
 await page.keyboard.press('Meta+0');await expect(o.locator('.po-b')).toHaveClass(/fit/);
 // Pinch (ctrl + wheel) zooms in.
 await sc.hover();await page.keyboard.down('Control');await page.mouse.wheel(0,-40);await page.keyboard.up('Control');
 await expect(o.locator('.po-b')).toHaveClass(/zoom/);
 // Close and reopen: whole day again.
 await page.keyboard.press('Escape');await col.locator('.cal-ax').click();
 await expect(o.locator('.po-b')).toHaveClass(/fit/);await expect(o.locator('.po-st')).toHaveText('');
});

test('CKP-PLG-07 a day pressed in the week view moves the strip to that day',async({page})=>{
 await open(page,{locale:'zh-CN'});
 const col=page.locator('.eng-cols .pl-col[data-plugin="calendar"]'),o=overlay(page),s=strip(page);
 await col.locator('.cal-ax').click();
 await expect(o.locator('.po-t')).toHaveText('日历 · 7 天');
 await expect(o.locator('.po-back')).toHaveText('‹ 返回 总览');
 await o.locator('.wk-dh').nth(1).click();
 await expect(s).toHaveAttribute('data-view','1');await expect(o.locator('.wk-dh').nth(1)).toHaveAttribute('aria-pressed','true');
 await o.locator('.wk-col').nth(4).click({position:{x:10,y:20}});
 await expect(s).toHaveAttribute('data-view','4');await expect(s.locator('.cal-ts')).toHaveText('11/15 周日');
 await expect(s.locator('.cal-d[aria-pressed="true"]')).toHaveCount(0);
 await expect(o).toBeVisible();
 await o.locator('.wk-dh').first().click();await expect(s).toHaveAttribute('data-view','now');
});

test('640 layout keeps seven narrow columns',async({page})=>{
 await open(page,{tier:'compact',locale:'zh-CN'});
 await page.locator('.eng-cols .pl-col[data-plugin="calendar"] .cal-ax').click();
 const o=overlay(page);await expect(o).toBeVisible();
 await expect(o.locator('.po-b')).toHaveClass(/narrow/);
 await expect(o.locator('.wk-dh i')).toHaveText(['三','四','五','六','日','一','二']);
 await expect(o.locator('.wk-col')).toHaveCount(7);
 await shot(page,'E3-week-640',page.locator('.ck-deck'));
});

test('calendar data is checked against the plugin shape and size bound; the display data is shaped on the page',async({page})=>{
 const data=dataWith(2);
 // The user's own 5-hour reset from the current session window; nothing pushed by the host.
 const deadline=new Date(NOW+3600e3).toISOString();
 for(const row of data.projection.rows)for(const a of row.accounts){a.valueState='current';a.freshUntil=deadline;for(const w of a.windows){w.current=true;w.validUntil=deadline;w.resetsAt=new Date(L(0,13)).toISOString();}}
 const {send,receive}=await open(page,{data,push:null});
 const s=strip(page);
 await expect(s.locator('.cal-ch')).toHaveCount(2);
 await expect(s.locator('.cal-ch').first()).toHaveText(/^(CX|TO) 5h 13:00$/);
 // Bad shapes and oversized data are refused and change nothing.
 const bad=[{...week,extra:1},{...week,version:2},{...week,peaks:[{sub:9,from:NOW,to:null,tentative:false}]},{...week,resets:[{sub:0,at:NOW,kind:'month'}]},{...week,subs:[{...week.subs[0],colour:'red'}]},{...week,resets:Array.from({length:65},()=>({sub:0,at:NOW,kind:'5h'}))}];
 for(const d of bad)expect(await receive(send('pluginData',{id:'calendar',data:d}))).toBe(false);
 // Over the 16 KiB bound: refused before the shape check runs.
 const big={...week,subs:[{...week.subs[0],name:{en:'x'.repeat(20000),zh:'y'}}]};
 expect(await receive(send('pluginData',{id:'calendar',data:big}))).toBe(false);
 await expect(s.locator('.cal-ch')).toHaveCount(2);
 // A valid host push takes over from the page's own shaping.
 expect(await receive(send('pluginData',{id:'calendar',data:week}))).toBe(true);
 await expect(s.locator('.cal-ch')).toHaveCount(4);
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(s.locator('.cal-ch')).toHaveCount(4);
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
