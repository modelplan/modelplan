// SPDX-License-Identifier: MIT
// Owner badcase 11-21 (internal build 9947ba97) on the built page through its normal bridge. Synthetic data only.
//  B1  the date keys: a clicked key never shows the keyboard ring; a history read the engine could not make this time
//      never shows "No usage record yet" while the page holds the last local history (same page context only).
//  B8  the resource column: tags CPU · Memory · Disk always present, in that order, never squeezed or clipped.
//  HUD the porthole list: every ★ effort starts at the same x; a versioned name keeps its version.
import {test,expect} from '../../../cockpit/node_modules/@playwright/test/index.mjs';
import {appearance,commands,pageId,sample,shell,excludePortholeFlicker} from '../fixture.mjs';
import {visualFixture} from '../visual-fixture.mjs';
import {shortLabel} from '../../../cockpit/study/rocket-r1/short-label.js';
test.beforeEach(async({page})=>excludePortholeFlicker(page));

const NOW=new Date(2026,10,4,12).getTime();
const localDay=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
async function open(page,{data,locale='en',tier='tall',range='7d',plugins=null}){
 await page.addInitScript(()=>{window.__msgs=[];window.webkit={messageHandlers:{cockpit:{postMessage(raw){window.__msgs.push(JSON.parse(raw));}}}};});
 await page.clock.setFixedTime(new Date(NOW));
 await page.goto('/?pageId='+pageId);await page.waitForFunction(()=>!!window.modelPlanCockpit);
 const send=commands(),receive=raw=>page.evaluate(raw=>window.modelPlanCockpit.receive(raw),raw);
 expect(await receive(send('load',{appearance:{...appearance,locale},shell:{...shell,tier,range},redBelow:25}))).toBe(true);
 expect(await receive(send('visibility',{visible:true,occluded:false,key:true}))).toBe(true);
 if(plugins)expect(await receive(send('plugins',{plugins}))).toBe(true);
 if(data)expect(await receive(send('display',{data}))).toBe(true);
 return {send,receive};
}
const sums=out=>({inputTokens:null,outputTokens:out,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
const noProjects={recent7d:[],recent30d:[]};
/** A reply whose local history was read (cockpitHistoryV1 coverage local-history). */
function recorded(){
 const data=visualFixture().data,ref=data.projection.rows[0].accounts[0].subscriptionRef;
 // The owner's case: nothing reported for today, so the overview's totals come from the history alone.
 data.details.subscriptions.forEach(s=>{s.today=[];});
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:localDay(40),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1),recent30d:sums(1)}]}],
  models:ranking,tools:ranking,daily:[{at:localDay(1),source:'codex',origin:'live',observedOutputTokens:1000},{at:localDay(0),source:'codex',origin:'live',observedOutputTokens:200}],hourly:[],projects:noProjects,cycles:[]};
 return data;
}
/** The same reply when the engine could not read the ledger this time (cockpit_history.go `empty` / BuildPerfHistory nil). */
function unread(coverage='unavailable'){
 const data=recorded();
 data.history={version:1,sources:[],coverage,recordingSince:null,dailyFrom:null,subscriptions:[],models:ranking,tools:ranking,daily:[],hourly:[],projects:noProjects,cycles:[]};
 return data;
}
const empty=page=>page.locator('.pg-overview .ov-empty');
const totals=page=>page.locator('.pg-overview .ov-top');

