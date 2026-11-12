// SPDX-License-Identifier: MIT
// Owner build 13 (CKP-MFD, study views.js round D1): trying an effort on a fader shows "Compare · <model>" on the
// MFD: the ability / cost share bars and the share chart (CKP-MFD-33, v8), the effort keys, the website links,
// "‹ back" and the fast key. The built page through its normal bridge; synthetic profile only.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {readFileSync} from 'node:fs';
import {build13Profile,SESSION_REF} from '../build13-fixture.mjs';
// Cut from the real /v1/client shape (data.speedTiers), the same file the module-level unit test reads.
// The producer's wire tier drops the client-only reviewedAt, so the delivered cut does too.
const speedTiers=JSON.parse(readFileSync(new URL('../unit/client-speed-tiers.fixture.json',import.meta.url),'utf8')).data.speedTiers.map(({reviewedAt,...tier})=>tier);

test.beforeEach(async({page})=>excludePortholeFlicker(page));
async function open(page,locale='en',tiers=false,edit=null){
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
 edit?.(data);
 expect(await receive(send('display',{data}))).toBe(true);
}
const sol=page=>page.locator('.fd-ch:not(.empty)').first();
// The numbers under the two bars, per bar: [[role, text], ...] (v8: shares of the top effort).
const cells=page=>page.locator('.mfd-page svg.cmp-bars').evaluate(svg=>[...svg.querySelectorAll('.pc-bar')].map(g=>[...g.querySelectorAll('.pc-num')].map(n=>[n.dataset.role,n.textContent])));

test('CKP-MFD compare: a fader trial opens the comparison with the two share bars, the chart and keys',async({page})=>{
 await open(page);
 await expect(page.locator('.mfd-page')).not.toHaveClass(/pg-compare/);
 await sol(page).locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
 await expect(screen.locator('.mfd-title')).toHaveText('Compare · Sol 6.1');
 // Sol: current High, trial XHigh, top effort Max (ability 47.5, cost 1.056).
 expect(await cells(page)).toEqual([[['current','90%'],['trial','97%']],[['current','36%'],['trial','60%']]]);
 await expect(screen.locator('svg.cmp-bars .pc-label')).toHaveText(['Ability','Cost']);
 await expect(screen.locator('svg.cmp-chart .pc-line')).toHaveCount(3);
 await expect(screen.locator('.cmp-lad .lad')).toHaveText(['Low','★Med','High','XHigh','Max']);
 await expect(screen.locator('.cmp-lad .lad.try')).toHaveText('XHigh');
 // The keys sit under the chart's columns: the shared left edge after the English bar labels (demo v8: 50 px).
 expect(await screen.locator('.cmp-lad').evaluate(e=>getComputedStyle(e).paddingLeft)).toBe('50px');
 // The study drops "How it's worked out" when the English header has no room for it; the compare link always shows.
 await expect(screen.locator('.cmp-header-links a').first()).toHaveText('Compare on the website ↗');
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
 expect((await cells(page))[0][1]).toEqual(['trial','100%']);
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
 const before=(await cells(page))[1];
 await key.click();await expect(key).toHaveAttribute('aria-pressed','true');
 await expect(sol.locator('.fd-indicator')).toHaveAttribute('data-fast-mode','try');
 const after=(await cells(page))[1];expect(after).not.toEqual(before);
 await key.click();await expect(key).toHaveAttribute('aria-pressed','false');
 await back();
 // A model the published tiers do not list (Astra here carries an id they do not name) keeps the key dark.
 await trial('Astra');
 await expect(page.locator('.mfd-vk button.vk-fast')).toHaveCount(0);
 await expect(page.locator('.mfd-vk span.vk-fast')).toHaveClass(/off/);
 await back();
 // Unstated ratio (Terra): the key shows; switching it on still prices the trial (the cost share grows by the
 // subscription ratio). Its unknown time is covered by the unit test of the share helper (speed-tiers.test.mjs).
 await trial('Terra');
 await expect(key).toHaveCount(1);await expect(key).toContainText(/off/i);
 const tBefore=(await cells(page))[1].find(([r])=>r==='trial')[1];
 await key.click();await expect(key).toHaveAttribute('aria-pressed','true');
 const tAfter=(await cells(page))[1].find(([r])=>r==='trial')[1];
 expect(parseInt(tAfter)/parseInt(tBefore)).toBeCloseTo(2.5,0);
});

test('CKP-FAD-11 fast key: Chinese key reads 关｜开',async({page})=>{
 await open(page,'zh-CN',true);
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-travel').focus();await page.keyboard.press('ArrowUp');
 const key=page.locator('.mfd-vk button.vk-fast');
 await expect(key).toContainText('关');await expect(key).toContainText('开');
});

