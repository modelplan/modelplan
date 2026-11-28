// SPDX-License-Identifier: MIT
// D474 master spec, #1291 (band layout): columns per page by language (zh 6, en 5, pseudo-long 4), the label column (42 zh /
// 50 en), nozzles = columns on the page, the one quiet `+ 添加订阅` bay, the shared hover card (400 ms, Esc, same text in
// aria-label, survives a refresh), the range row in total tokens (G-a: a shared source is `—`), and the keyboard (⌘1–5,
// ⌥← / ⌥→, digits by position on the page, a band cell opens 订阅). Built page through its normal bridge; synthetic data.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {usePseudoLong} from '../pseudo-long.mjs';

test.beforeEach(async({page})=>excludePortholeFlicker(page));
const NOW=new Date(2026,10,27,9,40).getTime(),H=36e5,iso=t=>new Date(t).toISOString();
const ref=i=>(i+1).toString(16).padStart(16,'0');
function many(n,{sharedSource=false}={}){
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];data.details.forecasts=[];data.details.resetEvents=[];data.details.sessions=[];data.details.peaks=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref(i),accountLocator:ref(i),valueState:'current',observedAt:iso(NOW-3*60000),lastFailure:null});a.plan.name=null;a.windows=a.windows.slice(0,2);
  Object.assign(a.windows[0],{current:true,validUntil:iso(NOW+600*60000),resetsAt:iso(NOW+2*H),remainingPercent:80});
  Object.assign(a.windows[1],{current:true,validUntil:iso(NOW+600*60000),resetsAt:iso(NOW+100*H),remainingPercent:53});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref(i),accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref(i),today:[{...detail.today[0],source:row.id}],
   resetCounts:[{kind:'tokens',count:2,expiresAt:iso(NOW+30*H)}],
   resetCards:{state:'complete',count:2,truncated:false,sources:[],items:[{id:'1'.padStart(64,'0'),expiresAt:iso(NOW+30*H)},{id:'2'.padStart(64,'0'),expiresAt:iso(NOW+90*H)}]}});
 }
 void sharedSource;
 return data;
}
async function open(page,{data,locale='zh-CN',range='today',pseudo=false}={}){
 if(pseudo)await usePseudoLong(page);
 await page.clock.setFixedTime(new Date(NOW));
 await page.addInitScript(()=>{window.__posts=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__posts.push(JSON.parse(raw));}}}};});
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const cols=page=>page.locator('.eng-cols > .ec[data-col]:not(.pl-col)');

for(const [name,locale,pseudo,per,label] of [['zh',  'zh-CN',false,6,42],['en','en',false,5,50],['pseudo-long','en',true,4,50]])
 test(`§3.1 ${name}: ${per} columns per page, label column ${label} pt, a pager, one nozzle per column, keys 1–${per}`,async({page})=>{
  await open(page,{data:many(7),locale,pseudo});
  await expect(cols(page)).toHaveCount(per);
  await expect(page.locator('.eng-pgn')).toHaveText(`1/${Math.ceil(7/per)}`);
  expect(await page.locator('.eng-labels').evaluate(e=>Math.round(e.getBoundingClientRect().width))).toBe(label);
  expect(await page.locator('.eng-keys .ek[data-sub] .ki').allTextContents()).toEqual(Array.from({length:per},(_,i)=>String(i+1)));
  // Nozzles: one per column on the page, re-shot when the page changes.
  await expect(page.locator('.ck-base .bz')).toHaveCount(per);
  await page.locator('[data-bpage="1"]').click();
  await expect(page.locator('.eng-pgn')).toHaveText(`2/${Math.ceil(7/per)}`);
  await expect(cols(page)).toHaveCount(7-per);
  await expect(page.locator('.ck-base .bz')).toHaveCount(7-per+(page.locator('.eng-cols .pl-col')?0:0));
 });

