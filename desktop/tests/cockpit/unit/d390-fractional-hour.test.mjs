// SPDX-License-Identifier: MIT
// macrevb-1212-3 (CKP-MFD-62): a recorded hour keeps its own wall-clock hour in a fractional-offset zone. Lord Howe falls back
// 30 minutes on 2026-04-05 02:00 LHDT (UTC+11) -> 01:30 LHST (UTC+10:30); the producer's 04:00 LHST bucket on Apr 5 is 2026-04-04T17:30Z.
process.env.TZ='Australia/Lord_Howe';
import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,symlinkSync} from 'node:fs';
import {heatCells} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';
globalThis.document??={documentElement:{}};
// The compiled adapter imports the study's i18n by a relative path that tsc does not emit.
const compiled=new URL('../../../cockpit/.tmp/compiled/',import.meta.url);
if(!existsSync(new URL('study',compiled)))symlinkSync('../../study',new URL('study',compiled).pathname);
const {historyView}=await import('../../../cockpit/.tmp/compiled/src/prototype-history.js');

const ref='0123456789abcdef',now=new Date(2026,3,6,23,30).getTime();
const sums={inputTokens:null,outputTokens:1,cacheReadTokens:null,cacheWriteTokens:null,cacheHitRatio:null,generationTps:null,observedRequests:1,eligibleRequests:1};
const hourly=[['2026-04-04T17:30:00Z',500]].map(([at,n])=>({at,source:'codex',origin:'live',observedOutputTokens:n}));
const data={history:{version:1,coverage:'local-history',dailyFrom:'2026-04-01',subscriptions:[{subscriptionRef:ref,sources:[{source:'codex',recent7d:sums,recent30d:sums}]}],
 daily:[],hourly,models:{recent7d:{top:[]},recent30d:{top:[]}},projects:{recent7d:[],recent30d:[]},cycles:[]},details:{}};
const A={id:'member0',short:'Pro',name:'Pro',colour:'#6aa8ff',vendor:'openai'};

for(const days of [7,30])
test(`Lord Howe 04:00 LHST after the 30-minute fall-back sits in the 04:00-08:00 cell (${days}d)`,()=>{
 const v=historyView(data,new Map([[ref,A.id]]),now,'en');
 const d={now,accounts:[A],alerts:[],daily:[],hourly:v.hourly,hourlyLong:v.hourlyLong};
 const g=heatCells(d,{lang:'en',days,stack:true,chart:'grid',scope:null,fill:{ov:{w:300,h:110}}});
 const lit=g.cells.filter(c=>c.recorded).map(c=>[new Date(c.at).getDate(),c.from,c.to,c.total]);
 assert.deepEqual(lit,[[5,4,8,500]]);
});
