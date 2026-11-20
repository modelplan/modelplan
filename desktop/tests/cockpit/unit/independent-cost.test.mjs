// SPDX-License-Identifier: MIT
// D352 change 4: the cockpit's ≈cost cells against an independently hand-calculated fixture
// (testdata/cost-fixture/independent-cost.json). The Go side asserts the same file against the CLI cost function
// (cli/internal/cost/independent_fixture_test.go). The producer prices each request; the page only sums, so this
// feeds the fixture's hand-written per-request USD through the wire and checks the page's totals, tokens, window
// and scale against the hand-written expectations. Defects it is meant to catch: totals that count output tokens
// only, a Today that is not one local day, bars scaled from the wrong maximum (#1057).
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {costView,subscriptionCost,estCostText} from '../../../cockpit/.tmp/compiled/src/prototype-cost.js';
import {assertAscending} from '../chart-order.mjs';

const fx=JSON.parse(readFileSync(new URL('../../../../testdata/cost-fixture/independent-cost.json',import.meta.url),'utf8'));
const ref='0123456789abcdef',now=new Date(2026,10,20,12,0,0).getTime();
const near=(a,b,what)=>assert.ok(Math.abs(a-b)<1e-9,`${what}: ${a} != ${b}`);
const dayKey=off=>{const d=new Date(2026,10,20-off);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};

function wire(opts={}){
 const daily=[];
 for(const day of fx.window.days)for(const name of day.requests){
  const r=fx.requests[name];if(r.expectedUsd==null)continue;
  const tokens=r.input+r.cacheRead+r.cacheWrite+r.output+r.reasoning;
  daily.push({at:dayKey(day.dayOffset),source:'codex',estimatedUsd:r.expectedUsd,pricedTokens:tokens,unpricedTokens:0});
 }
 daily.push(...(opts.extra??[]));
 return {subscriptions:[{subscriptionRef:ref,accounts:[]}],projection:{rows:[]},
  history:{coverage:'local-history',subscriptions:[{subscriptionRef:ref,sources:[{source:'codex'}]}],
   cost:{basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-20',daily,hourly:[],models:{today:[],recent7d:[],recent30d:[]}}}};
}

test('the fixture is hand-calculated: every priced case carries its arithmetic and an expected value',()=>{
 for(const [name,r] of Object.entries(fx.requests)){assert.ok(r.arithmetic,name);assert.ok('expectedUsd' in r,name);}
 assert.ok(Object.values(fx.requests).filter(r=>r.expectedUsd!=null).every(r=>r.expectedUsd!==r.outputOnlyUsd||r.input+r.cacheRead+r.cacheWrite===0),'a case that prices only output proves nothing against an output-only sum');
});

test('Overview totals: ≈cost and tokens count every bucket, in the local Today, 7 and 30 day windows',()=>{
 const v=costView(wire(),now),e=fx.window.expected;
 assert.ok(v);
 for(const [range,key] of [['today','today'],['last7d','last7d'],['last30d','last30d']]){
  near(v.total[range].cost.usd,e[key].usd,`${range} usd`);
  assert.equal(v.total[range].tokens,e[key].tokens,`${range} tokens (input + cached + output + reasoning, not output only)`);
 }
 const outputOnly=fx.window.days[0].requests.reduce((s,n)=>s+fx.requests[n].outputOnlyUsd,0);
 assert.ok(Math.abs(v.total.today.cost.usd-outputOnly)>0.5,'Today must not equal the output-only sum');
 assert.equal(estCostText(v.total.today.cost.usd),'≈$1.1');
 near(subscriptionCost(v,ref).last30d.usd,e.last30d.usd,'subscription 30d');
});

test('Today is exactly one local day: yesterday and tomorrow are outside it',()=>{
 const v=costView(wire({extra:[
  {at:dayKey(1),source:'codex',estimatedUsd:50,pricedTokens:1,unpricedTokens:0},
  {at:dayKey(-1),source:'codex',estimatedUsd:70,pricedTokens:1,unpricedTokens:0}]}),now);
 near(v.total.today.cost.usd,fx.window.expected.today.usd,'today');
 near(v.total.last7d.cost.usd,fx.window.expected.last7d.usd+50,'7d takes yesterday, never tomorrow');
});

test('Overview bars: one per day, oldest first, the highest day is the hand-calculated maximum',()=>{
 const v=costView(wire(),now);
 assert.equal(v.daily.length,3,'the day 40 days back is outside the 30-day bars');
 assertAscending(v.daily.map(b=>Date.parse(b.at)),'bars oldest to newest');
 assert.equal(v.daily.at(-1).at,dayKey(0),'the newest bar is today');
 near(Math.max(...v.daily.map(b=>b.usd)),fx.window.highestDayUsd,'scale maximum (the axis tops out at the highest day)');
 near(v.daily.at(-1).usd,fx.window.expected.today.usd,'today bar height');
});

test('a range with no priced use has no figure, not $0',()=>{
 const w=wire();w.history.cost.daily=[{at:dayKey(0),source:'codex',estimatedUsd:0,pricedTokens:0,unpricedTokens:6100}];
 const v=costView(w,now);
 assert.equal(v.total.today.cost,null);assert.equal(v.total.today.unpricedShare,1);
});
