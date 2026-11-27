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
test('a host with the shared clock (#1289) decides: its newsUntil wins, and first looks are reported to it',()=>{
 const c=createNewsClock(),looks=[];c.onLook(e=>looks.push(...e));
 c.observe([confirmed],T0+MIN,true);
 assert.deepEqual(looks,[{id:'codex-credit',status:'confirmed'}]);
 c.observe([confirmed],T0+2*MIN,true);assert.equal(looks.length,1,'a look is reported once');
 c.host([{id:'codex-credit',status:'confirmed',until:T0+10*MIN}]);// the widget was looked at earlier
 assert.equal(c.isNews(confirmed,T0+9*MIN),true);assert.equal(c.isNews(confirmed,T0+10*MIN),false);
 assert.equal(c.nextChange([confirmed],T0+5*MIN),T0+10*MIN);
 c.host([{id:'codex-credit',status:'confirmed',until:null}]);assert.equal(c.isNews(confirmed,T0+5*MIN),false);
 assert.equal(c.isNews(announced,T0+5*MIN),true,'an event the host did not answer keeps the page rule');
});
// macrevb-1290-3: a gap between two present refreshes is presence only when it is at most 15 minutes (the app's
// DockNewsClock rule). A sleep with no visibility change counts nothing, not a capped 10 minutes.
test('macrevb-1290-3 a long gap with no visibility change adds no present time: live at 170 present minutes, gone at 180',()=>{
 const c=createNewsClock(),e={...announced};
 c.observe([e],T0,true,false);
 for(let t=T0+5*MIN;t<=T0+165*MIN;t+=5*MIN)c.observe([e],t,true,false);// 165 present minutes
 const wake=T0+165*MIN+6*H;// asleep 6 h; the page saw no visibility change
 c.observe([e],wake,true,false);
 c.observe([e],wake+5*MIN,true,false);// 170 genuinely present minutes
 assert.equal(c.isNews(e,wake+5*MIN),true);
 assert.equal(c.nextChange([e],wake+5*MIN),wake+15*MIN);
 c.observe([e],wake+10*MIN,true,false);assert.equal(c.isNews(e,wake+10*MIN),true);
 c.observe([e],wake+15*MIN,true,false);assert.equal(c.isNews(e,wake+15*MIN),false,'180 present minutes');
 // A 15-minute step still counts in full.
 const d=createNewsClock();d.observe([e],T0,true,false);d.observe([e],T0+15*MIN,true,false);
 assert.equal(d.nextChange([e],T0+15*MIN),T0+15*MIN+NEWS_PRESENT_MS-15*MIN);
});
// macrevb-1290-1: an announcement the cockpit does not draw (its only subscription hidden) gets no look.
test('macrevb-1290-1 drawnNews keeps only announcements of shown subscriptions',async()=>{
 const {drawnNews}=await import('../../../cockpit/.tmp/compiled/src/news-clock.js');
 const {setHiddenMembers}=await import('../../../cockpit/.tmp/compiled/src/members.js');
 const d=capture(),row=d.projection.rows[0],ref=row.accounts[0].subscriptionRef;
 d.details.resetEvents=[{version:1,id:'h1',rowId:row.id,provider:'openai',status:'announced',publishedAt:iso(T0),expiresAt:iso(T0+7*24*H),source:{kind:'publication',publicationId:'p'}},
  {version:1,id:'x1',rowId:'not-mine',provider:'x',status:'announced',publishedAt:iso(T0),expiresAt:iso(T0+7*24*H),source:{kind:'publication',publicationId:'p'}}];
 assert.deepEqual(drawnNews(d).map(e=>e.id),['h1']);
 row.accounts=row.accounts.slice(0,1);assert.ok(ref);
 setHiddenMembers([ref]);
 try{assert.deepEqual(drawnNews(d).map(e=>e.id),[],'its only subscription is hidden');}finally{setHiddenMembers([]);}
 assert.deepEqual(drawnNews(d).map(e=>e.id),['h1'],'shown again');
});
// macrevb-1290-1 round 2: what the surfaces mark is what the clock may treat as looked at.
test('macrevb-1290-1 marks: observe reports a first look; renderedMarks reads only laid-out marks; alert rows carry the mark',async()=>{
 const {newsMark,renderedMarks}=await import('../../../cockpit/.tmp/compiled/src/news-clock.js');
 const c=createNewsClock();
 assert.equal(c.observe([confirmed],T0+MIN,true),true);assert.equal(c.observe([confirmed],T0+2*MIN,true),false);
 assert.equal(newsMark({id:'a b#c',status:'confirmed'}),'a%20b%23c#confirmed');
 const el=(news,rects)=>({isConnected:true,dataset:{news},getClientRects:()=>({length:rects}),closest:()=>null});
 const root={querySelectorAll:()=>[el('x#confirmed y#announced',1),el('z#confirmed',0)]};
 assert.deepEqual([...renderedMarks(root)],['x#confirmed','y#announced']);
 newsClock.reset();
 const d=capture(),row=d.projection.rows[0];
 d.details.resetEvents=[{version:1,id:'m1',rowId:row.id,provider:'openai',status:'announced',publishedAt:iso(T0),expiresAt:iso(T0+7*24*H),source:{kind:'publication',publicationId:'p'}}];
 assert.equal(cautionItems(d,T0+MIN,25).find(x=>x.id.includes('reset')).news,'m1#announced');
});

