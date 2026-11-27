// SPDX-License-Identifier: MIT
// v1 final quota table (WP-07) on the built page through its normal bridge, synthetic data only.
// CKP-ENG-50 the six cell states · CKP-ENG-53 range row drop order · CKP-ENG-54 column wash · CKP-ENG-55 footer
// (shown page only, failing reads, right-aligned beside the pager) · CKP-ENG-56 one add affordance (#793 folded in) ·
// CKP-ENG-57 empty table · CKP-ENG-01/03 paging with 7+ subscriptions keeps the reserve row inside the table.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,shell} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';

const NOW=Date.parse('2026-11-18T12:00:00Z'),iso=minutes=>new Date(NOW+minutes*60000).toISOString();
async function open(page,data,locale='en',range=null) {
 await page.addInitScript(()=>{window.sent=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.sent.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,range:range??'today'},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 expect(await receive(send('display',{data}))).toBe(true);
}
// n subscriptions cloned from the visual fixture's first one, every reading current and three minutes old.
function fixture(n) {
 const data=visualFixture().data,seed=data.projection.rows[0],detail=data.details.subscriptions[0];
 data.projection.rows=[];data.subscriptions=[];data.details.subscriptions=[];
 for(let i=0;i<n;i++){
  const row=structuredClone(seed),ref=(i+1).toString(16).padStart(16,'0'),a=row.accounts[0];
  row.id=`synthetic-${i+1}`;row.name={en:`Sub ${i+1}`,zh:`订阅${i+1}`};
  Object.assign(a,{subscriptionRef:ref,accountLocator:ref,valueState:'current',observedAt:iso(-3),lastFailure:null});a.plan.name=null;
  for(const w of a.windows)Object.assign(w,{current:true,validUntil:iso(600),resetsAt:iso(200)});
  data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(a)}]});
  data.details.subscriptions.push({...structuredClone(detail),subscriptionRef:ref,today:[{...detail.today[0],source:row.id}]});
 }
 const account=i=>data.projection.rows[i].accounts[0];
 const sync=()=>{for(const [i,s] of data.subscriptions.entries())s.accounts[0].account=structuredClone(account(i));};
 return {data,account,sync};
}
const cell=(page,i,row='first')=>page.locator(`.eng-cols > .ec[data-col]`).nth(i).locator(`.qcell[data-row="${row}"]`);

for(const [locale,unreadable,usedUp,quotaOnly] of [['en','no reading','used up','Quota only'],['zh-CN','读不到','已用完','仅额度']])
 test(`CKP-ENG-50 the six cell states on the page (${locale})`,async({page})=>{
  const {data,account,sync}=fixture(6);
  // 0 normal · 1 loading · 2 unreadable · 3 stale · 4 used up · 5 no usage record
  Object.assign(account(1),{valueState:'none',observedAt:null});for(const w of account(1).windows)w.remainingPercent=null;
  Object.assign(account(2),{valueState:'none',observedAt:null,windows:[],lastFailure:{at:iso(-1),code:'not_signed_in'}});
  Object.assign(account(3),{valueState:'retained',observedAt:iso(-90)});
  account(4).windows[0].remainingPercent=0;
  data.details.subscriptions[5].today=[];
  sync();
  await open(page,data,locale);
  await expect(cell(page,0).locator('.qvalue')).toHaveText('75');await expect(cell(page,0).locator('.qtxt')).toHaveText('3h20');
  await expect(page.locator('.eng-cols > .ec[data-col]').nth(1).locator('.qph')).toHaveCount(3);
  await expect(page.locator('.eng-cols > .ec[data-col]').nth(1).locator('.qvalue,.qtxt')).toHaveCount(0);
  await expect(cell(page,2).locator('.qvalue')).toHaveText('--');await expect(cell(page,2).locator('.qtxt.dim')).toHaveText(unreadable);
  await expect(cell(page,3).locator('.qtxt')).toHaveText(locale==='en'?'3h 1h ago':'3h 1h前');// stale: drawn like current, plus its reading age (CKP-ENG-22)
  await expect(page.locator('.eng-cols > .ec[data-col]').nth(3)).not.toHaveClass(/\bgrey\b/);
  await expect(cell(page,4).locator('.qvalue')).toHaveText('0');await expect(cell(page,4).locator('.qtxt.crit')).toHaveText(usedUp);
  const [ink,low]=await cell(page,4).evaluate(e=>{const p=document.createElement('i');p.style.color='var(--st-low)';e.append(p);const r=[getComputedStyle(e.querySelector('.qnum')).color,getComputedStyle(p).color];p.remove();return r;});
  expect(ink,'the used-up number is red').toBe(low);
  await expect(page.locator('.eng-cols > .ec[data-col]').nth(5).locator('.qrow-t .qq')).toHaveText(quotaOnly);
  await expect(page.locator('.eng-cols > .ec[data-col]').nth(0).locator('.qrow-t .qq')).toHaveCount(0);
 });

