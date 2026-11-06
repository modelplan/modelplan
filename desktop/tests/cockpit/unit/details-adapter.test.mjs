// SPDX-License-Identifier: MIT
// Synthetic producer capture from #414 at bf72ee6d; variants exercise the
// wire contract without reading a real home, account or session.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {definitions} from '../../../cockpit/.tmp/compiled/generated/wire.js';
import {conforms} from '../../../cockpit/.tmp/compiled/src/schema.js';
import {cockpitDetails,prototypeEngineSupplement} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';
import {sample} from '../fixture.mjs';
const producer=()=>JSON.parse(readFileSync(new URL('../../../../schema/app-cli/captures/WireCockpitDetails.json',import.meta.url)));
const withDetails=()=>{const d=sample();d.details=producer();return d;};

test('producer details fixture, absence, null and empty remain distinct',()=>{
 const d=withDetails();assert.equal(conforms(d,definitions.CockpitData,definitions),true);
 assert.deepEqual(cockpitDetails(d),producer());
 delete d.details;assert.equal(cockpitDetails(d),undefined);assert.equal(conforms(d,definitions.CockpitData,definitions),true);
 d.details=null;assert.equal(cockpitDetails(d),null);assert.equal(conforms(d,definitions.CockpitData,definitions),true);
 d.details={version:1,sources:[],subscriptions:[],sessions:[],sessionCoverage:'local-last-seen',resetEvents:[],alerts:[]};
 assert.equal(conforms(d,definitions.CockpitData,definitions),true);assert.deepEqual(cockpitDetails(d).sessions,[]);
});

test('malformed nested details reject the entire display',()=>{
 for(const change of [d=>d.details.version=2,d=>delete d.details.sessions[0].lastObservedAt,d=>d.details.sessions[0].sessionRef='bad',d=>d.details.subscriptions[0].credits.observedAt='bad',d=>d.details.subscriptions[0].resetCounts[0].count='0',d=>d.details.sessions[0].rate='2',d=>d.details.surprise=true]){
  const d=withDetails();change(d);assert.equal(conforms(d,definitions.CockpitData,definitions),false);
 }
});

test('verified subscription preserves zero and unknown while ambiguity is withheld',()=>{
 const d=withDetails(),detail=d.details.subscriptions[0],account=d.projection.rows[0].accounts[0];
 account.subscriptionRef=detail.subscriptionRef;d.subscriptions[0].subscriptionRef=detail.subscriptionRef;
 detail.today[0].bindingBasis='source-wide-current-binding';detail.today[0].observedOutputTokens=0;detail.today[0].generationTps=0;
 detail.credits.balance=0;detail.resetCounts[0].count=0;
 let out=prototypeEngineSupplement(account,d);assert.equal(out.todayTokens,0);assert.equal(out.todayAverageGenerationTps,0);assert.equal(out.reserveCredits.balance,0);assert.equal(out.resetCards[0].count,0);
 detail.today[0].generationTps=null;detail.credits.balance=null;detail.resetCounts[0].count=null;
 out=prototypeEngineSupplement(account,d);assert.equal(out.todayAverageGenerationTps,null);assert.equal(out.reserveCredits.balance,null);assert.equal(out.resetCards[0].count,null);
 detail.today.push({...detail.today[0],source:'another'});assert.equal(prototypeEngineSupplement(account,d).todayTokens,null);
 detail.today.pop();d.subscriptions=[];assert.equal(prototypeEngineSupplement(account,d).todayTokens,null);
});

test('forbidden-null fields reject explicit null while omission remains valid',()=>{
 const d=withDetails();
 delete d.details.subscriptions[0].resetCards;
 assert.equal(conforms(d,definitions.CockpitData,definitions),true);
 d.details.subscriptions[0].resetCards=null;
 assert.equal(conforms(d,definitions.CockpitData,definitions),false);
});
