// SPDX-License-Identifier: MIT
// D466 / DOCK-3.7-05 (owner D166, extended to every cockpit surface): one news clock per announcement and status. It ends
// 30 min after the first look, after 3 present hours, or 24 h after its start, whichever comes first; it moves only on
// renders and ticks (no timers) and names its next change as a deadline.
import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,symlinkSync} from 'node:fs';
import {capture} from '../fixture.mjs';

const out=new URL('../../../cockpit/.tmp/compiled/',import.meta.url);
if(!existsSync(new URL('study',out)))symlinkSync(new URL('../../study',out).pathname,new URL('study',out).pathname);
globalThis.document??={documentElement:{}};
const {createNewsClock,newsClock,NEWS_LOOK_MS,NEWS_CAP_MS,NEWS_PRESENT_MS}=await import('../../../cockpit/.tmp/compiled/src/news-clock.js');
const {cautionItems}=await import('../../../cockpit/.tmp/compiled/src/caution.js');

const T0=Date.parse('2026-11-27T00:29:00Z'),MIN=60_000,H=3_600_000,iso=t=>new Date(t).toISOString();
const confirmed={id:'codex-credit',status:'confirmed',publishedAt:iso(T0-2*H),confirmedAt:iso(T0),expiresAt:iso(T0+30*24*H)};
const announced={id:'glm-reset',status:'announced',publishedAt:iso(T0),expiresAt:iso(T0+7*24*H)};

test('unseen news lives until 24 h after its start, never past the event expiry',()=>{
 const c=createNewsClock();
 c.observe([confirmed],T0+MIN,false);
 assert.equal(c.isNews(confirmed,T0+23*H),true);
 assert.equal(c.isNews(confirmed,T0+NEWS_CAP_MS),false);
 const short={...announced,expiresAt:iso(T0+2*H)};
 assert.equal(c.isNews(short,T0+2*H),false);
 assert.equal(c.nextChange([confirmed],T0+MIN),T0+NEWS_CAP_MS);
});
test('the first look ends it 30 minutes later, and the deadline says when',()=>{
 const c=createNewsClock();
 c.observe([confirmed],T0+9*H,true);// the owner opens the cockpit at 09:00
 assert.equal(c.isNews(confirmed,T0+9*H+29*MIN),true);
 assert.equal(c.nextChange([confirmed],T0+9*H+MIN),T0+9*H+NEWS_LOOK_MS);
 c.observe([confirmed],T0+9*H+NEWS_LOOK_MS,true);
 assert.equal(c.isNews(confirmed,T0+9*H+NEWS_LOOK_MS),false);
 assert.equal(c.nextChange([confirmed],T0+9*H+NEWS_LOOK_MS),null);
});
test('a confirmation starts a fresh clock: the announcement having been seen does not hide it',()=>{
 const c=createNewsClock(),ann={...confirmed,status:'announced',confirmedAt:undefined,publishedAt:iso(T0-2*H)};
 c.observe([ann],T0-2*H,true);
 assert.equal(c.isNews(ann,T0-H),false);
 assert.equal(c.isNews(confirmed,T0+MIN),true);
});
test('shown but not looked at: 3 present hours end it; a long gap (sleep) is not present time',()=>{
 const c=createNewsClock(),e={...announced};
 c.observe([e],T0,true,false);
 for(let t=T0+5*MIN;t<=T0+2*H;t+=5*MIN)c.observe([e],t,true,false);// 2 present hours
 c.present(false,T0+2*H);
 c.observe([e],T0+8*H,true,false);// back after 6 hours asleep: not counted
 assert.equal(c.isNews(e,T0+8*H),true);
 assert.equal(c.nextChange([e],T0+8*H),T0+8*H+NEWS_PRESENT_MS-2*H);
 for(let t=T0+8*H+5*MIN;t<=T0+9*H;t+=5*MIN)c.observe([e],t,true,false);
 assert.equal(c.isNews(e,T0+9*H),false,'3 present hours reached');
});
test('the alert list reads the page clock: a confirmed banked reset leaves the list 30 min after a look',()=>{
 newsClock.reset();
 const d=capture(),row=d.projection.rows[0];
 d.details.resetEvents=[{version:1,id:'c1',rowId:row.id,provider:'openai',kind:'reset_credit',status:'confirmed',publishedAt:iso(T0-H),confirmedAt:iso(T0),expiresAt:iso(T0+30*24*H),source:{kind:'publication',publicationId:'p'}}];
 const blue=now=>cautionItems(d,now,25).filter(x=>x.id.includes('reset'));
 assert.equal(blue(T0+MIN).length,1);
 assert.equal(blue(T0+MIN)[0].dot,'solid');
 newsClock.observe(d.details.resetEvents,T0+2*H,true);
 assert.equal(blue(T0+2*H+29*MIN).length,1);
 assert.equal(blue(T0+2*H+30*MIN).length,0);
 newsClock.reset();
});
