// SPDX-License-Identifier: MIT
// macrevc-1224-3. Invariant: a published peak the producer did not confirm is called tentative wherever it is listed
// (sentence and tooltip); a confirmed one keeps the plain sentence and has no tooltip.
import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,symlinkSync} from 'node:fs';
import {capture} from '../fixture.mjs';

const out=new URL('../../../cockpit/.tmp/compiled/',import.meta.url);
if(!existsSync(new URL('study',out)))symlinkSync(new URL('../../study',out).pathname,new URL('study',out).pathname);
globalThis.document??={documentElement:{}};
const {cautionItems}=await import('../../../cockpit/.tmp/compiled/src/caution.js');

const NOW=Date.parse('2026-11-16T12:00:00Z'),iso=m=>new Date(NOW+m*60000).toISOString();
const items=(status,from,to)=>{
 const d=capture(),rowId=d.projection.rows[0].id;
 d.details.peaks=[{rowId,startsAt:iso(from),endsAt:to===null?null:iso(to),status}];
 return cautionItems(d,NOW,25).filter(x=>x.id.includes('peak'));
};
const TIP={en:"From Zhipu's published rules; may change",zh:'智谱高峰时段来自公开规则，可能调整'};

test('a tentative upcoming peak reads Peak (tentative) with the explaining tooltip',()=>{
 const [x]=items('tentative',60,300);
 assert.match(x.text.zh,/高峰（暂定）/);assert.match(x.text.en,/Peak \(tentative\)/);assert.deepEqual(x.tip,TIP);
});
test('a tentative running peak and an open-ended one say tentative too',()=>{
 const [live]=items('tentative',-30,120),[open]=items('tentative',60,null);
 for(const x of [live,open]){assert.match(x.text.zh,/高峰（暂定）/);assert.match(x.text.en,/Peak \(tentative\)/);assert.deepEqual(x.tip,TIP);}
});
test('a confirmed peak keeps the plain sentence and has no tooltip',()=>{
 for(const [f,t] of [[60,300],[-30,120],[60,null]]){
  const [x]=items('confirmed',f,t);
  assert.doesNotMatch(x.text.zh,/暂定/);assert.doesNotMatch(x.text.en,/tentative/);assert.equal(x.tip,undefined);
 }
});
