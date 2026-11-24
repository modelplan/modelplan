// SPDX-License-Identifier: MIT
// v1 final quota table (WP-07): the cell states, the Other tag, the reserve row, the range row, the footer and the
// account label. Pure study model/view plus the host's pure helpers; synthetic data only.
// CKP-ENG-50 cell states · CKP-ENG-51 Other tag and +N · CKP-ENG-52 reserve names what it is, 0 is absent ·
// CKP-ENG-53 range row ≈cost first · CKP-ENG-55 footer reads the shown page only and says when reads keep failing ·
// CKP-ENG-26 (amended) "out ~40m" / "约40m用完" · §0 time format never prints "1h60".
import test from 'node:test';
import assert from 'node:assert/strict';
import {engineModel} from '../../../cockpit/study/rocket-r1/engine-model.js';
import {engineView} from '../../../cockpit/study/rocket-r1/engine-view.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import {dhm,approxCost} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';
import {cockpitMembers,unavailableZCodeMember} from '../../../cockpit/.tmp/compiled/src/members.js';
import {sessionMember} from '../../../cockpit/.tmp/compiled/src/session-binding.js';
import {accountLabel,accountState,footerState} from '../../../cockpit/.tmp/compiled/src/account-line.js';

globalThis.document??={documentElement:{}};
const NOW=Date.UTC(2026,10,18,12),H=3600e3;
const win=(kind,remaining,resetIn,extra={})=>({kind,remaining,resetIn,resetAt:null,resetText:null,elapsed:null,trend:null,runOutMin:null,durationMinutes:null,...extra});
const account=(id,windows,more={})=>({id,name:id,short:id,alias:id,colour:'#888888',logo:'x.svg',state:'ok',support:'observed',todayTokens:null,windows,extras:[],forecast:null,...more});
const model=(accounts,lang,alerts=[])=>engineModel({accounts,alerts,now:NOW},{few:'c3',page:0,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang,now:NOW});
const view=(accounts,lang='en',alerts=[])=>{setLanguage(lang);return engineView(model(accounts,lang,alerts),{changed:new Set(),lang,now:NOW});};
const col=(html,id)=>html.split(`data-col="${id}" data-state`)[1]?.split('<div class="ec')[0]??'';
const lines=html=>[...html.matchAll(/<em class="qtxt([^"]*)" data-full="([^"]*)"/g)].map(m=>({cls:m[1].trim(),full:m[2]}));
const values=html=>[...html.matchAll(/<span class="qvalue">([^<]*)<\/span>/g)].map(m=>m[1]);

for(const [lang,unreadable,usedUp,quotaOnly] of [['en','no reading','used up','Quota only'],['zh-CN','读不到','已用完','仅额度']])
 test(`CKP-ENG-50 the six cell states (${lang})`,()=>{
  const html=view([
   account('ok',[win('5h',75,90),win('week',40,3000)]),
   account('loading',[win('5h',null,null)],{state:'loading'}),
   account('error',[],{state:'error'}),
   account('stale',[win('5h',62,90),win('week',41,3000)],{state:'stale'}),
   account('used',[win('5h',0,90),win('week',30,3000)]),
   account('quota',[win('5h',80,90)],{support:'quota-only'}),
  ],lang);
  // Normal: number, side text (the countdown), bar and time dots.
  assert.deepEqual(values(col(html,'ok')),['75','40']);assert.deepEqual(lines(col(html,'ok')).map(l=>l.full),['1h30','2d2h']);
  // Loading: a dark placeholder block in every row, no text and no number.
  const loading=col(html,'loading');
  assert.equal((loading.match(/class="qph"/g)||[]).length,3);assert.equal(values(loading).length,0);assert.equal(lines(loading).length,0);
  // Unreadable: dim "--" with grey "no reading" / "读不到", also when the reader sent no windows at all.
  const error=col(html,'error');
  assert.deepEqual(values(error),['--']);assert.deepEqual(lines(error),[{cls:'dim',full:unreadable}]);
  // Stale: drawn exactly like a normal reading (no age text, no grey column).
  const stale=col(html,'stale');
  assert.deepEqual(lines(stale).map(l=>l.full),['1h30','2d2h']);assert.ok(!html.includes('data-col="stale" data-state="stale" class'));
  assert.doesNotMatch(html,/class="ec grey[^"]*" data-col="stale"/);
  // Used up: red 0% and "used up" / "已用完".
  const used=col(html,'used');
  assert.equal(values(used)[0],'0');assert.deepEqual(lines(used)[0],{cls:'crit',full:usedUp});assert.match(used,/qcell lv-low/);
  // No usage record: the usage cell says "quota only".
  assert.match(col(html,'quota'),new RegExp(`<span class="qq">${quotaOnly}</span>`));
  assert.doesNotMatch(col(html,'ok'),/class="qq"/);
 });

