// SPDX-License-Identifier: MIT
// WP-08 (V1-FINAL §7): model cards. CKP-FAD-50…53: the card's lines, the 9-character rule in both languages, the
// current effort from the last 15 minutes with hysteresis, and the use / share a card shows for the time range.
import test from 'node:test';
import assert from 'node:assert/strict';
import {faderModel,cardText,effortLine,stripAria,lcdView,CARD_LINE} from '../../../cockpit/study/rocket-r1/fader-view.js';
import {approxCost,tokShort} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import {assertChartOrder} from '../chart-order.mjs';
import {cardUsage,currentEffort,CURRENT_WINDOW_MS} from '../../../cockpit/.tmp/compiled/src/model-card.js';

globalThis.document??={documentElement:{}};
const LADDER=['Low','Med','High','XHigh','Max'];
const e=LADDER.map((l,i)=>[l,40+i*3,.2*(i+1),60*(i+1)]);
const fader=(o={})=>({id:'m',name:'GPT-6.1 Sol',short:'Sol 6.1',rec:'Med',e,current:'High',currentFast:false,tier:null,live:true,pinned:false,others:{},accounts:['a'],sessions:[],...o});
const channel=(f,ui={})=>faderModel({faders:[f],accounts:[{id:'a',colour:'#6aa8ff'}]},{bank:0,bankSize:3,selModel:null,previews:{},view:null,...ui}).channels[0];
const chars=s=>[...s].length;

// D464 (amends CKP-FAD-50): tokens are the large figure; ≈cost moves to the small line with the share.
test('CKP-FAD-50 D464 a used model: name, tokens large, share bar, "≈$64 17%", "High ★Med"; no ability bars',()=>{
 setLanguage('en');
 const c=channel(fader({use:{tokens:212e6,share:.17,cost:64}}));
 assert.equal(c.card.state,'normal');assert.equal(c.card.big,'212M');assert.equal(c.card.bigKind,'tokens');
 assert.equal(c.card.bar,.17);assert.deepEqual(c.card.use,['≈$64','17%']);
 assert.deepEqual(cardText(c.card),['Sol 6.1','212M','≈$64 17%','High ★Med']);
 assert.equal(c.bars,undefined,'the five ability bars are gone (CKP-FAD-04 superseded)');
});

test('CKP-FAD-50/51 current = ★ shows only "★Med"; no public price puts tokens in the large slot and the bar by tokens',()=>{
 setLanguage('en');
 const follows=channel(fader({current:'Med',use:{tokens:480e6,share:.81,cost:310}}));
 assert.deepEqual(follows.card.eff,{cur:'',rec:'Med',note:''});
 const unpriced=channel(fader({use:{tokens:96e6,share:.02}}));
 assert.equal(unpriced.card.big,'96M');assert.equal(unpriced.card.bigKind,'tokens');assert.equal(unpriced.card.bar,.02);
});

test('CKP-FAD-51 unused, no usage record, effort unreported',()=>{
 setLanguage('zh-CN');
 const unused=channel(fader({live:false,current:null,rec:'High'}));
 assert.equal(unused.card.state,'unused');assert.deepEqual(cardText(unused.card),['Sol 6.1','未使用','★High']);
 const norecord=channel(fader({recorded:true,live:false,current:null}));
 assert.equal(norecord.card.state,'norecord');assert.equal(norecord.card.big,'无用量记录');
 const unreported=channel(fader({current:null,use:{tokens:5e6,share:.4}}));
 assert.equal(unreported.card.eff.note,'档位未报告');
 setLanguage('en');
 assert.equal(channel(fader({current:null,use:{tokens:5e6,share:.4}})).card.eff.note,'Effort ?');
});

