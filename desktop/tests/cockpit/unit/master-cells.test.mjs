// SPDX-License-Identifier: MIT
// D474 (master spec round 5) for the band cells, #1290: one time format (§2.1), one width threshold (§6.1), the amber
// rule of decision 2 (C9), two lines per cell (§3.2, decision 1, C26), the lapse rule (§3.4) and the C33 names.
// Pure study model/view; synthetic data only. The built page is checked by browser/master-cells.spec.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {engineModel,levelOf,widthClass,WIDE_MIN} from '../../../cockpit/study/rocket-r1/engine-model.js';
import {engineView} from '../../../cockpit/study/rocket-r1/engine-view.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import {countdown,ago,estimateAt} from '../../../cockpit/study/rocket-r1/mfd-pages/engine-fmt.js';

globalThis.document??={documentElement:{}};
const NOW=Date.UTC(2026,10,27,12);
const win=(kind,remaining,resetIn,extra={})=>({kind,remaining,resetIn,resetAt:null,resetText:null,elapsed:null,trend:null,runOutMin:null,durationMinutes:null,...extra});
const account=(id,windows,more={})=>({id,name:id,short:id,alias:id,colour:'#888888',logo:'x.svg',state:'ok',support:'observed',todayTokens:null,windows,extras:[],forecast:null,...more});
const model=(accounts,lang,ui={})=>engineModel({accounts,alerts:[],now:NOW},{few:'c3',page:0,scope:null,tint:true,pctMode:'left',redAt:25,ack:null,lang,now:NOW,...ui});
const view=(accounts,lang='zh-CN',ui={})=>{setLanguage(lang);return engineView(model(accounts,lang,ui),{changed:new Set(),lang,now:NOW});};
const cellsOf=html=>[...html.matchAll(/<div class="qcell([^"]*)" data-row="(\w+)"[^]*?<\/div>/g)].map(m=>({cls:m[1],row:m[2],html:m[0],
 value:(m[0].match(/class="qvalue">([^<]*)</)||[])[1],l1:(m[0].match(/class="qtxt ql1([^"]*)" data-full="([^"]*)"/)||[])[2],l2:(m[0].match(/class="qtxt ql2([^"]*)" data-full="([^"]*)"/)||[])[2],l2cls:((m[0].match(/class="qtxt ql2([^"]*)"/)||[])[1]||'').trim()}));
const fiveCols=(first,lang)=>view([first,...['b','c','d','e'].map(id=>account(id,[win('5h',90,60)]))],lang);// narrow

test('§2.1 countdown: 4d14h / 3h09 / 42m; narrow rounds ten days or more to whole days',()=>{
 assert.equal(countdown(6600),'4d14h');assert.equal(countdown(189),'3h09');assert.equal(countdown(42),'42m');
 assert.equal(countdown(119.7),'2h00');assert.equal(countdown(0.2),'1m');assert.equal(countdown(null),'--');
 assert.equal(countdown(14*1440+23*60),'14d23h');assert.equal(countdown(14*1440+23*60,{narrow:true}),'15d');
 assert.equal(countdown(9*1440+23*60,{narrow:true}),'9d23h');
 assert.equal(ago(28),'28m前');assert.equal(ago(100),'1h40前');assert.equal(ago(3060),'2d3h前');assert.equal(ago(28,'en'),'28m ago');
 const at=Date.UTC(2026,10,27,9,14);assert.match(estimateAt(at),/ 前后$/);assert.match(estimateAt(at,{lang:'en'}),/^around /);
});

test('§6.1 one threshold: measured column width 140 pt; unmeasured: up to 3 columns are wide',()=>{
 assert.equal(WIDE_MIN,140);
 assert.equal(widthClass(6,139.9),'narrow');assert.equal(widthClass(6,140),'wide');assert.equal(widthClass(3,107.6),'narrow');
 for(const [n,cls] of [[1,'wide'],[3,'wide'],[4,'narrow'],[5,'narrow'],[6,'narrow']])assert.equal(widthClass(n),cls);
 assert.equal(model([account('a',[win('5h',50,60)])],'en',{colWidth:120}).cls,'narrow');
});

test('decision 2 (C9): amber only when the estimate runs out before the reset; red at the line, used up or drawing',()=>{
 assert.equal(levelOf(45),'ok','no 50 % rule');assert.equal(levelOf(45,25,{runOutBefore:true}),'mid');
 assert.equal(levelOf(25),'low');assert.equal(levelOf(0),'low');assert.equal(levelOf(60,25,{drawing:true}),'low');
 assert.equal(levelOf(null),'none');
 const m=model([account('a',[win('5h',60,240,{trend:-1,runOutMin:120}),win('week',40,3000,{trend:-1,runOutMin:4000})],{forecast:{runOutMin:120}})],'zh-CN');
 assert.equal(m.cols[0].cells.first.level,'mid');assert.equal(m.cols[0].cells.second.level,'ok','an estimate after the reset is not amber');
});

for(const [lang,reset,resetN,est,estN,lasts,lastsN] of [['zh-CN','4d14h 后重置','4d14h后','预估 2d16h 用完','2d16h完','够用到重置','够用'],['en','resets in 4d14h','in 4d14h','est. out in 2d16h','out 2d16h','lasts to reset','lasts']])
 test(`decision 1 (C26): two lines per cell, wide and narrow (${lang})`,()=>{
  const a=account('a',[win('5h',90,300,{lasts:true}),win('week',53,6600,{trend:-1,runOutMin:3840})],{forecast:{runOutMin:3840}});
  const wide=cellsOf(view([a],lang));
  assert.deepEqual([wide[1].l1,wide[1].l2,wide[1].l2cls],[reset,est,'warn'],'line 1 reset (never coloured), line 2 amber estimate');
  assert.equal(wide[0].l2,lasts);assert.equal(wide[0].l2cls,'','够用 stays ink-3');
  assert.doesNotMatch(wide[1].html,/qtxt ql1 (warn|crit)/,'the reset line is never coloured');
  const narrow=cellsOf(fiveCols(a,lang));
  assert.deepEqual([narrow[1].l1,narrow[1].l2],[resetN,estN]);assert.equal(narrow[0].l2,lastsN);
  assert.doesNotMatch(view([a],lang)+fiveCols(a,lang),/…|约|~/);
 });

for(const [lang,usedUp,unread,fail] of [['zh-CN','已用完','读不到','失败·2h'],['en','used up','no reading','Fail·2h']])
 test(`used up, kept and lapsed readings (${lang})`,()=>{
  const used=cellsOf(view([account('a',[win('5h',0,198)])],lang))[0];
  assert.equal(used.value,'0');assert.equal(used.l2,usedUp);assert.equal(used.l2cls,'crit');assert.match(used.l1,/3h18/);
  // §3.4: a kept reading keeps its numbers with 失败·2h; once its reset passes it lapses to -- 读不到, column kept.
  const kept=account('k',[win('5h',70,30),win('week',40,3000)],{state:'error-lastgood',ageMin:120});
  const [k5,kw]=cellsOf(view([kept],lang));
  assert.equal(k5.value,'70');assert.equal(k5.l1,fail);assert.equal(kw.value,'40');
  const lapsed=account('k',[win('5h',70,0,{resetPassed:true}),win('week',40,3000)],{state:'error-lastgood',ageMin:400,attemptAt:NOW-30*60000});
  const [l5,lw]=cellsOf(view([lapsed],lang));
  assert.equal(l5.value,'--');assert.equal(l5.l1,unread);assert.match(l5.cls,/\blapsed\b/);assert.equal(lw.value,'40','only the lapsed window');
  const noReset=account('k',[win('5h',70,null)],{state:'error-lastgood',ageMin:1500});
  assert.equal(cellsOf(view([noReset],lang))[0].value,'--','no reset time: lapses after 24 h');
 });

test('C33: a cell names its extra window only under the 额外 heading; narrow moves the name to line 1 or the hover',()=>{
 const mcp=(id,more={})=>account(id,[win('5h',90,60)],{extras:[{...win('month',100,21540),name:'MCP',named:true,period:'month',...more}]});
 const same=cellsOf(view([mcp('a'),mcp('b')],'zh-CN')).filter(c=>c.row==='other');
 assert.ok(same.every(c=>!c.l1.includes('MCP')),'the heading names it once');
 const mixed=[mcp('a'),account('b',[win('5h',90,60)],{extras:[{...win('week',64,3000),name:'Opus',named:true,period:'week'}]})];
 const wide=cellsOf(view(mixed,'zh-CN')).filter(c=>c.row==='other');
 assert.equal(wide[0].l1,'MCP 14d23h 后重置');assert.match(wide[0].html,/MCP · 每月额度/);
 const narrow=cellsOf(view([...mixed,...['c','d','e'].map(id=>account(id,[win('5h',90,60)]))],'zh-CN')).filter(c=>c.row==='other');
 assert.deepEqual([narrow[0].l1,narrow[0].l2],['MCP','15d后'],'narrow: name on line 1, reset on line 2');
 const est=[mcp('a',{trend:-1,runOutMin:600}),...mixed.slice(1),...['c','d','e'].map(id=>account(id,[win('5h',90,60)]))];
 const withEst=cellsOf(view(est,'zh-CN')).filter(c=>c.row==='other')[0];
 assert.deepEqual([withEst.l1,withEst.l2],['15d后','10h00完'],'narrow with an estimate: the name moves into the hover');
 assert.match(withEst.html,/data-hc="[^"]*MCP · 每月额度/);
});