// ---- B1 (a): the yellow box on the selected date key ----
test('B1 a clicked date key, scale key, fader, session line or "more sessions" key never shows the keyboard ring after a key press; Tab and arrows still do',async({page})=>{
 // ghglm-1135-1: seven sessions, so the tape shows linked lines and its "more sessions" key too.
 const data=visualFixture().data,template=data.details.sessions.find(s=>s.state==='running')??data.details.sessions[0];
 const ref=data.projection.rows[0].accounts[0].subscriptionRef;// linked lines belong to a subscription
 data.details.sessions=Array.from({length:7},(_,i)=>({...template,subscriptionRef:ref,sessionRef:(i+1).toString(16).padStart(16,'0')}));
 await open(page,{data,range:'30d'});
 // The tape's controls must be there: a missing one would skip its check.
 await expect(page.locator('.ck-tape .tl.t-observed:not([aria-disabled="true"])').first()).toBeVisible();
 await expect(page.locator('.ck-tape .t-overflow')).toBeVisible();
 // A drawn keyboard ring: an outline, or the date key's ::before frame (strip header.css), on a :focus-visible element.
 const ringed=()=>page.evaluate(()=>[...document.querySelectorAll('body *')].filter(e=>{if(!e.matches(':focus-visible'))return false;const s=getComputedStyle(e),b=getComputedStyle(e,'::before');return s.outlineStyle!=='none'&&parseFloat(s.outlineWidth)>0||b.content!=='none'&&parseFloat(b.borderTopWidth)>0;}).map(e=>e.className.toString()));
 const targets=['[data-range-key="7d"]','[data-range-key="today"]','[data-range-key="30d"]','.fd-travel','.sc-l:not([disabled])',
  '.ck-tape .tl.t-observed:not([aria-disabled="true"])','.ck-tape .t-overflow'];
 for(const selector of targets){
  const control=page.locator(selector).first();if(!await control.count())continue;
  for(const key of ['Escape','Space','t']){
   await page.evaluate(()=>document.activeElement?.blur?.());
   await control.click();
   await page.keyboard.press(key);
   expect(await ringed(),`${selector} then ${key}`).toEqual([]);
  }
 }
 // The pointer still chose the range (the app owns it; the page asked).
 expect(await page.evaluate(()=>window.__msgs.filter(m=>m.type==='action'&&m.action==='rangeSelect').length)).toBeGreaterThan(0);
});
test('B1 keyboard users keep the date keys\' ring: an arrow moves the choice and the ring with it',async({page})=>{
 await open(page,{data:visualFixture().data,range:'today'});
 await page.locator('[data-range-key="today"]').focus();
 await page.keyboard.press('ArrowRight');
 await expect(page.locator('[data-range-key="7d"]')).toBeFocused();
 expect(await page.locator('[data-range-key="7d"]').evaluate(e=>e.matches(':focus-visible')&&parseFloat(getComputedStyle(e,'::before').borderTopWidth)>0)).toBe(true);
 // A click still focuses the key, so the arrow keys keep working after it (wp-10-header).
 await page.locator('[data-range-key="30d"]').click();await page.keyboard.press('ArrowLeft');
 await expect(page.locator('[data-range-key="7d"]')).toBeFocused();
});

// ---- B1 (c): loading is never the empty state ----
test('B1 a reply with an unread history keeps the last local history in the same page context; range switches never show the empty state',async({page})=>{
 const {send,receive}=await open(page,{data:recorded()});
 await expect(totals(page)).toHaveCount(1);await expect(empty(page)).toHaveCount(0);
 expect(await receive(send('display',{data:unread()}))).toBe(true);
 await expect(empty(page)).toHaveCount(0);await expect(totals(page)).toHaveCount(1);
 for(const k of ['30d','today','7d']){
  await page.locator(`[data-range-key="${k}"]`).click();
  expect(await receive(send('shell',{...shell,range:k}))).toBe(true);
  await expect(empty(page),k).toHaveCount(0);
  expect(await receive(send('display',{data:k==='today'?recorded():unread()}))).toBe(true);
  await expect(empty(page),k).toHaveCount(0);
 }
 // Recording turned off is a real state, not a failed read: it replaces the held history.
 expect(await receive(send('display',{data:unread('recording-off')}))).toBe(true);
 await expect(empty(page)).toHaveCount(1);
});
test('B1 the held history never crosses the privacy barrier and expires after ten minutes',async({page})=>{
 const {send,receive}=await open(page,{data:recorded()});
 await expect(totals(page)).toHaveCount(1);
 // A consent or store change arrives as `clear` first: nothing read before it is shown after it.
 const next={viewRevision:'4'};
 expect(await receive(send('clear',next))).toBe(true);
 expect(await receive(send('display',{...next,data:unread()}))).toBe(true);
 await expect(empty(page)).toHaveCount(1);
 // Hold expiry: ten minutes after the last local history an unread reply is taken at its word.
 expect(await receive(send('display',{...next,data:recorded()}))).toBe(true);
 await expect(empty(page)).toHaveCount(0);
 await page.clock.setFixedTime(new Date(NOW+10*60*1000));
 expect(await receive(send('display',{...next,data:unread()}))).toBe(true);
 await expect(empty(page)).toHaveCount(1);
});
test('B1 a fresh profile with nothing recorded still says "No usage record yet"',async({page})=>{
 await open(page,{data:unread()});
 await expect(empty(page)).toHaveCount(1);
});

// ---- B8: the resource column's labels ----
const GB=1024**3;
const reading=(t,o={})=>{const s={t,cpuUser:30,cpuSystem:9,load:2.4,memTotal:16*GB,memApp:8*GB,memWired:3*GB,memCompressed:1.4*GB,memCached:2*GB,memFree:1*GB,swapUsed:0.7*GB,pressure:'normal',diskTotal:494*GB,diskFree:28.9*GB,...o};
 for(const k of Object.keys(s))if(k.startsWith('mem')||k.startsWith('disk')||k==='swapUsed')s[k]=Math.round(s[k]);return s;};
function subscriptions(n){const data=sample();data.projection.rows=data.projection.rows.slice(0,n);
 // More than four subscriptions: copies of the first connected row under new ids (each its own column).
 while(data.projection.rows.length<n){const row=structuredClone(data.projection.rows[0]);row.id='copy'+data.projection.rows.length;data.projection.rows.push(row);}
 return data;}