test('CKP-ENG-50 hovering a reading with an unknown reset shows it (macrevb-1020-2)',async({page})=>{
 const {data,account,sync}=fixture(2);account(0).windows[0].resetsAt=null;sync();
 await open(page,data);
 await cell(page,0).hover();
 await expect(page.locator('.eng-hint')).toBeVisible();await expect(page.locator('.eng-hint')).toContainText('reset ?');
 await cell(page,0,'second').hover();
 await expect(page.locator('.eng-hint')).toHaveCount(0);
});

test('CKP-ENG-54 an alert washes its column; a stale or unreadable one does not',async({page})=>{
 const {data,account,sync}=fixture(3);
 for(const i of [0,1,2])account(i).windows[0].remainingPercent=10;
 Object.assign(account(1),{valueState:'retained',observedAt:iso(-90)});
 Object.assign(account(2),{valueState:'none',observedAt:null,lastFailure:{at:iso(-1),code:'network'}});
 sync();await open(page,data);
 const cols=page.locator('.eng-cols > .ec[data-col]');
 await expect(cols.nth(0)).toHaveClass(/\btint-red\b/);
 await expect(cols.nth(1)).not.toHaveClass(/\btint-/);await expect(cols.nth(2)).not.toHaveClass(/\btint-/);
});

for(const [locale,text,retry,reason] of [['en','12 min ago','Retry','no new data'],['zh-CN','12 分钟前','重试','读不到新数据']])
 test(`CKP-ENG-55 the overview's bottom line says when reads keep failing in amber, with the reason on hover, and offers a retry (${locale})`,async({page})=>{
  const {data,account,sync}=fixture(2);Object.assign(account(1),{valueState:'retained',observedAt:iso(-12),lastFailure:{at:iso(-1),code:'network'}});sync();
  await open(page,data,locale);
  const line=page.locator('.pg-overview .ov-foot .eng-upd');
  await expect(line.locator('.eng-upd-t')).toHaveText(text);await expect(line.locator('button.eng-upd-r')).toHaveText(retry);
  await expect(line).toHaveAttribute('data-failing','true');
  expect(await line.getAttribute('data-tip')).toContain(reason);
  const [ink,amber]=await page.evaluate(()=>{const e=document.querySelector('.pg-overview .eng-upd[data-failing="true"] .eng-upd-t'),probe=document.createElement('i');probe.style.color='var(--st-mid)';e.parentElement.append(probe);const r=[getComputedStyle(e).color,getComputedStyle(probe).color];probe.remove();return r;});
  expect(ink,'amber').toBe(amber);
  await page.locator('button.eng-upd-r').click();
  expect(await page.evaluate(()=>window.sent.filter(m=>m.type==='action').map(m=>[m.action,m.key]).at(-1))).toEqual(['refreshMember','all']);
  // The held values stay: no "delayed" notice in the table.
  await expect(page.locator('.eng-cols .qvalue').first()).toHaveText('75');
 });