// CKP-FAD-11 / CKP-MFD-19 (audit B finding 2): the producer's observed Fast mode (details.sessions[].fast) reaches the
// comparison through the ordinary bridge, so a Fast session's current column is measured as Fast, not standard.
test('CKP-FAD-11 CKP-MFD-19: a session the engine recorded as Fast compares as Fast; an unreported mode stays standard',async({page})=>{
 await open(page,'en',true,data=>{data.details.sessions[0].fast=true;});
 const solFader=page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first();
 await expect(solFader.locator('.fd-indicator')).toHaveAttribute('data-fast','true');
 await solFader.locator('.fd-strip').click();
 await expect(page.locator('.mfd-page.pg-compare')).toBeVisible();
 const key=page.locator('.mfd-vk button.vk-fast');
 await expect(key).toHaveAttribute('aria-pressed','true');
});
test('CKP-FAD-11 CKP-MFD-19: without the observed mode the same session stays standard',async({page})=>{
 await open(page,'en',true);
 const solFader=page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first();
 await expect(solFader.locator('.fd-indicator')).toHaveAttribute('data-fast','false');
 await solFader.locator('.fd-strip').click();
 await expect(page.locator('.mfd-vk button.vk-fast')).toHaveAttribute('aria-pressed','false');
});

// CKP-MFD-33 (demo v12, owner 11-12): fast mode on the big screen is only a number. Equal ability = one number with a blue
// "="; a fast value past 100 % pins to the end with › and prints the exact value; no ⚡ and no time on the bars.
const barsRead=page=>page.locator('.mfd-page svg.cmp-bars').evaluate(svg=>{const out={};for(const k of ['abl','cost']){const g=svg.querySelector(`.pc-${k}`),track=g.querySelector('.pc-track'),W=Number(track.getAttribute('width')),lane=g.querySelector('.pc-lane-trial');
 out[k]={numbers:[...g.querySelectorAll('.pc-num')].map(e=>({role:e.dataset.role,text:e.textContent,equal:e.dataset.equal==='true'})),lane:lane?Number(lane.getAttribute('width'))/W:null,over:g.querySelector('.pc-over')?g.querySelector('.pc-over').classList.contains('trial'):null};}return out;});
test('CKP-MFD-33 fast only: equal ability is one number with a blue "=", the cost shows both; nothing for fast on the big screen',async({page})=>{
 await open(page,'en',true);
 await sol(page).locator('.fd-strip').click();
 const screen=page.locator('.mfd-page.pg-compare');await expect(screen).toBeVisible();
 await page.locator('.mfd-vk button.vk-fast').click();
 const b=await barsRead(page);
 expect(b.abl.numbers.map(n=>[n.role,n.equal])).toEqual([['current',true]]);expect(b.abl.numbers[0].text).toMatch(/^=\d+%$/);
 expect(b.abl.lane).toBeGreaterThan(.5);
 expect(b.cost.numbers.map(n=>[n.role,n.equal])).toEqual([['current',false],['trial',false]]);
 const [c,t]=b.cost.numbers.map(n=>parseInt(n.text));expect(t/c).toBeGreaterThan(2.3);expect(t/c).toBeLessThan(2.7); // the subscription ratio 2.5
 expect(b.cost.over).toBeNull();
 await expect(screen.locator('.g-bolt')).toHaveCount(0);
 await expect(screen.locator('.cmp-note')).toHaveCount(0);
});
test('CKP-MFD-33 fast overflow: the bar pins to the end, › marks it, the number is exact',async({page})=>{
 await open(page,'en',true);
 await sol(page).locator('.fd-strip').click();
 await page.locator('.mfd-vk button.vk-fast').click();
 await page.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 const b=await barsRead(page);
 // The top effort at fast = the cost of the top effort x 2.5 = 250 %
 expect(b.cost.numbers.map(n=>n.role)).toEqual(['current','trial']);expect(b.cost.numbers[1].text).toBe('250%');
 expect(b.cost.over).toBe(true);expect(b.cost.lane).toBeGreaterThan(.99);
 expect(b.abl.over).toBeNull();
});

