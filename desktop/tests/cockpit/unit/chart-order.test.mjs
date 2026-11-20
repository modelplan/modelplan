// SPDX-License-Identifier: MIT
// D352 change 4: chart-order assertions. The helper itself, then the Overview bars (time runs oldest -> newest, the
// newest bar last on the x axis). The resource plugin's CPU > Memory > Disk order (D347) is asserted in
// browser/resource-chart-order.spec.mjs, because that screen is drawn on the page.
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {assertChartOrder,assertAscending,orderOf,overviewBuckets} from '../chart-order.mjs';
import {overviewBars} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';
import {md} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}};
setLanguage('en');

test('the helper fails a reversed order and names both orders',()=>{
 assertChartOrder([{id:'cpu',pos:10},{id:'memory',pos:60},{id:'disk',pos:120}],['cpu','memory','disk'],'column');
 assert.throws(()=>assertChartOrder([{id:'memory',pos:10},{id:'cpu',pos:60},{id:'disk',pos:120}],['cpu','memory','disk'],'column'),/drawn order differs/);
 assert.deepEqual(orderOf([{id:'b',pos:1},{id:'a',pos:1}]),['b','a'],'ties keep input order');
 assert.throws(()=>assertChartOrder([],['a'],'empty'),/nothing was measured/);
 assert.throws(()=>assertAscending([1,3,2],'axis'),/before item/);
});

const now=new Date(2026,10,12,12).getTime();
const account={id:'a',short:'Codex',name:'Codex',colour:'#4a8cff'};
const series=values=>({now,accounts:[account],daily:[{accountId:'a',values,imported:[],coverageStart:new Date(2026,9,1).getTime()}]});

for(const stack of [true,false]){
 test(`Overview bars (${stack?'stacked':'split'}): oldest day first, today last, in x and in the tip dates`,()=>{
  const values=[1000,2000,3000,4000,5000,6000,7000],d=series(values),view={lang:'en',days:7,stack,scope:null,fill:{}};
  const svg=overviewBars(d,view,[{a:account,daily:d.daily[0]}]),buckets=overviewBuckets(svg);
  assert.equal(buckets.length,7);
  assertAscending(buckets.map(b=>b.x),'bar x positions');
  assertChartOrder(buckets.map(b=>({id:String(b.total),pos:b.x})),values.map(String),'bars by day');
  const days=Array.from({length:7},(_,i)=>md(new Date(2026,10,12-(6-i),12).getTime(),view));
  assert.deepEqual(buckets.map(b=>b.tip.split(' · ')[0]),days,'tip dates run oldest to today');
 });
}