// D376: the staleness signal stays visible when the overview is not showing: an amber dot on the 全部 key.
test('CKP-ENG-55 healthy reads put no dot on the 全部 key',async({page})=>{
 const {data}=fixture(2);await open(page,data);
 await expect(page.locator('.ek-all .ek-stale')).toHaveCount(0);
});
test('CKP-ENG-55 failing reads put an amber dot on the 全部 key, also while another page is showing',async({page})=>{
 const {data,account,sync}=fixture(2);
 Object.assign(account(1),{valueState:'retained',observedAt:iso(-12),lastFailure:{at:iso(-1),code:'network'}});sync();
 await open(page,data);
 await expect(page.locator('.ek-all .ek-stale')).toHaveCount(1);await expect(page.locator('.ek-all .ek-stale')).toBeVisible();
 await page.locator('.mfd-pk .pk').nth(1).click();
 await expect(page.locator('.mfd-page.pg-overview')).toHaveCount(0);
 await expect(page.locator('.ek-all .ek-stale'),'still there when another page is showing').toBeVisible();
});

test('D376 one page: no pager, no strip, the keys keep full height',async({page})=>{
 const {data}=fixture(3);await open(page,data);
 await expect(page.locator('.eng-pg')).toHaveCount(0);
 const [all,sub]=await Promise.all([page.locator('.ek-all').boundingBox(),page.locator('.eng-keys .ek[data-sub]').first().boundingBox()]);
 expect(all.height).toBe(sub.height);
 const [eng,lcd]=await Promise.all([page.locator('.ck-eng').boundingBox(),page.locator('.eng-lcd').boundingBox()]);
 expect(Math.abs(eng.y+eng.height-(lcd.y+lcd.height)),'the table reclaims the strip row').toBeLessThanOrEqual(1);
});

test('CKP-ENG-01/03 D376 seven subscriptions: the pager sits under the 全部 key, the table reclaims the strip, the reserve row stays whole',async({page})=>{
 const {data,account,sync}=fixture(7);
 account(6).observedAt=iso(-60);
 for(const s of data.details.subscriptions)s.credits={balance:2368,observedAt:iso(-3)};
 sync();await open(page,data);
 await expect(page.locator('.eng-pg')).toBeVisible();await expect(page.locator('.eng-pgn')).toHaveText('1/2');
 await expect(page.locator('.eng-pgn')).toHaveAttribute('aria-label','Page 1 of 2');
 await expect(page.locator('.eng-foot,.ck-eng .eng-upd')).toHaveCount(0);
 const [lcd,pager,all,eng,reserve]=await Promise.all(['.eng-lcd','.eng-pg','.ek-all','.ck-eng','.eng-cols > .ec[data-col] .qrow-r'].map(s=>page.locator(s).first().boundingBox()));
 expect(pager.y,'under the 全部 key').toBeGreaterThanOrEqual(all.y+all.height-1);
 expect(pager.x).toBeGreaterThanOrEqual(all.x-1);expect(pager.x+pager.width,'fits the key width').toBeLessThanOrEqual(all.x+all.width+1);
 expect(pager.y+pager.height,'above the table').toBeLessThanOrEqual(lcd.y+1);
 expect(Math.abs(eng.y+eng.height-(lcd.y+lcd.height)),'the table reclaims the old strip row').toBeLessThanOrEqual(1);
 expect(reserve.y+reserve.height,'the reserve row is whole inside the table').toBeLessThanOrEqual(lcd.y+lcd.height+0.5);
 await expect(page.locator('.eng-cols > .ec[data-col]').first().locator('.qrow-r .qrv-p')).toHaveText('Credits 2,368');
 // Page 2: the seventh subscription alone; the paged empty bays stay blank (CKP-ENG-03).
 await page.locator('.eng-pk[data-bpage="1"]').click();
 await expect(page.locator('.eng-pgn')).toHaveText('2/2');
 await expect(page.locator('.ec-add')).toHaveCount(0);
 const reserve2=await page.locator('.eng-cols > .ec[data-col] .qrow-r').first().boundingBox(),lcd2=await page.locator('.eng-lcd').boundingBox();
 expect(reserve2.y+reserve2.height).toBeLessThanOrEqual(lcd2.y+lcd2.height+0.5);
});

