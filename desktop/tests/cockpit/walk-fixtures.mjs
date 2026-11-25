// SPDX-License-Identifier: MIT
// Synthetic inputs for the cockpit click walk. No account keys are needed or passed to the page.
import {build13Profile} from './build13-fixture.mjs';

const plugins=enabled=>({version:1,entries:['calendar','resources'].map(id=>({id,enabled,pinned:false})),settings:{}});

function extraMember(data,index){
 const row=structuredClone(data.projection.rows[0]);
 row.id=`walk-tool-${index}`;row.name={en:`Walk tool ${index}`,zh:`工具 ${index}`};
 const account=row.accounts[0],ref=(index+100).toString(16).padStart(16,'0');
 account.subscriptionRef=ref;account.accountLocator=ref;
 data.projection.rows.push(row);data.subscriptions.push({subscriptionRef:ref,accounts:[{tool:row.id,account:structuredClone(account)}]});
}

function withHistory(data,now){
 const ref=data.projection.rows[0].accounts[0].subscriptionRef;
 const day=back=>{const d=new Date(now);d.setUTCDate(d.getUTCDate()-back);return d.toISOString().slice(0,10);};
 const sums=outputTokens=>({inputTokens:null,outputTokens,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1});
 const ranking={measure:'observed-output-tokens',attribution:'unattributed',recent7d:{entities:0,totalObservedOutputTokens:0,top:[]},recent30d:{entities:0,totalObservedOutputTokens:0,top:[]}};
 data.details.subscriptions=[{subscriptionRef:ref,resetCounts:[],credits:null,today:[{source:'codex',observedOutputTokens:12000,generationTps:42,bindingBasis:'source-wide-current-binding'}]}];
 data.history={version:1,sources:['local-history'],coverage:'local-history',recordingSince:null,dailyFrom:day(39),
  subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',bindingBasis:'source-wide-current-binding',recent7d:sums(1200),recent30d:sums(21200)}]}],
  models:ranking,tools:ranking,daily:[[0,200],[1,1000],[8,20000]].map(([n,v])=>({at:day(n),source:'codex',origin:'live',observedOutputTokens:v})),hourly:[],projects:{recent7d:[],recent30d:[]},cycles:[]};
 return data;
}

/** Fresh data for every walk; `display:false` models the time before the first reading. */
export const WALK_CLOCK='2026-11-23T12:00:00.000Z';
export function walkScenarios(clock=WALK_CLOCK){
 const now=Date.parse(clock);if(!Number.isFinite(now))throw Error('invalid walk clock');
 const base=()=>{const data=build13Profile(now);for(const account of [...data.projection.rows.flatMap(r=>r.accounts),...data.subscriptions.flatMap(s=>s.accounts.map(a=>a.account))]){account.freshUntil='2035-01-01T00:00:00Z';for(const w of account.windows)w.validUntil='2035-01-01T00:00:00Z';}return data;};
 const empty=base();empty.projection.rows=[];empty.subscriptions=[];empty.details.sessions=[];
 const one=withHistory(base(),now);one.projection.rows=one.projection.rows.slice(0,1);
 const many=withHistory(base(),now);for(let i=0;i<7;i++)extraMember(many,i);
 function mixed(readable){
  const data=withHistory(base(),now),row=structuredClone(data.projection.rows[0]);
  row.id='zai';row.vendorKey='glm';row.name={en:'ZCode',zh:'ZCode'};
  const account=row.accounts[0];account.subscriptionRef=null;account.accountLocator=null;
  if(!readable){row.surfaces=['menu','settings'];row.state='needs_action';row.reason={...row.reason,code:'not_signed_in'};account.valueState='none';account.windows=[];account.lastFailure={at:new Date(now).toISOString(),code:'not_signed_in'};}
  data.projection.rows.push(row);
  data.details.publishedModels.push({...structuredClone(data.details.publishedModels[0]),id:'walk-glm',name:'Walk GLM',developerId:'zhipuai'});
  return data;
 }
 const stale=withHistory(base(),now);stale.projection.rows[0].accounts[0].valueState='retained';
 return [
  {name:'empty',data:empty,plugins:plugins(false)},
  {name:'one',data:one,plugins:plugins(false)},
  {name:'many',data:many,plugins:plugins(true)},
  {name:'zcode-readable',data:mixed(true),plugins:plugins(true)},
  {name:'zcode-unreadable',data:mixed(false),plugins:plugins(true)},
  {name:'loading-then-stale',data:null,afterLoading:stale,plugins:plugins(false)},
 ];
}