test('§3.1 a language switch keeps the scoped subscription on screen (its page changes: zh 6 → en 5)',async({page})=>{
 const {send,receive}=await open(page,{data:many(7),locale:'zh-CN'});
 expect(await receive(send('shell',{...shell,range:'today',scope:ref(5)}))).toBe(true);
 await expect(page.locator('.eng-keys .ek[aria-pressed="true"]')).toHaveCount(1);
 await expect(page.locator('.eng-pgn')).toHaveText('1/2');
 expect(await receive(send('appearance',{...appearance,locale:'en'}))).toBe(true);
 await expect(page.locator('.eng-pgn')).toHaveText('2/2');
 await expect(page.locator('.eng-keys .ek[aria-pressed="true"]')).toHaveCount(1);
});

test('§7.3 digits scope by position on the current page; a digit with no column does nothing; 0 = 全部; ⌥← / ⌥→ page the band',async({page})=>{
 const {send,receive}=await open(page,{data:many(7),locale:'en'});
 const asked=()=>page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='scopeSelect').map(m=>m.key));
 await page.keyboard.press('Alt+ArrowRight');
 await expect(page.locator('.eng-pgn')).toHaveText('2/2');
 await page.keyboard.press('1');
 expect((await asked()).at(-1)).toBe(ref(5));// position 1 of page 2 is the sixth subscription
 const before=(await asked()).length;
 await page.keyboard.press('6');
 expect((await asked()).length,'en page 2 has two columns: key 6 has no target').toBe(before);
 await page.keyboard.press('Alt+ArrowLeft');
 await expect(page.locator('.eng-pgn')).toHaveText('1/2');
 await page.keyboard.press('0');
 expect((await asked()).at(-1)).toBe('all');
 void send;void receive;
});

test('§7.3 ⌘1–⌘5 open the five pages',async({page})=>{
 await open(page,{data:many(3)});
 for(const [i,id] of [[1,'overview'],[2,'sub'],[3,'tune'],[4,'where'],[5,'calendar']]){
  await page.keyboard.press(`Meta+${i}`);
  await expect(page.locator(`.mfd-pk .pk[data-mfd="page:${id}"]`)).toHaveAttribute('aria-pressed','true');
 }
});

for(const [n,bays] of [[1,1],[2,1],[3,0]])
 test(`CKP-ENG-56 ${n} subscription(s): ${bays} quiet "+ 添加订阅" bay${bays?'':', none at three columns'}; no calendar filler`,async({page})=>{
  await open(page,{data:many(n)});
  await expect(page.locator('.eng-cols .ec-bay .ec-add')).toHaveCount(bays);
  if(bays)await expect(page.locator('.eng-cols .ec-bay .ec-add')).toContainText('添加订阅');
  await expect(page.locator('.eng-cols .pl-col[data-plugin="calendar"]')).toHaveCount(0);
 });

// §7.1: hover or focus shows the card after 400 ms; Esc closes it; the aria-label carries the same text; a refresh keeps it open.
test('§7.1 the shared hover card: 400 ms, title / facts / basis, Esc, same text in aria-label, survives a refresh',async({page})=>{
 const {send,receive}=await open(page,{data:many(3),locale:'zh-CN'});
 const cell=cols(page).first().locator('.qcell[data-row="second"]');
 await cell.hover();
 await page.waitForTimeout(150);
 await expect(page.locator('.hc-card'),'not yet: the card waits 400 ms').toBeHidden();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:1500});
 const card=page.locator('.hc-card');
 await expect(card.locator('.h')).toContainText('订阅1');
 expect(await card.locator('span').count()).toBeGreaterThanOrEqual(3);
 await expect(card.locator('.basis')).toContainText('读数');
 const text=(await card.innerText()).replace(/\s*\n\s*/g,' · ');
 const aria=await cell.getAttribute('aria-label');
 expect(aria.replace(/\s/g,'')).toBe(text.replace(/\s/g,''));
 // A refresh redraws the cells; the open card stays and is redrawn in place.
 const data=many(3);expect(await receive(send('display',{data}))).toBe(true);
 await expect(page.locator('.hc-card')).toHaveCount(1);
 await page.keyboard.press('Escape');
 await expect(page.locator('.hc-card')).toHaveCount(0);
});