test('sampling 11-22: the lower corners of All select All without paging',async({page})=>{
 const {data}=fixture(7);await open(page,data);
 for(const side of ['left','right']){
  await page.locator('.eng-keys .ek[data-sub]').first().click();
  await expect(page.locator('.ek-all')).toHaveAttribute('aria-pressed','false');
  const box=await page.locator('.ek-all').boundingBox();
  await page.mouse.click(side==='left'?box.x+2:box.x+box.width-2,box.y+box.height-1);
  await expect(page.locator('.ek-all')).toHaveAttribute('aria-pressed','true');
  await expect(page.locator('.eng-pgn')).toHaveText('1/2');
 }
 const arrow=await page.locator('.eng-pk[data-bpage="1"]').boundingBox();
 await page.mouse.click(arrow.x-0.5,arrow.y+arrow.height/2);
 await expect(page.locator('.eng-pgn')).toHaveText('2/2');
});

// D464 (reverses CKP-ENG-53's drop order): tokens never drop; speed drops before ≈cost.
test('D464 six English columns: tokens never drop; speed drops before ≈cost',async({page})=>{
 const {data,sync}=fixture(6);
 for(const s of data.details.subscriptions)s.today=[{...s.today[0],observedOutputTokens:212e6,generationTps:52}];
 sync();await open(page,data);
 const row=page.locator('.eng-cols > .ec[data-col]').first().locator('.qrow-t');
 const shown=async sel=>row.locator(sel).evaluate(e=>getComputedStyle(e).display!=='none').catch(()=>false);
 const fits=await row.evaluate(e=>e.scrollWidth<=e.clientWidth);
 expect(fits,'the row never overflows').toBe(true);
 expect(await shown('.qtokens'),'tokens stay').toBe(true);
 if(!(await shown('.qcost')))expect(await shown('.qaverage'),'≈cost only drops after speed').toBe(false);
 await expect(row.locator('.qtokens')).toHaveText('212M');
});

for(const n of [1,2])test(`CKP-ENG-56 ${n} subscription(s): one quiet add affordance in the first empty bay, which opens Settings (#793)`,async({page})=>{
 const {data}=fixture(n);await open(page,data);
 await expect(page.locator('.ec-add')).toHaveCount(1);await expect(page.locator('.ec-add-label')).toHaveText('Add a subscription');
 await expect(page.locator('.eng-cols > .ec-bay').first().locator('.ec-add')).toHaveCount(1);
 const add=page.locator('.ec-add'),rest=Number(await add.evaluate(e=>getComputedStyle(e).opacity));expect(rest).toBeLessThanOrEqual(0.5);
 await page.locator('.eng-cols > .ec-bay').first().hover();
 expect(Number(await add.evaluate(e=>getComputedStyle(e).opacity))).toBeGreaterThan(rest);
 await page.locator('.eng-cols > .ec-bay').first().click();
 // The bay opens the add menu (WP-18); its all-subscriptions row is the way into Settings > Subscriptions.
 await page.locator('.pl-menu .pm-more[data-pm-all]').click();
 expect(await page.evaluate(()=>window.sent.filter(m=>m.type==='action').at(-1)?.action)).toBe('openSettingsSubscriptions');
});

test('CKP-ENG-56 three or more subscriptions show no add affordance',async({page})=>{
 await open(page,fixture(3).data);
 await expect(page.locator('.ec-add')).toHaveCount(0);
});

for(const [locale,text,button] of [['en','No quota read yet. Sign in to a coding tool and it appears here.','Open Settings › Subscriptions'],['zh-CN','还没读到订阅额度。登录一个编程工具后，这里会自动显示。','打开 设置 › 订阅']])
 test(`CKP-ENG-57 no subscriptions: one line, one way in, and the rest stays dark (${locale})`,async({page})=>{
  const {data}=fixture(1);for(const r of data.projection.rows)r.surfaces=r.surfaces.filter(s=>s!=='dock');
  await open(page,data,locale);
  await expect(page.locator('.ck-eng .ec-empty')).toHaveText(text);
  await page.locator('.ck-eng .ec-empty-open').click();
  expect(await page.evaluate(()=>window.sent.filter(m=>m.type==='action').at(-1)?.action)).toBe('openSettingsSubscriptions');
  await expect(page.locator('#cockpit')).toHaveAttribute('data-engine-empty','true');
  expect(await page.locator('.ck-deck').evaluate(e=>getComputedStyle(e).filter)).toContain('brightness');
 });

