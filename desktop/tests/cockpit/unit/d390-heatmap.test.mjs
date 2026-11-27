// SPDX-License-Identifier: MIT
// D390 (CKP-MFD-62): the Overview's Grid key switches to the day-by-hour heatmap of the current range.
process.env.TZ='America/Los_Angeles'; // 2026-11-01 DST end sits inside the 7-day range
import test from 'node:test';
import assert from 'node:assert/strict';
import {overview,heatCells} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';
globalThis.document??={documentElement:{}};

const HOUR=36e5,now=new Date(2026,10,4,12,30).getTime(),top=new Date(2026,10,4,12).getTime();
const A={id:'member0',short:'Pro',name:'Pro',colour:'#6aa8ff',vendor:'openai'};
const instants=Array.from({length:48},(_,i)=>top-(47-i)*HOUR);
const at=(d,h)=>instants.indexOf(new Date(2026,10,d,h).getTime());
function data(set){const values=Array(48).fill(null);for(const [d,h,v] of set)values[at(d,h)]=v;
 return {now,accounts:[A],alerts:[],daily:[{accountId:A.id,values:Array(182).fill(null),imported:[],coverageStart:0}],hourly:[{accountId:A.id,instants:instants.slice(24),values:values.slice(24)}],hourlyLong:[{accountId:A.id,instants,values}]};}
const ui=days=>({lang:'en',days,stack:true,chart:'grid',scope:null,fill:{ov:{w:300,h:110}}});

test('D390 the chart key switches between bars and grid and stack belongs to bars only',()=>{
 const keys=u=>overview.optionKeys({range:'7d',lang:'en',...u});
 assert.equal(keys({chart:'bars'})[0].b.value,'grid');
 assert.equal(overview.onClick('opt','chart',{chart:'bars'}).patch.mfdChart,'grid');
 assert.equal(overview.onClick('opt','chart',{chart:'grid'}).patch.mfdChart,'bars');
 assert.equal(keys({chart:'bars'})[2]?.id,'stack');
 assert.equal(keys({chart:'grid'})[2],null);
});
test('D390 the key hint follows the mode',()=>{
 setLanguage('en');
 const hint=c=>overview.optionKeys({range:'7d',lang:'en',chart:c})[0].hint;
 assert.match(hint('bars'),/bar/i);assert.match(hint('grid'),/hour/i);assert.notEqual(hint('bars'),hint('grid'));
});
test('D390 heatCells: one column per day of the range, four-hour bands as rows, only recorded hours count',()=>{
 const d=data([[4,9,500],[4,10,300],[3,22,1000],[3,23,400],[3,13,0]]);
 const g=heatCells(d,ui(7));
 assert.equal(g.cols,7);assert.equal(g.rows,6);
 const cell=(day,band)=>g.cells.find(c=>c.col===7-1-(4-day)&&c.row===band);
 assert.equal(cell(4,2).total,800);   // 08-12h: 9h and 10h
 assert.equal(cell(3,5).total,1400);  // 20-24h
 assert.equal(cell(3,3).total,0);     // 12-16h: a recorded zero
 assert.equal(cell(3,3).step,0);
 assert.equal(g.cells.filter(c=>c.recorded).length,3);
 assert.equal(g.cells.filter(c=>c.recorded).every(c=>c.col>=5),true,'days the series has no hours for draw nothing');
});
test('D390 heatCells: Today is one row of hours; no hourly series is no record, not invented',()=>{
 const g=heatCells(data([[4,9,500]]),ui(24));
 assert.equal(g.cols,24);assert.equal(g.rows,1);assert.equal(g.cells.filter(c=>c.recorded).length,1);assert.equal(g.cells.find(c=>c.recorded).col,9);
 const none=heatCells({...data([]),hourly:[],hourlyLong:[]},ui(7));
 assert.equal(none.cells.filter(c=>c.recorded).length,0);
 setLanguage('en');
 const html=overview.render({...data([]),hourly:[],hourlyLong:[]},ui(7));
 assert.doesNotMatch(html,/<rect class="hm/);assert.match(html,/hour/i);
});
test('D390 grid render draws the heatmap svg with tips',()=>{
 setLanguage('en');
 const html=overview.render(data([[4,9,500],[3,22,1000]]),ui(7));
 assert.match(html,/<svg class="ov-heat/);assert.equal((html.match(/<rect class="hm /g)||[]).length,2);assert.match(html,/data-tip="[^"]*Nov 4/);
});

// D402: the wire keeps 30 days of hourly rows, so the 7天 and 30天 grids fill (no "only two days" note).
function fullMonth(){
 const n=30*24,long=Array.from({length:n},(_,i)=>top-(n-1-i)*HOUR);
 return {now,accounts:[A],alerts:[],daily:[{accountId:A.id,values:Array(182).fill(null),imported:[],coverageStart:0}],hourly:[],hourlyLong:[{accountId:A.id,instants:long,values:long.map(()=>10)}]};
}
test('D402 7天 and 30天 grids fill every day and band up to the current hour',()=>{
 for(const days of [7,30]){
  const g=heatCells(fullMonth(),ui(days));
  assert.equal(g.cols,days);assert.equal(g.rows,6);
  // Today has only hours up to 12:00 (bands 0-3); every other cell of every day is recorded.
  assert.equal(g.cells.filter(c=>c.recorded).length,days*6-2,`${days}天`);
  assert.equal(g.cells.filter(c=>!c.recorded).every(c=>c.col===days-1&&c.row>=4),true);
  assert.equal(g.cells.find(c=>c.col===0&&c.row===0).total,40,'the oldest day of the range has its hours');
 }
});
test('D402 the grid drops the two-day note and fills the 30-day render',()=>{
 setLanguage('en');
 const html=overview.render(fullMonth(),ui(30));
 assert.doesNotMatch(html,/today and yesterday|hm-since/i);
 assert.equal((html.match(/<rect class="hm /g)||[]).length,30*6-2);
});