// Owner 11-12: fast mode on the small fader screen is a ⚡ beside the lamp, symbol only (no text), for both the real mode
// (white) and the trial (solid blue = a trial turns it on, blue outline = a trial turns it off).
test('CKP-FAD-24 fast symbol: ⚡ beside the lamp shows the real fast mode (white) and the trial (blue); no text; none without a fast mode',async({page})=>{
 await open(page,'en',true,data=>{data.details.sessions[0].fast=true;});
 const solFader=page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first(),bolt=solFader.locator('.fd-fast');
 await expect(bolt).toHaveCount(1);await expect(bolt).toHaveAttribute('data-fast-state','on');
 expect(await bolt.evaluate(e=>e.textContent.trim())).toBe('');
 // the lamp stays a dot, the bolt stands right of it on the same row
 const [lamp,sym]=await Promise.all([solFader.locator('.fd-indicator').boundingBox(),bolt.boundingBox()]);
 expect(sym.x).toBeGreaterThanOrEqual(lamp.x+lamp.width/2);expect(Math.abs(sym.y+sym.height/2-(lamp.y+lamp.height/2))).toBeLessThan(2);
 await expect(solFader.locator('.fd-indicator svg')).toHaveCount(0);
 // trial turns it off: blue outline
 await solFader.locator('.fd-strip').click();
 await page.locator('.mfd-vk button.vk-fast').click();
 await expect(solFader.locator('.fd-fast')).toHaveAttribute('data-fast-state','off');
 await page.locator('.mfd-vk button.vk-fast').click();
 await expect(solFader.locator('.fd-fast')).toHaveAttribute('data-fast-state','on');
 // a model with no fast mode (Astra) shows none
 await page.locator('.mfd-vk .vk-back').click();
 await expect(page.locator('.fd-ch:not(.empty)').filter({hasText:'Astra'}).first().locator('.fd-fast')).toHaveCount(0);
});
test('CKP-FAD-24 fast symbol: a trial that turns fast on shows a solid blue ⚡; standard mode shows none',async({page})=>{
 await open(page,'en',true);
 const solFader=page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first();
 await expect(solFader.locator('.fd-fast')).toHaveCount(0);
 await solFader.locator('.fd-strip').click();
 await page.locator('.mfd-vk button.vk-fast').click();
 const bolt=solFader.locator('.fd-fast');
 await expect(bolt).toHaveAttribute('data-fast-state','try');
 expect(await bolt.locator('path').evaluate(p=>getComputedStyle(p).fill)).not.toBe('none');
 await page.locator('.mfd-vk button.vk-fast').click();
 await expect(solFader.locator('.fd-fast')).toHaveCount(0);
});

// Owner 11-12: with fast on (real or trial) the WHOLE cost and time lines are drawn with the tier applied, the Standard lines stay faint behind them and a band joins each pair.
const lineYs=(page,sel)=>page.locator(`.mfd-page svg.cmp-chart ${sel} polyline`).evaluate(p=>p.getAttribute('points').split(' ').map(q=>Number(q.split(',')[1])));
test('CKP-MFD-33 fast lines: a fast trial raises every point of the cost and time lines; Standard stays faint with a band between; off draws neither',async({page})=>{
 await open(page,'en',true);
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-strip').click();
 const chart=page.locator('.mfd-page svg.cmp-chart');
 await expect(chart.locator('.pc-std')).toHaveCount(0);await expect(chart.locator('.pc-fastband')).toHaveCount(0);
 const before=await lineYs(page,'.pc-line.pc-cost:not(.pc-std)');
 await page.locator('.mfd-vk button.vk-fast').click();
 await expect(chart.locator('.pc-std')).toHaveCount(2);await expect(chart.locator('.pc-fastband')).toHaveCount(2);
 const std=await lineYs(page,'.pc-line.pc-cost.pc-std'),fast=await lineYs(page,'.pc-line.pc-cost:not(.pc-std)');
 expect(fast).toHaveLength(before.length);expect(std).toHaveLength(before.length);
 // the chart's scale stretches with the fast values, so compare the fast line with the Standard line in the same scale: every point is higher (a smaller y)
 for(let i=0;i<fast.length;i++)expect(fast[i],`point ${i}`).toBeLessThan(std[i]);
 expect(await chart.locator('.pc-std').first().evaluate(e=>Number(getComputedStyle(e).opacity))).toBeLessThan(.6);
 // time: a stated speed-up lowers every point of the time line
 const tstd=await lineYs(page,'.pc-line.pc-time.pc-std'),tfast=await lineYs(page,'.pc-line.pc-time:not(.pc-std)');
 for(let i=0;i<tfast.length;i++)expect(tfast[i]).toBeGreaterThan(tstd[i]);
 await page.locator('.mfd-vk button.vk-fast').click();
 await expect(chart.locator('.pc-std')).toHaveCount(0);
});
test('CKP-MFD-33 fast lines: a real fast session draws the fast lines too',async({page})=>{
 await open(page,'en',true,data=>{data.details.sessions[0].fast=true;});
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-strip').click();
 await expect(page.locator('.mfd-page svg.cmp-chart .pc-fastband')).toHaveCount(2);
});