test('CKP-FAD-52 a trial reads "试 XHigh / 当前 High" with no multiple; every card line is at most 9 characters',()=>{
 setLanguage('zh-CN');
 const tried=channel(fader({use:{tokens:212e6,share:.17}}),{previews:{m:'XHigh'},view:{modelId:'m',trial:'XHigh',fast:null,from:'fader'}});
 assert.equal(tried.card.state,'try');assert.equal(tried.card.tryLine,'试 XHigh');assert.equal(tried.card.nowLine,'当前 High');
 assert.doesNotMatch(cardText(tried.card).join('|'),/×/);
 // Every state × language × current/★/trial combination, and every name the alias table knows.
 const names=['GPT-6.1 Sol','Claude Opus 5.5','Claude Sonnet 5.5','GLM-5.3-Flash','GPT-6.1 Terra','Claude Haiku 5.5','GPT-6.2 Astra'];
 for(const lang of ['zh-CN','en']){setLanguage(lang);
  for(const name of names)for(const rec of LADDER)for(const cur of [null,...LADDER])for(const trial of [null,...LADDER])for(const use of [null,{tokens:1.23e9,share:.999,cost:12345},{tokens:830e3,share:.004}])for(const live of [true,false]){
   const c=channel(fader({name,rec,current:cur,live,use}),trial?{previews:{m:trial},view:{modelId:'m',trial,fast:null,from:'fader'}}:{});
   for(const line of cardText(c.card))assert.ok(chars(line)<=CARD_LINE,`${lang} ${name} ${cur}/${rec}/${trial}: "${line}" is ${chars(line)} characters`);
  }
 }
 assert.deepEqual(effortLine('XHigh','High'),{cur:'XHigh',rec:''},'"XHigh ★High" does not fit: the current effort alone');
 assert.deepEqual(effortLine('High','Med'),{cur:'High',rec:'Med'});
});

test('macrevb-1052-1 an unaliased long name and "1000B 100%" are bounded on the card; the accessible name keeps the full text',()=>{
 setLanguage('en');
 const c=channel(fader({name:'Future Research Model',short:'Future Research Model',use:{tokens:1000e9,share:1}}));
 for(const line of cardText(c.card))assert.ok(chars(line)<=CARD_LINE,`"${line}"`);
 assert.match(stripAria(c),/Future Research Model/);assert.match(stripAria(c),/1000B 100%/);
 const u=channel(fader({name:'Future Research Model',use:null,live:false}));
 for(const line of cardText(u.card))assert.ok(chars(line)<=CARD_LINE,`"${line}"`);
});

test('macrevb-1052-2 the lamp reads the full verified session set; an unbound running session borrows no subscription colour',()=>{
 setLanguage('en');
 const idle=n=>Array.from({length:n},()=>({sub:'a',active:false}));
 const seven=channel(fader({sessions:idle(6),lamps:[...idle(6),{sub:'a',active:true}]}));
 assert.equal(seven.session,'live');assert.equal(seven.lampColour,'#6aa8ff');
 const unbound=channel(fader({sessions:[{sub:'',active:true}],lamps:[{sub:'',active:true}]}));
 assert.equal(unbound.session,'live');assert.equal(unbound.lampColour,null,'not the first subscription colour');
 const mixed=channel(fader({lamps:[{sub:'',active:true},{sub:'a',active:true}]}));
 assert.equal(mixed.lampColour,'#6aa8ff');
});

test('CKP-FAD-53 current effort: most tokens in the last 15 minutes, with hysteresis; a notable other effort gets a dot',()=>{
 const now=Date.parse('2026-11-18T12:00:00Z'),at=m=>now-m*60e3;
 assert.deepEqual(currentEffort([{effort:'High',at:at(1),weight:40},{effort:'XHigh',at:at(2),weight:20}],now,null),{current:'High',notable:['XHigh']});
 // XHigh now leads, but not by 1.5×: the held High stays (no flicker between two close efforts).
 assert.equal(currentEffort([{effort:'High',at:at(1),weight:30},{effort:'XHigh',at:at(1),weight:40}],now,'High').current,'High');
 assert.equal(currentEffort([{effort:'High',at:at(1),weight:20},{effort:'XHigh',at:at(1),weight:40}],now,'High').current,'XHigh');
 // Older than 15 minutes does not count; without a reported effort in the window the latest session's effort is kept.
 assert.equal(currentEffort([{effort:'Low',at:now-CURRENT_WINDOW_MS-1,weight:900},{effort:'Med',at:at(3),weight:1}],now,null).current,'Med');
 assert.equal(currentEffort([{effort:'Low',at:now-CURRENT_WINDOW_MS-60e3,weight:null}],now,null).current,'Low');
 // No rates: one session counts one; a share under 25 % is not notable.
 assert.deepEqual(currentEffort([{effort:'Med',at:at(1),weight:null},{effort:'Med',at:at(2),weight:null},{effort:'Med',at:at(3),weight:null},{effort:'Max',at:at(4),weight:null}],now,null),{current:'Med',notable:['Max']});
 assert.deepEqual(currentEffort([{effort:'Med',at:at(1),weight:9},{effort:'Max',at:at(4),weight:1}],now,null).notable,[]);
 // The dot sits on the fader for the notable effort.
 const c=channel(fader({current:'High',notable:['XHigh']}));
 assert.deepEqual(c.dots.map(d=>d.e),['XHigh']);
});

