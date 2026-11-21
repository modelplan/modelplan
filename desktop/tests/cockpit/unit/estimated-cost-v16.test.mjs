// SPDX-License-Identifier: MIT
// WP-06 end to end: the shared client-v1.6 publication (testdata/client-v1.6/example.json) is read by the CLI digest
// and priced into the cockpit history by TestClientV16PublicationPricesTheCockpitHistory, which writes
// testdata/client-v1.6/cockpit-history.json. This test takes that exact wire value to the page's ≈cost cells.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {definitions} from '../../../cockpit/.tmp/compiled/generated/wire.js';
import {conforms} from '../../../cockpit/.tmp/compiled/src/schema.js';
import {costView,subscriptionCost,estCostText} from '../../../cockpit/.tmp/compiled/src/prototype-cost.js';

const history=JSON.parse(readFileSync(new URL('../../../../testdata/client-v1.6/cockpit-history.json',import.meta.url),'utf8'));
const refA='0123456789abcdef',refB='fedcba9876543210';
// The Go test's clock: 2026-11-05 12:00, a local day for the page.
const now=new Date(2026,10,5,12,0,0).getTime();
const near=(a,b)=>Math.abs(a-b)<1e-9;

test('the v1.6 cockpit history is a valid wire value',()=>{
 assert.equal(conforms(history,definitions.CockpitHistory,definitions),true);
});

test('a v1.6 publication reaches the page as ≈cost cells',()=>{
 const v=costView({subscriptions:[{subscriptionRef:refA,accounts:[]},{subscriptionRef:refB,accounts:[]}],projection:{rows:[]},history},now);
 assert.ok(v,'prices published → a ≈cost view');
 assert.equal(v.pricesAsOf,'2026-11-19');
 // today: sol-6.1 $3.20 (long-context price, so approximate) plus an unpublished model counted in tokens only.
 assert.ok(near(v.total.today.cost.usd,3.2));assert.equal(v.total.today.cost.approximate,true);
 assert.equal(v.total.today.unpricedShare,1000/3101000);
 // 7 days: + the pending astra-6.2 row's own price ($1.20) + opus ($1.74, exact).
 assert.ok(near(v.total.last7d.cost.usd,6.14));
 const a=subscriptionCost(v,refA),b=subscriptionCost(v,refB);
 assert.ok(near(a.last7d.usd,4.4));assert.equal(a.last7d.approximate,true);
 assert.equal(b.today,null,'no Claude Code use today: no ≈$, not $0');
 assert.deepEqual(b.last7d,{usd:1.74,approximate:false});
 assert.deepEqual(v.models.last7d.map(m=>m.model),['sol-6.1','opus','astra-6.2','unknown']);
 const unknown=v.models.last7d.at(-1);
 assert.equal(unknown.cost,null);assert.equal(unknown.share,null);
 assert.equal(estCostText(v.total.last7d.cost.usd),'≈$6.1');
});