// D474 §5.1: retirements beyond the clock. An undated announcement that is never confirmed retires 48 h after
// publication; a confirmed direct reset clears once the reading shows its window restarted; a banked one never does.
const {newsRetired,newsLive,NEWS_UNDATED_RETIRE_MS}=await import('../../../cockpit/.tmp/compiled/src/news-clock.js');
function withWeekly(cycleStart,kind){
 const data=capture(),row=data.projection.rows[0],a=row.accounts[0];
 a.valueState='current';
 a.windows=[{...a.windows[0],id:'week',role:'weekly',durationSeconds:604800,current:true,remainingPercent:100,validUntil:iso(T0+10*H),resetsAt:iso(cycleStart+7*24*H)}];
 data.subscriptions=[{subscriptionRef:a.subscriptionRef,accounts:[{tool:row.id,account:structuredClone(a)}]}];
 const e={id:'direct',status:'confirmed',kind,rowId:row.id,publishedAt:iso(T0-H),confirmedAt:iso(T0),expiresAt:iso(T0+7*24*H),provider:'x',source:'official',version:1};
 return {data,e};
}
test('D474 an undated announcement that is never confirmed retires 48 h after publication',()=>{
 const data=capture(),e={...announced,rowId:data.projection.rows[0].id};
 assert.equal(NEWS_UNDATED_RETIRE_MS,48*H);
 assert.equal(newsRetired(e,data,T0+47*H),false);
 assert.equal(newsRetired(e,data,T0+48*H),true);
 assert.equal(newsRetired({...e,schedule:{from:iso(T0+72*H),through:iso(T0+73*H),precision:'minute'}},data,T0+60*H),false,'a dated one stays for its time');
 assert.equal(newsLive(e,data,T0+49*H),false);
});
test('D474 a confirmed direct reset clears when the window restarted; a banked reset does not',()=>{
 const restarted=withWeekly(T0+10*MIN,'direct_reset');
 assert.equal(newsRetired(restarted.e,restarted.data,T0+20*MIN),true,'the weekly cycle began after the confirmation');
 const before=withWeekly(T0-3*24*H,'direct_reset');
 assert.equal(newsRetired(before.e,before.data,T0+20*MIN),false,'not restarted yet');
 const banked=withWeekly(T0+10*MIN,'reset_credit');
 assert.equal(newsRetired(banked.e,banked.data,T0+20*MIN),false,'a banked reset never clears this way');
});