for(const [lang,line,narrow] of [['zh-CN',['重置 3 次','1 次 40h 后到期'],['3次','40h到期']],['en',['3 resets','1 expires in 40h'],['3 resets','1 exp. 40h']]])
 test(`§3.1 reserve line: only the clause is amber, points drop first when narrow, +1 is plain blue text (${lang})`,()=>{
  const a=account('z',[win('5h',90,60)],{cards:[{count:1,expiresAt:NOW+40*3600e3},{count:2,expiresAt:null}],credits:{balance:1865},plus:1});
  const row=html=>html.match(/<div class="qrow qrow-r[^"]*"[^]*?<\/div>/)[0];
  const w=row(view([a],lang)),n=row(fiveCols(a,lang));
  assert.match(w,new RegExp(`class="qrv-c"(?: data-drop="")? data-full="${line[0]}"`));assert.match(w,new RegExp(`class="qrv-x warn" data-full="${line[1]}"`));
  assert.match(w,/class="qrv-p"/);assert.match(w,/<b class="qrv-plus"[^>]*>\+1<\/b>/);
  assert.match(n,new RegExp(`class="qrv-c"(?: data-drop="")? data-full="${narrow[0]}"`));assert.match(n,new RegExp(`class="qrv-x warn" data-full="${narrow[1]}"`));
  assert.doesNotMatch(n,/class="qrv-p"/,'narrow: the points drop first');
 });
