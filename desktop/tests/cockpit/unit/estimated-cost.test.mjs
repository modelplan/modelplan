// SPDX-License-Identifier: MIT
// WP-06: ≈cost reaches the page's view model from the wire, and only from it (COST-52…54, SET-9-50).
import test from 'node:test';
import assert from 'node:assert/strict';
import {costView,subscriptionCost,withoutEstimatedCost,estCostText} from '../../../cockpit/.tmp/compiled/src/prototype-cost.js';
import {prototypeEngineSupplement} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';
import {sample} from '../fixture.mjs';

const refA='0123456789abcdef',refB='fedcba9876543210';
const now=new Date(2026,10,5,12,0,0).getTime();
const day=n=>{const d=new Date(2026,10,5-n);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const sums={totalTokens:0,inputTokens:null,outputTokens:0,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:0,eligibleRequests:0};
function data(withCost=true){
 const history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:null,daily:[],hourly:[],cycles:[],
  models:{measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}},tools:{measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}},
  projects:{recent7d:[],recent30d:[]},
  subscriptions:[{subscriptionRef:refA,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums,recent30d:sums}]},{subscriptionRef:refB,sources:[{source:'claude-code',bindingBasis:'source-wide-current-binding',recent7d:sums,recent30d:sums}]}]};
 if(withCost)history.cost={basis:'api-list-price',currency:'USD',pricesAsOf:'2026-11-04',
  daily:[
   {at:day(0),source:'codex',estimatedUsd:10.2,pricedTokens:33900000,unpricedTokens:0},
   {at:day(0),source:'claude-code',estimatedUsd:0,pricedTokens:0,unpricedTokens:700},
   {at:day(2),source:'claude-code',estimatedUsd:5,pricedTokens:1000,unpricedTokens:0,approximate:true},
   {at:day(10),source:'codex',estimatedUsd:50,pricedTokens:5000,unpricedTokens:300},
   {at:day(10),source:'opencode',estimatedUsd:1,pricedTokens:100,unpricedTokens:0},
   {at:day(40),source:'codex',estimatedUsd:999,pricedTokens:1,unpricedTokens:0}],
  hourly:[{at:new Date(2026,10,5,10).toISOString(),source:'codex',estimatedUsd:3,pricedTokens:10,unpricedTokens:0}],
  models:{today:[{model:'sol',source:'codex',estimatedUsd:10.2,pricedTokens:33900000,unpricedTokens:0},{model:'sonnet',source:'claude-code',estimatedUsd:null,pricedTokens:0,unpricedTokens:700}],
   recent7d:[{model:'sol',source:'codex',estimatedUsd:10.2,pricedTokens:33900000,unpricedTokens:0},{model:'opus',source:'claude-code',estimatedUsd:5,pricedTokens:1000,unpricedTokens:0,approximate:true},{model:'opus',source:'opencode',estimatedUsd:1,pricedTokens:100,unpricedTokens:0}],
   recent30d:[]}};
 return {subscriptions:[{subscriptionRef:refA,accounts:[]},{subscriptionRef:refB,accounts:[]}],projection:{rows:[]},history};
}

test('the ≈cost view sums each range from the wire and keeps unpriced use out of ≈cost',()=>{
 const v=costView(data(),now);
 assert.equal(v.pricesAsOf,'2026-11-04');
 assert.deepEqual(v.total.today.cost,{usd:10.2,approximate:false});
 assert.equal(v.total.today.unpricedShare,700/33900700);
 assert.deepEqual(v.total.last7d.cost,{usd:15.2,approximate:true});
 assert.deepEqual(v.total.last30d.cost,{usd:66.2,approximate:true},'a day before the 30-day range is left out');
 assert.deepEqual(subscriptionCost(v,refA),{today:{usd:10.2,approximate:false},last7d:{usd:10.2,approximate:false},last30d:{usd:60.2,approximate:false}});
 assert.equal(subscriptionCost(v,refB).today,null,'a subscription with only unpriced use today has no ≈$, not $0');
 assert.equal(subscriptionCost(v,'1111111111111111'),null);
 // Bars: unpriced buckets draw nothing; an unbound source stays unattributed.
 assert.deepEqual(v.daily.map(b=>[b.at,b.subscriptionRef,b.usd]),[[day(10),null,1],[day(10),refA,50],[day(2),refB,5],[day(0),refA,10.2]]);
 assert.equal(v.hourly.length,1);
 // Models: one row per model across sources, ranked by ≈cost; no price → no share, token share instead.
 assert.deepEqual(v.models.last7d.map(m=>[m.model,m.cost?.usd,m.share]),[['sol',10.2,10.2/16.2],['opus',6,6/16.2]]);
 const sonnet=v.models.today.find(m=>m.model==='sonnet');
 assert.equal(sonnet.cost,null);assert.equal(sonnet.share,null);assert.equal(sonnet.tokenShare,700/33900700);
});

test('no published prices, or "Show estimated cost" off, leaves no ≈cost anywhere',()=>{
 assert.equal(costView(data(false),now),null);
 const off=withoutEstimatedCost(data());
 assert.equal(off.history.cost,undefined);
 assert.equal(costView(off,now),null);
 const unchanged=data(false);assert.equal(withoutEstimatedCost(unchanged),unchanged);
});

test('the engine supplement carries its own subscription ≈cost only under a verified binding',()=>{
 const account=sample().projection.rows[0].accounts[0];
 account.subscriptionRef=refA;
 const d=data();d.details={subscriptions:[]};
 assert.deepEqual(prototypeEngineSupplement(account,d,now).estCost.last7d,{usd:10.2,approximate:false});
 assert.equal(prototypeEngineSupplement(account,withoutEstimatedCost(d),now).estCost,null);
 account.subscriptionRef='1111111111111111';
 assert.equal(prototypeEngineSupplement(account,d,now).estCost,null);
});

test('≈cost text follows V1-FINAL §0',()=>{
 assert.equal(estCostText(64),'≈$64');
 assert.equal(estCostText(10.2),'≈$10');
 assert.equal(estCostText(0.042),'≈$0.042');
 assert.equal(estCostText(0.004),'<$0.01');
 assert.equal(estCostText(383.4),'≈$383');
 assert.equal(estCostText(1234),'≈$1.2k');
 assert.equal(estCostText(56000),'≈$56k');
 assert.equal(estCostText(NaN),null);
});