test('§7.1 keyboard focus on a cell shows the same card; the card never covers the HUD',async({page})=>{
 await open(page,{data:many(3)});
 await cols(page).first().locator('.qcell[data-row="first"]').focus();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:1500});
 const [c,h]=await Promise.all([page.locator('.hc-card').boundingBox(),page.locator('.hud').boundingBox()]);
 if(h)expect(c.y>=h.y+h.height||c.y+c.height<=h.y||c.x>=h.x+h.width||c.x+c.width<=h.x).toBe(true);
});

test('§7.1 the key card: full name, plan, updated; the reserve row card lists the banked resets with their expiry',async({page})=>{
 await open(page,{data:many(2),locale:'en'});
 await page.locator('.eng-keys .ek[data-sub]').first().hover();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:1500});
 await expect(page.locator('.hc-card .h')).toContainText('Sub 1');
 await expect(page.locator('.hc-card')).toContainText('Updated');
 await page.mouse.move(2,2);
 await cols(page).first().locator('.qrow-r').hover();
 await expect(page.locator('.hc-card')).toBeVisible({timeout:1500});
 await expect(page.locator('.hc-card')).toContainText('2 reset(s) · expires in 1d6h');
});

// D474 §2.5, G-a: total tokens from cost.daily; two subscriptions on one tool cannot split Today.
test('G-a the range row is total tokens from cost.daily; a source shared by two subscriptions shows "—" and explains itself',async({page})=>{
 const data=many(2);
 const day=new Date(NOW),key=`${day.getFullYear()}-${String(day.getMonth()+1).padStart(2,'0')}-${String(day.getDate()).padStart(2,'0')}`;
 const S={totalTokens:50e6,reasoningTokens:1e6,inputTokens:20e6,outputTokens:10e6,cacheReadTokens:18e6,cacheWriteTokens:2e6,cacheHitRatio:.9,generationTps:40,observedRequests:9,eligibleRequests:9};
 const src=(source)=>({source,bindingBasis:'source-wide-current-binding',recent7d:S,recent30d:S});
 data.history={...structuredClone(data.history),coverage:'local-history',
  subscriptions:[{subscriptionRef:ref(0),sources:[src('synthetic-1')]},{subscriptionRef:ref(1),sources:[src('synthetic-2')]}],
  cost:{basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-20',daily:[{at:key,source:'synthetic-1',estimatedUsd:3,pricedTokens:4_000_000,unpricedTokens:1_000_000},{at:key,source:'synthetic-2',estimatedUsd:1,pricedTokens:2_000_000,unpricedTokens:0}],hourly:[],models:{today:[],recent7d:[],recent30d:[]}}};
 const {send,receive}=await open(page,{data,locale:'en'});
 await expect(cols(page).nth(0).locator('.qrow-t .qtokens')).toHaveText('5.0M');
 await expect(cols(page).nth(1).locator('.qrow-t .qtokens')).toHaveText('2.0M');
 await cols(page).nth(0).locator('.qrow-t').hover();
 await expect(page.locator('.hc-card')).toContainText('5.0M tokens in total',{timeout:1500});
 await expect(page.locator('.hc-card')).toContainText('≈$3');
 // Now both subscriptions read the same source.
 data.history.subscriptions[1].sources=[src('synthetic-1')];
 expect(await receive(send('display',{data}))).toBe(true);
 await expect(cols(page).nth(0).locator('.qrow-t .qtokens')).toHaveText('—');
 await expect(cols(page).nth(1).locator('.qrow-t .qtokens')).toHaveText('—');
 await page.mouse.move(2,2);
 await cols(page).nth(0).locator('.qrow-t').hover();
 await expect(page.locator('.hc-card')).toContainText('cannot be split',{timeout:1500});
 await expect(page.locator('.hc-card')).toContainText('5.0M');
});

test('§7.2 a band cell scopes to its subscription and opens 订阅',async({page})=>{
 await open(page,{data:many(3)});
 await cols(page).nth(1).locator('.qcell[data-row="first"]').click();
 await expect(page.locator('.mfd-pk .pk[data-mfd="page:sub"]')).toHaveAttribute('aria-pressed','true');
 expect(await page.evaluate(()=>window.__posts.filter(m=>m.type==='action'&&m.action==='scopeSelect').map(m=>m.key).at(-1))).toBe(ref(1));
});