// Owner 11-12: column strength is trial blue > current white > recommended gold; and when the trial effort equals the current
// effort (a fast-only trial) both show: the white current fill with the blue trial fill and a solid blue outline on top.
test('CKP-MFD-33 chart columns: trial blue > current white > ★ gold; trial = current keeps both',async({page})=>{
 await open(page,'en',true);
 await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-strip').click();
 const chart=page.locator('.mfd-page svg.cmp-chart');
 const alpha=async sel=>chart.locator(sel).evaluate(e=>{const c=getComputedStyle(e),m=c.fill.match(/rgba?\(([^)]+)\)/)[1].split(',').map(Number);return (m[3]??1)*Number(c.opacity);});
 await page.locator('.mfd-vk button.vk-fast').click(); // fast-only trial: the trial effort is the current one
 const cur=chart.locator('.pc-band-current'),tri=chart.locator('.pc-band-trial');
 await expect(cur).toHaveCount(1);await expect(tri).toHaveCount(1);
 expect(await cur.getAttribute('data-effort')).toBe(await tri.getAttribute('data-effort'));
 const a={cur:await alpha('.pc-band-current'),trial:await alpha('.pc-band-trial'),rec:await alpha('.pc-band-rec')};
 expect(a.cur).toBeGreaterThanOrEqual(.1);expect(a.cur).toBeLessThanOrEqual(.15);
 expect(a.trial).toBeGreaterThan(a.cur);expect(a.cur).toBeGreaterThan(a.rec);
 // equal: the blue outline stands on top of the white fill
 await expect(tri).toHaveClass(/pc-band-same/);
 expect(await tri.evaluate(e=>parseFloat(getComputedStyle(e).strokeOpacity))).toBeGreaterThanOrEqual(.6);
 // a different trial effort draws no such outline
 await page.locator('.cmp-lad [data-mfd="try:XHigh"]').click();
 await expect(chart.locator('.pc-band-trial')).not.toHaveClass(/pc-band-same/);
});

// Owner 11-12: the chart column layers, bottom to top: ★ gold wash, current white fill, trial blue fill + 1 px border. Every overlap keeps all its layers.
test('CKP-MFD-33 chart column layers: every overlap of current, trial and ★ shows all its layers, trial blue on top',async({page})=>{
 const cases=[
  {name:'current = ★',edit:d=>{d.details.sessions[0].effort='medium';},act:null,want:['rec','current']},
  {name:'trial = ★',edit:null,act:async()=>{await page.locator('.cmp-lad [data-mfd="try:Med"]').click();},want:['rec','current','trial']},
  {name:'trial = current',edit:null,act:async()=>{await page.locator('.mfd-vk button.vk-fast').click();},want:['rec','current','trial']},
  {name:'all three equal',edit:d=>{d.details.sessions[0].effort='medium';},act:async()=>{await page.locator('.mfd-vk button.vk-fast').click();},want:['rec','current','trial']},
 ];
 for(const c of cases){
  await open(page,'en',true,c.edit);
  await page.locator('.fd-ch:not(.empty)').filter({hasText:'Sol'}).first().locator('.fd-strip').click();
  await c.act?.();
  const chart=page.locator('.mfd-page svg.cmp-chart');
  const info=await chart.evaluate(svg=>[...svg.querySelectorAll('.pc-band:not(.pc-band-hover)')].map(e=>({role:e.classList.contains('pc-band-rec')?'rec':e.classList.contains('pc-band-current')?'current':'trial',effort:e.dataset.effort,order:[...svg.children].indexOf(e),
   stroke:parseFloat(getComputedStyle(e).strokeOpacity),fill:getComputedStyle(e).fill,w:e.getBBox().width})));
  const roles=info.map(i=>i.role);
  expect(roles.sort(),c.name).toEqual([...c.want].sort());
  const by=r=>info.find(i=>i.role===r);
  if(by('rec')&&by('current'))expect(by('rec').order,c.name).toBeLessThan(by('current').order);
  if(by('trial')){expect(by('trial').order,c.name).toBeGreaterThan(Math.max(...info.filter(i=>i.role!=='trial').map(i=>i.order)));expect(by('trial').stroke,c.name).toBeGreaterThanOrEqual(.5);}
  for(const i of info)expect(i.w).toBeGreaterThan(10);
  // the same column when they coincide
  const efforts=new Set(info.map(i=>i.effort));
  if(c.name==='all three equal')expect(efforts.size).toBe(1);
  if(c.name==='current = ★')expect(efforts.size).toBe(1);
 }
});