test('CKP-ENG-50 the hover of a reading with an unknown reset says so (macrevb-1020-2)',()=>{
 const html=view([account('a',[win('5h',75,null),win('week',40,3000)])]);
 const cells=[...html.matchAll(/<div class="qcell[^"]*"[^>]*>/g)].map(m=>m[0]);
 assert.match(cells[0],/data-tip="[^"]*reset \?/,'the unknown-reset cell carries a visible hover');
 assert.doesNotMatch(cells[1],/data-tip=/,'a cell with a known reset shows its time instead');
});

for(const [lang,tag] of [['en','MCP · mo'],['zh-CN','MCP · 月']])test(`CKP-ENG-51 the Other row's tag and +N (${lang})`,()=>{
 const extras=[{...win('month',30,9000),name:'MCP',period:'month'},{...win('month',60,9000),name:'Search',period:'month'}];
 const html=view([account('a',[win('5h',75,90),win('week',40,3000)],{extras})],lang);
 const other=[...html.matchAll(/data-row="other"[^>]*data-tag="([^"]*)" data-more="(\d)"/g)][0];
 assert.equal(other[1],tag);assert.equal(other[2],'1');
 assert.match(lines(html).at(-1).full,new RegExp(`^${tag} .* \\+1$`));
});

for(const [lang,cards,points] of [['en','2 resets · expires in 30h','Credits 2,368'],['zh-CN','重置 2 次 · 30h 后到期','点数 2,368']])
 test(`CKP-ENG-52 the reserve row names what it holds and leaves out zeros (${lang})`,()=>{
  const html=view([account('a',[win('5h',75,90)],{cards:[{count:2,expiresAt:NOW+30*H}],credits:{balance:2368}}),
   account('b',[win('5h',75,90)],{cards:[{count:0,expiresAt:NOW+30*H}],credits:{balance:0}})],lang);
  const a=col(html,'a'),b=col(html,'b');
  assert.match(a,new RegExp(`<span class="qrv-c[^"]*" data-full="${cards}"`));assert.match(a,new RegExp(`>${points}</span>`));
  assert.doesNotMatch(b,/qrv-c|qrv-p/,'nothing that is zero is shown');
  // Nothing anywhere: no reserve row at all.
  assert.equal(model([account('c',[win('5h',75,90)],{cards:[{count:0,expiresAt:null}],credits:{balance:0}})],lang).reserve,false);
 });

for(const [lang,label] of [['en','Today'],['zh-CN','今天']])test(`CKP-ENG-53 the range row: ≈cost first, then tokens, then speed (${lang})`,()=>{
 const html=view([account('a',[win('5h',75,90)],{todayTokens:212e6,todayAverageGenerationTps:52,rangeCost:64.2})],lang);
 const row=html.match(/<div class="qrow qrow-t"[^]*?<\/div>/)[0];
 const order=[...row.matchAll(/class="(qcost|qtokens|qaverage)"/g)].map(m=>m[1]);
 assert.deepEqual(order,['qcost','qtokens','qaverage']);
 assert.match(row,/<span class="qcost" title="[^"]+" aria-label="≈\$64 · [^"]+">≈\$64<\/span>/);
 // No price: no ≈$ at all, never a guess.
 assert.doesNotMatch(view([account('b',[win('5h',75,90)],{todayTokens:212e6})],lang),/qcost/);assert.match(row,/212M/);assert.match(row,/52<em> t\/s<\/em>/);
 // The narrow class keeps the same words: speed and then tokens drop when they do not fit, never "42/s".
 assert.match(html,new RegExp(`<span class="lb lb-t"[^>]*>${label}</span>`));
});

test('CKP-ENG-53 ≈cost format (§0): two significant figures under $100, whole dollars to $1k, then k',()=>{
 assert.equal(approxCost(64.2),'≈$64');assert.equal(approxCost(6.43),'≈$6.4');assert.equal(approxCost(0.042),'≈$0.042');
 assert.equal(approxCost(123.6),'≈$124');assert.equal(approxCost(1234),'≈$1.2k');assert.equal(approxCost(99.7),'≈$100');
 assert.equal(approxCost(null),null);assert.equal(approxCost(Number.NaN),null);assert.equal(approxCost(0),null);
});

for(const [lang,text] of [['en','out ~40m'],['zh-CN','约40m用完']])test(`CKP-ENG-26 (amended) the run-out wording (${lang})`,()=>{
 const html=view([account('a',[win('5h',60,null,{trend:-1,runOutMin:40}),win('week',80,null)],{forecast:{runOutMin:40}})],lang);
 assert.equal(lines(html)[0].full,text);
});

test('§0 times never read "1h60"',()=>{
 assert.equal(dhm(119.7),'2h00');assert.equal(dhm(179.6),'3h00');assert.equal(dhm(1439.8),'1d0h');assert.equal(dhm(40),'40m');assert.equal(dhm(198),'3h18');
});