// G3-156 / CKP-ENG-53: the range row follows the header range (label, ≈cost, tokens, speed) in all three ranges, and a
// narrow column drops speed first, then tokens, never the ≈cost.
const localKey=back=>{const d=new Date(NOW);d.setDate(d.getDate()-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const sums=(out,tps)=>({inputTokens:null,outputTokens:out,totalTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:tps,observedRequests:5,eligibleRequests:5});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
function withHistory(data){
 const refs=data.projection.rows.map(r=>r.accounts[0].subscriptionRef);
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localKey(40),
  subscriptions:refs.map((ref,i)=>({subscriptionRef:ref,sources:[{source:`synthetic-${i+1}`,bindingBasis:'source-wide-current-binding',recent7d:sums(212e6,52),recent30d:sums(900e6,48)}]})),
  models:ranking,tools:ranking,daily:[],hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[],
  cost:{basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-18',models:{today:[],recent7d:[],recent30d:[]},hourly:[],
   daily:refs.flatMap((ref,i)=>[{at:localKey(0),source:`synthetic-${i+1}`,estimatedUsd:3,pricedTokens:1000,unpricedTokens:0},{at:localKey(3),source:`synthetic-${i+1}`,estimatedUsd:61,pricedTokens:1000,unpricedTokens:0},{at:localKey(20),source:`synthetic-${i+1}`,estimatedUsd:100,pricedTokens:1000,unpricedTokens:0}])}};
}
for(const [range,label,tokens,cost] of [['today','Today','12k','≈$3'],['7d','7d','212M','≈$64'],['30d','30d','900M','≈$164']])
 test(`G3-156 CKP-ENG-53 the range row follows the ${range} key: label, ≈cost, tokens and speed`,async({page})=>{
  const {data,sync}=fixture(3);withHistory(data);sync();await open(page,data,'en',range);
  await expect(page.locator('.lb-t')).toHaveText(label);
  const row=page.locator('.eng-cols > .ec[data-col]').first().locator('.qrow-t');
  await expect(row.locator('.qq')).toHaveCount(0);
  await expect(row.locator('.qcost')).toHaveText(cost);
  await expect(row.locator('.qtokens')).toHaveText(tokens);
  await expect(row.locator('.qaverage')).toContainText(range==='today'?'42':range==='7d'?'52':'48');
 });
for(const range of ['today','7d','30d'])
 test(`G3-156 D464 six columns, ${range}: the row never overflows and drops speed before ≈cost, never the tokens`,async({page})=>{
  const {data,sync}=fixture(6);withHistory(data);sync();await open(page,data,'en',range);
  const row=page.locator('.eng-cols > .ec[data-col]').first().locator('.qrow-t');
  const shown=async sel=>row.locator(sel).evaluate(e=>getComputedStyle(e).display!=='none').catch(()=>false);
  expect(await row.evaluate(e=>e.scrollWidth<=e.clientWidth)).toBe(true);
  expect(await shown('.qtokens'),'tokens stay').toBe(true);
  if(!(await shown('.qcost')))expect(await shown('.qaverage'),'≈cost only drops after speed').toBe(false);
 });
test('G3-156 the range row says no usage in the range, not "quota only", when history is read and nothing is recorded',async({page})=>{
 for(const [range,text] of [['today','No usage today'],['7d','No usage in 7d'],['30d','No usage in 30d']]){
  const {data,sync}=fixture(3);withHistory(data);
  for(const s of data.history.subscriptions)for(const x of s.sources){x.recent7d={...x.recent7d,observedRequests:0,eligibleRequests:0,outputTokens:0,totalTokens:0};x.recent30d={...x.recent30d,observedRequests:0,eligibleRequests:0,outputTokens:0,totalTokens:0};}
  data.history.cost.daily=[];data.details.subscriptions.forEach(s=>{s.today=[];});
  sync();await open(page,data,'en',range);
  await expect(page.locator('.eng-cols > .ec[data-col]').first().locator('.qrow-t .qq')).toHaveText(text);
 }
});