const geometry=page=>page.evaluate(()=>{const col=document.querySelector('.pl-col[data-plugin="resources"]');if(!col)return null;
 const inside=(a,b)=>a.top>=b.top-.5&&a.bottom<=b.bottom+.5&&a.left>=b.left-.5&&a.right<=b.right+.5;
 return [...col.querySelectorAll('.pl-cell')].map(cell=>{const c=cell.getBoundingClientRect(),tag=cell.querySelector('.pl-tag'),t=tag.getBoundingClientRect();
  const parts=[...cell.querySelectorAll('.qtxt,.qnum')];
  return {tag:tag.textContent,tagHeight:t.height,lineHeight:parseFloat(getComputedStyle(tag).lineHeight),tagCut:tag.scrollHeight>tag.clientHeight+.5||tag.scrollWidth>tag.clientWidth+.5,tagInside:inside(t,c),
   parts:parts.map(p=>({w:[p.scrollWidth,p.clientWidth,Math.round(c.width)].join('/'),text:p.textContent,cut:p.scrollWidth>p.clientWidth+.5,inside:inside(p.getBoundingClientRect(),c)}))};});});
for(const tier of ['tall','compact'])for(const locale of ['en','zh-CN'])for(const subs of [1,2])
test(`B8 resource tags CPU · Memory · Disk are whole and in order, values never clipped (${tier}, ${locale}, ${subs} subscription${subs>1?'s':''})`,async({page})=>{
 const {send,receive}=await open(page,{data:subscriptions(subs),locale,tier,plugins:{version:1,entries:[],settings:{}}});
 const words=locale==='en'?['CPU','Memory','Disk']:['CPU','内存','磁盘'];
 const check=async when=>{const cells=await geometry(page);expect(cells,when).not.toBeNull();expect(cells.map(c=>c.tag),when).toEqual(words);
  for(const c of cells){expect(c.tagHeight,`${when} ${c.tag} height`).toBeGreaterThanOrEqual(c.lineHeight-.5);expect(c.tagCut,`${when} ${c.tag} cut`).toBe(false);expect(c.tagInside,`${when} ${c.tag} inside`).toBe(true);
   for(const p of c.parts){expect(p.cut,`${when} ${c.tag} ${p.text} ${p.w}`).toBe(false);expect(p.inside,`${when} ${c.tag} ${p.text} inside`).toBe(true);}}};
 await check('before the first reading');
 expect(await receive(send('pluginData',{id:'resources',data:{samples:[reading(NOW-5000,{cpuUser:43}),reading(NOW)]}}))).toBe(true);
 await expect(page.locator('.pl-col[data-plugin="resources"] .qvalue')).toHaveCount(3);
 await check('first render with readings');
});

// ---- HUD: the ★ column and versioned names ----
test('HUD every ★ effort starts at the same x, whatever the name length',async({page})=>{
 const effort=(key,ability,cost,star=false)=>({effort:key,label:key,star,ability,cost,time:30});
 const names=['GPT-6.2 Astra','GPT-6.1 Terra','GPT-6 Luna','GPT-6.2 Sol','GPT-6 Astra','GPT-5.6 Sol'],recs=['medium','medium','high','medium','medium','low'];
 const data=visualFixture().data;
 data.details.publishedModels=names.map((name,i)=>({id:'n'+i,name,developerId:'openai',recommended:recs[i],efforts:[effort('low',30+i,.02*(i+1),recs[i]==='low'),effort('medium',40+i,.05*(i+1),recs[i]==='medium'),effort('high',45+i,.1*(i+1),recs[i]==='high')]}));
 await open(page,{data});
 await expect(page.locator('.hud-b .hp')).toHaveCount(6);
 const starts=await page.locator('.hud-b .hp-rec').evaluateAll(list=>list.map(e=>e.getBoundingClientRect().left));
 for(const x of starts)expect(Math.abs(x-starts[0])).toBeLessThanOrEqual(0.5);
 // Names never run into the ★ column.
 const gaps=await page.locator('.hud-b .hp').evaluateAll(rows=>rows.map(r=>r.querySelector('.hp-rec').getBoundingClientRect().left-r.querySelector('b').getBoundingClientRect().right));
 for(const g of gaps)expect(g).toBeGreaterThanOrEqual(1.5);
 // "GPT-6 Astra" beside "GPT-6.2 Astra" keeps its version, so the two never read as one model twice.
 const shown=await page.locator('.hud-b .hp b').allTextContents();
 expect(new Set(shown).size).toBe(shown.length);
 expect(shortLabel('GPT-6 Astra')).toBe('Astra 6');expect(shortLabel('GPT-6 Luna')).toBe('Luna 6');
});