test('CKP-ENG-54 an alert washes its column; unreadable and stale readings never wash',()=>{
 const alerts=['a','s','e'].map(sub=>({level:'red',sub}));
 const html=view([account('a',[win('5h',10,90)]),account('s',[win('5h',10,90)],{state:'stale'}),account('e',[],{state:'error'})],'en',alerts);
 assert.match(html,/class="ec tint-red" data-col="a"/);
 assert.doesNotMatch(html,/tint-[a-z]+[^"]*" data-col="s"/);assert.doesNotMatch(html,/tint-[a-z]+[^"]*" data-col="e"/);
});

test('CKP-ENG-56 at most one quiet add affordance, in the first empty bay',()=>{
 for(const n of [1,2]){const html=view(Array.from({length:n},(_,i)=>account('m'+i,[win('5h',75,90)])));
  assert.equal((html.match(/class="ec-add"/g)||[]).length,1);
  assert.match(html.split('ec ec-bay')[1],/class="ec-add"/,'the first empty bay');}
 assert.equal((view(['a','b','c'].map(id=>account(id,[win('5h',75,90)]))).match(/class="ec-add"/g)||[]).length,0);
 // Page 2 of seven subscriptions: its empty bays stay blank (CKP-ENG-03).
 setLanguage('en');
 const m=engineModel({accounts:Array.from({length:7},(_,i)=>account('p'+i,[win('5h',75,90)])),alerts:[],now:NOW},{few:'a',page:1,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang:'en',now:NOW});
 assert.equal((engineView(m,{lang:'en',now:NOW}).match(/class="ec-add"/g)||[]).length,0);
});

const wire=(observed,{valueState='current',failure=null}={})=>({valueState,observedAt:observed==null?null:new Date(NOW-observed*60000).toISOString(),lastFailure:failure==null?null:{at:new Date(NOW-failure*60000).toISOString(),code:'network'},windows:[]});
test('CKP-ENG-50 the wire account maps to the cell state',()=>{
 assert.equal(accountState(wire(3)),'ok');assert.equal(accountState(wire(30,{valueState:'retained'})),'stale');
 assert.equal(accountState(wire(null,{valueState:'none'})),'loading');
 assert.equal(accountState(wire(null,{valueState:'none',failure:1})),'error');
 assert.equal(accountState({...wire(null,{valueState:'none'}),lastFailure:{at:new Date(NOW).toISOString(),code:'reader_busy'}}),'loading');
});

test('CKP-ENG-55 the footer reads the oldest shown reading, and says so when reads keep failing (macrevb-1020-1)',()=>{
 // Six shown readings three minutes old; a seventh (on another page) an hour old: the shown page says 3 minutes.
 assert.deepEqual(footerState([wire(3),wire(3),wire(4)]),{at:NOW-4*60000,failing:false});
 assert.deepEqual(footerState([]),{at:null,failing:false});
 // A retained reading whose later reads failed: the line says no new data and offers a retry.
 assert.deepEqual(footerState([wire(3),wire(12,{valueState:'retained',failure:1})]),{at:NOW-12*60000,failing:true});
 // A failure older than the reading, or a current reading with a failure, is not "no new data".
 assert.equal(footerState([wire(12,{valueState:'retained',failure:20})]).failing,false);
 assert.equal(footerState([wire(2,{failure:1})]).failing,false);
});

test('CKP-ENG-27 a plan is dropped only when the name already says it as a word (glm-1020-3)',()=>{
 const plan=en=>({plan:{name:{en,zh:en}}});
 assert.equal(accountLabel('MaxCompute',plan('Max'),'en'),'MaxCompute Max');
 assert.equal(accountLabel('Claude Max',plan('Max'),'en'),'Claude Max');
 assert.equal(accountLabel('Codex',plan('Pro 200'),'en'),'Codex Pro 200');
 assert.equal(accountLabel('Codex Pro 200',plan('pro 200'),'en'),'Codex Pro 200');
 assert.equal(accountLabel('智谱 GLM 编程套餐',plan('编程套餐'),'zh-CN'),'智谱 GLM 编程套餐');
});

test('an established ZCode column renders unavailable without adopting a session',()=>{
 for(const state of ['failed','empty']){
  const account={route:'unknown',valueState:'none',windows:[]};
  const row={id:'zai',state,surfaces:['dock','menu','settings'],accounts:[account]};
  const members=cockpitMembers({projection:{rows:[row]},subscriptions:[]});
  assert.equal(members.length,1);
  assert.equal(members[0].key,'zai#unknown');
  assert.ok(unavailableZCodeMember(row,account));
  assert.equal(accountState(account,row.state),'error');
  assert.equal(sessionMember(members,{source:'zcode',subscriptionRef:null}),null);
  assert.equal(sessionMember(members,{source:'zcode',subscriptionRef:'previous-account'}),null);
 }
});
