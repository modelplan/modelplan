// SPDX-License-Identifier: MIT
// CKP-MFD-56 (#1045 MP1045-1). Invariant: a plan-scoped reset announcement belongs to the subscription of that plan, so the
// alert row's click target (its `member`) is never another plan's subscription of the same tool.
import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,symlinkSync} from 'node:fs';
import {capture} from '../fixture.mjs';

// The compiled page code imports the plain-JS study modules next to it; link them into the build output (ignored by git).
const out=new URL('../../../cockpit/.tmp/compiled/',import.meta.url);
if(!existsSync(new URL('study',out)))symlinkSync(new URL('../../study',out).pathname,new URL('study',out).pathname);
globalThis.document??={documentElement:{}};
const {cautionItems}=await import('../../../cockpit/.tmp/compiled/src/caution.js');

const NOW=Date.parse('2026-11-16T12:00:00Z'),iso=m=>new Date(NOW+m*60000).toISOString();
function data(planIds){
 const d=capture(),row=d.projection.rows[0],a=row.accounts[0];
 const plus={...structuredClone(a),subscriptionRef:'1111111111111111',route:'plus',plan:{id:'plus',name:{en:'Plus',zh:'Plus'}}};
 const pro={...structuredClone(a),subscriptionRef:'2222222222222222',route:'pro',plan:{id:'pro',name:{en:'Pro',zh:'Pro'}}};
 row.accounts=[plus,pro]; // saved order: Plus first
 d.subscriptions=[plus,pro].map(x=>({...structuredClone(d.subscriptions[0]),subscriptionRef:x.subscriptionRef}));
 d.details.resetEvents=[{version:1,id:'e1',rowId:row.id,provider:'openai',status:'confirmed',publishedAt:iso(-10),expiresAt:iso(600),planIds,source:{kind:'publication',publicationId:'p'}}];
 return d;
}
const target=d=>cautionItems(d,NOW,25).find(x=>x.level==='blue'&&x.id.includes('reset'))?.member;

test('a Pro-only reset announcement targets the Pro subscription even with Plus ordered first',()=>{
 assert.equal(target(data(['pro'])),'2222222222222222');
});
test('an announcement for both plans, or with no plan list, keeps the first matching subscription',()=>{
 assert.equal(target(data(['plus','pro'])),'1111111111111111');
 assert.equal(target(data([])),'1111111111111111');
});
test('an announcement for a plan this reader does not hold lists nothing',()=>{
 assert.equal(target(data(['max'])),undefined);
});