test('the range use (D474 §2.5): total tokens from cost.models for every range, token share of the range total; ≈$ small; output tokens only without a publication',()=>{
 const ranking=(top,total)=>({totalObservedOutputTokens:total,top});
 const cost=(rows,today=[])=>({basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-18',daily:[],hourly:[],models:{today,recent7d:rows,recent30d:rows}});
 const row=(model,usd,priced,unpriced=0,source='codex')=>({model,source,estimatedUsd:usd,pricedTokens:priced,unpricedTokens:unpriced});
 const h={coverage:'local-history',models:{recent7d:ranking([{name:'sol',observedOutputTokens:212e6},{name:'opus',observedOutputTokens:480e6},{name:'glm',observedOutputTokens:96e6}],1247e6),recent30d:ranking([],0)}};
 // Without the cost section (no publication, or "Show estimated cost" off): the history ranking's output tokens and shares.
 assert.deepEqual(cardUsage(h,'7d').get('sol'),{tokens:212e6,share:212/1247});
 // With it: the total (priced + unpriced) of every range, the share is the token share of ALL rows, the unknown row included.
 const priced={...h,cost:cost([row('sol',64,2e9,12e6),row('opus',310,480e6),row('glm',null,0,96e6),row('unknown',null,0,10e6)])};
 const u=cardUsage(priced,'7d'),total=2e9+12e6+480e6+96e6+10e6;
 assert.deepEqual(u.get('sol'),{tokens:2e9+12e6,share:(2e9+12e6)/total,cost:64},'tokens are the TOTAL, not the output ranking');
 assert.deepEqual(u.get('glm'),{tokens:96e6,share:96e6/total},'no public price: tokens and token share, no ≈$');
 assert.equal(u.has('unknown'),false,'the unknown row has no card, but stays in the denominator');
 // A model on two sources is one card: the rows are summed.
 const two=cardUsage({...h,cost:cost([row('sol',10,100e6,0,'codex'),row('sol',5,50e6,0,'zcode'),row('opus',1,50e6)])},'7d');
 assert.deepEqual(two.get('sol'),{tokens:150e6,share:.75,cost:15});
 // Every range reads cost.models: today and 30 days too, even where the output ranking has nothing.
 assert.deepEqual(cardUsage({...h,cost:cost([],[row('sol',3.1,9e6,1e6)])},'today').get('sol'),{tokens:10e6,share:1,cost:3.1});
 assert.equal(cardUsage({...priced,cost:{...priced.cost,currency:'EUR'}},'7d').get('sol').cost,undefined,'an unusable section falls back to the output ranking');
 assert.equal(cardUsage(h,'30d').size,0);assert.equal(cardUsage(h,'today').size,0);
 assert.equal(cardUsage({...h,coverage:'none'},'7d').size,0);assert.equal(cardUsage(null,'7d').size,0);
 // Chart-order: the card bank keeps the publication's order; the usage map never reorders it (the caller indexes by id).
 const ids=['opus','sol','glm'];assertChartOrder(ids.map((id,i)=>({id,pos:i*10})),['opus','sol','glm'],'bank order');
});

test('LBL-2.2-51 ≈cost and token formats on the card',()=>{
 assert.deepEqual([64,9.1,0.42,310,99.4,1234,12345].map(approxCost),['≈$64','≈$9.1','≈$0.42','≈$310','≈$99','≈$1.2k','≈$12k']);
 assert.deepEqual([212e6,4.2e6,830e3,1.23e9,12.4e9,512].map(tokShort),['212M','4.2M','830k','1.2B','12B','512']);
});

// Owner 11-21 (G3-144…): the cost in the card's large slot never clips, and the unknown current effort says what it is.
// D464: the cost moved to the small line; it keeps the G3-145 short form (the full estimate stays in useFull).
test('G3-145 D464 the card cost is a short form on the small line: under $0.01 "<$0.01", under $1 two decimals; the accessible text keeps the estimate',()=>{
 setLanguage('en');
 const card=cost=>channel(fader({use:{tokens:432,share:.01,cost}})).card;
 assert.equal(card(0.004).use[0],'<$0.01');assert.equal(card(0.004).useFull[0],'≈$0.004');
 assert.equal(card(0.012).use[0],'≈$0.01');assert.equal(card(0.42).use[0],'≈$0.42');
 assert.equal(card(9.1).use[0],'≈$9.1');assert.equal(card(1234).use[0],'≈$1.2k');
 assert.equal(card(9.1).big,'432');
 for(const v of [0.0004,0.004,0.012,0.09,0.42,0.999,1,9.1,64,310,1234,12345])assert.ok(chars(card(v).use.join(' '))<=9,`${v} -> ${card(v).use}`);
});

// G3-146 named the unknown current effort "档位未报告" / "Effort ?" and banned the "当前未报告" look. G3-182 (owner row 35,
// build 2): under a trial line ("试 XHigh") that second line read as a contradiction, so a trial card with no reported
// current drops the line; the wording itself stays on the non-trial card's note (CKP-FAD-51 above).
test('G3-182 a trial on a model with no reported current shows the trial alone, no "档位未报告" line',()=>{
 for(const lang of ['zh-CN','en']){
  setLanguage(lang);
  const c=channel(fader({current:null,use:{tokens:5e6,share:.4}}),{previews:{m:'XHigh'},view:{modelId:'m',trial:'XHigh',fast:null,from:'fader'}});
  assert.equal(c.card.state,'try');assert.equal(c.card.tryLine,lang==='zh-CN'?'试 XHigh':'Try XHigh');
  assert.equal(c.card.nowLine,'');assert.doesNotMatch(lcdView(c),/cd-now/);
  assert.doesNotMatch(lcdView(c),/档位未报告|Effort \?/);assert.match(lcdView(c),/cd-try/);
 }
 setLanguage('zh-CN');
 const known=channel(fader({current:'High',use:{tokens:5e6,share:.4}}),{previews:{m:'XHigh'},view:{modelId:'m',trial:'XHigh',fast:null,from:'fader'}});
 assert.equal(known.card.nowLine,'当前 High');
 setLanguage('en');
});

// G3-181 (owner row 33, build 2): the subscription-colour top edge is for cards with use (or live ones); a card the
// range shows as unused carries no strip, so it no longer reads as active.
test('G3-181 an unused card carries no vendor strip; used, live and no-record cards keep it',()=>{
 // G3-181: owner row 33 (build 2, screenshot 20261122-141638): unused cards still showed the blue top edge.
 setLanguage('zh-CN');
 const unused=channel(fader({live:false,current:null,rec:'High'}));
 assert.equal(unused.card.state,'unused');assert.doesNotMatch(lcdView(unused),/st-vend/);
 for(const f of [fader({use:{tokens:5e6,share:.4}}),fader({current:null,use:{tokens:5e6,share:.4},live:true}),fader({recorded:true,live:false,current:null})]){
  const c=channel(f);
  assert.notEqual(c.card.state,'unused');assert.match(lcdView(c),/st-vend/);
 }
 setLanguage('en');
});
