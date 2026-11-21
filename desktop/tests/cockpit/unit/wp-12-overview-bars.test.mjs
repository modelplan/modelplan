// SPDX-License-Identifier: MIT
// WP-12 (CKP-MFD-58…62): the overview's ≈cost bars and totals, as pure views over synthetic ≈cost series. Bar height is
// ≈cost from zero, linear; one dashed line carries the highest day; a recorded day with no cost keeps a 3 px base;
// a day before the record has nothing. The wire path that fills d.cost is covered with WP-06 (estimated-cost tests).
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {overview,overviewBars,alertList} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import {overviewCost} from '../../../cockpit/.tmp/compiled/src/overview-cost.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}};
setLanguage('en');
const now=new Date(2026,10,4,12).getTime();
const acc=(id,colour)=>({id,short:id,name:id,colour,vendor:'unknown',state:'ok',todayTokens:100});
const A=acc('A','#6aa8ff'),B=acc('B','#ff9a6a');
const days=tail=>{const v=Array(182).fill(null);tail.forEach((x,i)=>{v[182-tail.length+i]=x;});return v;};
const dailyOf=(a,tail)=>({accountId:a.id,values:days(tail),imported:[],coverageStart:new Date(2026,10,1).getTime(),priced:days(tail).map(v=>v>0?1000:0),unpriced:days(tail).map(()=>0)});
const listOf=(...pairs)=>pairs.map(([a,tail])=>({a,daily:dailyOf(a,tail)}));
const ui={lang:'en',days:7,stack:true,scope:null,fill:{ov:{w:260,h:110}}};
const bars=svg=>[...svg.matchAll(/<g class="ov-bucket(?: ov-last)?"[^>]*data-total="([^"]*)"[^>]*>(.*?)<\/g>/g)].map(m=>({total:Number(m[1]),paths:[...m[2].matchAll(/<path class="ov-bar[^"]*"[^>]*d="M([\d.]+),([\d.]+)V([\d.]+)/g)].map(p=>({y:Number(p[2])}))}));
const heightOf=g=>g.match(/<path class="ov-bar[^"]*"[^>]*d="M[\d.]+,([\d.]+)V([\d.]+)/);

test('WP-12 one bar per day, heights linear from zero in ≈cost, the highest day on the dashed line',()=>{
 const list=listOf([A,[10,20,40,null,null,null,5]]);
 const svg=overviewBars({now,accounts:[A],daily:[],cost:{daily:[],hourly:[]}},ui,list);
 assert.match(svg,/data-buckets="7"/);
 const heights=[...svg.matchAll(/class="ov-bar"[^>]*d="M[\d.]+,([\d.]+)V[\d.]+Q[\d.]+,([\d.]+) /g)].map(m=>Number(m[1])-Number(m[2]));
 assert.equal(heights.length,4);
 const unit=heights[2]/40;
 for(const [h,v] of [[heights[0],10],[heights[1],20],[heights[3],5]])assert.ok(Math.abs(h-v*unit)<0.1,JSON.stringify(heights));
 assert.equal((svg.match(/class="ov-max"/g)||[]).length,1);assert.match(svg,/class="ov-max"[^>]*>≈\$40</);
 assert.equal((svg.match(/class="ov-grid"/g)||[]).length,1,'one dashed line, no other scale');
});
test('WP-12 a day before the record draws nothing, a recorded day without cost keeps a 3 px base',()=>{
 const list=listOf([A,[0,7,null,null,null,null,3]]);
 const svg=overviewBars({now,accounts:[A],daily:[],cost:{daily:[],hourly:[]}},ui,list);
 const g=[...svg.matchAll(/<g class="ov-bucket[^"]*"[^>]*>[\s\S]*?<\/g>/g)].map(m=>m[0]);
 assert.equal(g.length,7);
 assert.match(g[0],/class="ov-stub"[^>]*height="3"/);
 assert.doesNotMatch(g[2],/ov-bar|ov-stub/);
 assert.doesNotMatch(g[6-1],/ov-bar|ov-stub/);
});
test('WP-12 six subscriptions stack six layers in their own colours, no legend',()=>{
 const six=['A','B','C','D','E','F'].map((id,i)=>acc(id,'#'+String(i+1).repeat(6)));
 const list=six.map((a,i)=>({a,daily:dailyOf(a,[1+i,2,3,4,5,6,7])}));
 const svg=overviewBars({now,accounts:six,daily:[],cost:{daily:[],hourly:[]}},ui,list);
 const first=svg.match(/<g class="ov-bucket[^"]*"[\s\S]*?<\/g>/)[0];
 assert.equal((first.match(/class="ov-bar/g)||[]).length,6);
 for(const a of six)assert.ok(first.includes(`fill="${a.colour}"`));
 assert.doesNotMatch(svg,/ov-legend/);
 assert.match(overview.render({now,accounts:six,daily:list.map(x=>x.daily),alerts:[],cost:{daily:list.map(x=>x.daily),hourly:[],unpriced:{d7:0}}},{...ui}),/^(?!.*ov-legend)/s);
});
test('WP-12 the hover note lists the day, its total and each subscription; the newest bar is the bright one',()=>{
 const list=listOf([A,[0,0,0,0,0,10,20]],[B,[0,0,0,0,0,5,64]]);
 const svg=overviewBars({now,accounts:[A,B],daily:[],cost:{daily:[],hourly:[]}},ui,list);
 const tips=[...svg.matchAll(/data-tip="([^"]*)"/g)].map(m=>m[1]);
 assert.equal(tips.at(-1),'Nov 4 · ≈$84\nA ≈$20\nB ≈$64');
 assert.equal((svg.match(/ov-last/g)||[]).length,1);
});
test('WP-12 axis names the two ends only (7 days), plus the middle at 30 days, 24 hourly bars for Today',()=>{
 const list=listOf([A,[1,2,3,4,5,6,7]]);
 const d={now,accounts:[A],daily:[],cost:{daily:[],hourly:[]}};
 assert.deepEqual([...overviewBars(d,ui,list).matchAll(/class="ov-ax"[^>]*>([^<]*)</g)].map(m=>m[1]),['−6d','Today']);
 const month=overviewBars(d,{...ui,days:30},listOf([A,Array.from({length:30},(_,i)=>i+1)]));
 assert.deepEqual([...month.matchAll(/class="ov-ax"[^>]*>([^<]*)</g)].map(m=>m[1]),['−29d','−14d','Today']);
 assert.match(month,/data-buckets="30"/);
});
test('WP-12 totals row: ≈cost large, tokens beside it, "per day" on the right, no bars without price data',()=>{
 const withCost={now,accounts:[A],daily:[dailyOf(A,[10,0,0,0,0,0,0])],alerts:[],
  cost:{daily:[{...dailyOf(A,[100,50,50,0,0,0,183]),unpriced:days([0,0,0,0,0,0,167])}],hourly:[]}};
 const html=overview.render(withCost,ui);
 assert.match(html,/class="ov-total">≈\$383</);assert.match(html,/class="ov-per">≈\$55\/day</);
 assert.match(html,/4% of use has no public price/);
 const noPrice=overview.render({...withCost,cost:null},ui);
 assert.doesNotMatch(noPrice,/ov-chart|≈/);assert.match(noPrice,/class="ov-total">10</);
});
test('WP-12 a selected subscription counts only itself in totals and bars',()=>{
 const d={now,accounts:[A,B],daily:[dailyOf(A,[1]),dailyOf(B,[1])],alerts:[],cost:{daily:[dailyOf(A,[10]),dailyOf(B,[90])],hourly:[]}};
 const html=overview.render(d,{...ui,scope:'A'});
 assert.match(html,/class="ov-total">≈\$10</);assert.doesNotMatch(html,/data-sub="B"/);
});
test('WP-12 alert rows: three or more unreadable subscriptions merge into one grey line; at most four lines',()=>{
 const grey=n=>Array.from({length:n},(_,i)=>({level:'grey',kind:'unreadable',text:'S'+i+' not read'}));
 const html=alertList({alerts:[{level:'red',text:'r'},...grey(3)]},{max:4});
 assert.equal((html.match(/<li/g)||[]).length,2);assert.match(html,/3 subscriptions not read · Settings ›/);
 const many=Array.from({length:6},(_,i)=>({level:'blue',text:'b'+i}));
 const out=alertList({alerts:many},{max:4});assert.equal((out.match(/<li/g)||[]).length,4);assert.match(out,/\+3 ▸/);
});
test('WP-12 the ≈cost series reads the wire\'s cost buckets per subscription, null where nothing was recorded, none without a price',()=>{
 const ids=new Map([['refA','A']]),day=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
 const data={history:{coverage:'local-history',subscriptions:[{subscriptionRef:'refA',sources:[{source:'codex'}]}],
  cost:{basis:'api-list-price',currency:'USD',daily:[{at:day(0),source:'codex',estimatedUsd:12,pricedTokens:100,unpricedTokens:0},{at:day(0),source:'codex',estimatedUsd:3,pricedTokens:10,unpricedTokens:10},{at:day(2),source:'codex',estimatedUsd:0,pricedTokens:0,unpricedTokens:50},{at:day(1),source:'other',estimatedUsd:99,pricedTokens:1,unpricedTokens:0}],
   hourly:[{at:new Date(2026,10,4,11).toISOString(),source:'codex',estimatedUsd:4,pricedTokens:1,unpricedTokens:0}]}}};
 const c=overviewCost(data,ids,now);
 assert.deepEqual(c.daily[0].values.slice(-3),[0,null,15],'unpriced-only day is a recorded zero; other tools do not count');
 assert.equal(c.daily[0].accountId,'A');
 assert.equal(c.hourly[0].values.at(-2),4);
 assert.equal(overviewCost({history:{...data.history,cost:{...data.history.cost,daily:[],hourly:[]}}},ids,now),null,'no cost buckets at all: no series, no fallback');
 assert.equal(overviewCost({history:{...data.history,cost:undefined}},ids,now),null);
});

// macrevb-635-3 (moved from the browser suite): hour buckets are local hours, which need not be UTC hours.
for(const [zone,clock,buckets,last] of [
 ['Asia/Kolkata','2026-11-04T12:10:00+05:30',[['2026-11-04T12:00:00+05:30',7]],[7]],
 ['Asia/Kathmandu','2026-11-04T12:50:00+05:45',[['2026-11-04T12:00:00+05:45',7]],[7]],
 // The repeated 01:00 hour when daylight saving ends: two offsets, two buckets.
 ['America/New_York','2026-11-01T01:30:00-05:00',[['2026-11-01T01:00:00-04:00',1],['2026-11-01T01:00:00-05:00',2]],[1,2]],
])test(`WP-12 local-hour ≈cost buckets land in the right bar in ${zone}`,()=>{
 const was=process.env.TZ;process.env.TZ=zone;
 try{
  const at=Date.parse(clock);
  const data={history:{coverage:'local-history',subscriptions:[{subscriptionRef:'r',sources:[{source:'codex'}]}],
   cost:{basis:'api-list-price',currency:'USD',daily:[{at:'2026-11-04',source:'codex',estimatedUsd:1,pricedTokens:1,unpricedTokens:0}],
    hourly:buckets.map(([t,usd])=>({at:t,source:'codex',estimatedUsd:usd,pricedTokens:1,unpricedTokens:0}))}}};
  const values=overviewCost(data,new Map([['r','A']]),at).hourly[0].values;
  assert.equal(values.length,24);assert.deepEqual(values.slice(-last.length),last);
 }finally{process.env.TZ=was;}
});

// ---- macrevc-1057 review blockers (R19 delta) ----
const dayKey=back=>{const d=new Date(2026,10,4-back);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
const refs=new Map([['refA','A'],['refB','B']]);
const wireOf=({daily=[],hourly=[],rows=[],both=true})=>({history:{coverage:'local-history',dailyFrom:dayKey(30),
 subscriptions:[{subscriptionRef:'refA',sources:[{source:'codex'}]},...(both?[{subscriptionRef:'refB',sources:[{source:'other'}]}]:[])],daily:rows,
 cost:{basis:'api-list-price',currency:'USD',daily,hourly}}});
const bucket=(back,source,usd,priced,unpriced)=>({at:dayKey(back),source,estimatedUsd:usd,pricedTokens:priced,unpricedTokens:unpriced});
const viewData=(wire,accounts=[A])=>({now,accounts,alerts:[],daily:accounts.map(a=>dailyOf(a,[1])),cost:overviewCost(wire,refs,now)});

test('macrevc-1057-3 only unreadable grey rows merge; retained readings stay as their own lines',()=>{
 const stale=n=>Array.from({length:n},(_,i)=>({level:'grey',kind:'stale',text:'S'+i+' last reading 2h ago'}));
 const unread=n=>Array.from({length:n},(_,i)=>({level:'grey',kind:'unreadable',text:'U'+i+' not read'}));
 assert.equal((alertList({alerts:stale(3)},{max:4}).match(/<li/g)||[]).length,3,'three retained readings are not merged');
 assert.doesNotMatch(alertList({alerts:stale(3)},{max:4}),/not read ·/);
 const mixed=alertList({alerts:[...stale(2),...unread(2)]},{max:4});
 assert.equal((mixed.match(/<li/g)||[]).length,4,'two unreadable do not merge');
 const merged=alertList({alerts:[...stale(2),...unread(3)]},{max:4});
 assert.match(merged,/3 subscriptions not read/);assert.equal((merged.match(/<li[^>]*>[^]*?last reading/g)||[]).length,2);assert.equal((merged.match(/<li/g)||[]).length,3);
});

test('macrevc-1057-4 the unpriced note is calculated for the selected subscription and range',()=>{
 const wire=wireOf({daily:[bucket(0,'codex',9,900,0),bucket(0,'other',0,0,900)]});
 const d=viewData(wire,[A,B]);
 assert.doesNotMatch(overview.render(d,{...ui,scope:'A'}),/ov-note/,'A is fully priced');
 assert.match(overview.render(d,{...ui,scope:'B'}),/100% of use has no public price/);
 assert.match(overview.render(d,{...ui,scope:null}),/50% of use has no public price/);
});

test('macrevc-1057-5 Today is the local calendar day\'s daily cost, whatever the hourly buckets say',()=>{
 const yesterday=new Date(2026,10,3,13).toISOString();
 const a=overview.render(viewData(wireOf({daily:[bucket(1,'codex',9,10,0),bucket(0,'codex',1,10,0)],hourly:[{at:yesterday,source:'codex',estimatedUsd:9,pricedTokens:10,unpricedTokens:0},{at:new Date(2026,10,4,11).toISOString(),source:'codex',estimatedUsd:1,pricedTokens:10,unpricedTokens:0}]})),{...ui,days:24});
 assert.match(a,/class="ov-total">≈\$1</,'$9 yesterday and $1 today');
 const b=overview.render(viewData(wireOf({daily:[bucket(0,'codex',9,10,0),bucket(3,'codex',1,10,0)]})),{...ui,days:24});
 assert.match(b,/class="ov-total">≈\$9</,'a daily-only cost still counts');
});

test('macrevc-1057-6 the period token total counts every token the cost counts, priced or not',()=>{
 const wire=wireOf({daily:[bucket(1,'codex',1,9000,1000),bucket(0,'codex',0,0,0)]});
 const d=viewData(wire);d.daily=[{...dailyOf(A,[1200]),}];
 assert.match(overview.render(d,ui),/class="ov-tok">10k</);
});

test('macrevc-1057-7 a range with no priced usage shows no cost, only its tokens and the unpriced note',()=>{
 const wire=wireOf({daily:[bucket(20,'codex',5,100,0),bucket(0,'codex',0,0,900)]});
 const html=overview.render(viewData(wire),{...ui,days:7});
 assert.doesNotMatch(html,/≈\$0/);assert.doesNotMatch(html,/ov-per/);assert.doesNotMatch(html,/class="ov-chart"/);
 assert.match(html,/100% of use has no public price/);
});

test('macrevc-1057-8 the highest bar reaches the dashed line when only some subscriptions have cost that day',()=>{
 const six=['A','B','C','D','E','F'].map((n,i)=>acc(n,['#6aa8ff','#ff9a6a','#9a6aff','#6affb0','#ffd86a','#ff6a9a'][i]));
 const list=six.map((a,i)=>({a,daily:dailyOf(a,i===0?[0,0,0,0,0,0,50]:[5,5,5,5,5,5,null])}));
 const svg=overviewBars({now,accounts:six,daily:[],cost:{daily:[],hourly:[]}},ui,list);
 const line=Number(/class="ov-grid" d="M0 ([\d.]+)H/.exec(svg)[1]);
 const last=[...svg.matchAll(/<g class="ov-bucket[^"]*"[^>]*>[\s\S]*?<\/g>/g)].at(-1)[0];
 const top=Number(/class="ov-bar"[^>]*d="M[\d.]+,[\d.]+V[\d.]+Q[\d.]+,([\d.]+) /.exec(last)[1]);
 assert.ok(Math.abs(top-line)<=1,`bar top ${top} vs line ${line}`);
});

test('macrevc-1057-9 a recorded day with no cost bucket is a recorded zero; days before the record stay null',()=>{
 const wire=wireOf({daily:[bucket(0,'codex',4,10,0)],rows:[{at:dayKey(2),source:'codex',origin:'live',observedOutputTokens:0}]});
 const v=overviewCost(wire,refs,now).daily[0].values;
 assert.deepEqual(v.slice(-4),[null,0,null,4]);
 const svg=overviewBars({now,accounts:[A],daily:[],cost:{daily:[],hourly:[]}},ui,[{a:A,daily:{values:v.slice(-7)}}]);
 assert.equal((svg.match(/class="ov-stub"/g)||[]).length,1);
});

// ---- macrevc-1057 second round (R20 acceptance conditions) ----
test('macrevc-1057-6/7 all-unpriced usage keeps a cost object: the full token total and the note show, no ≈cost, no bars',()=>{
 const wire=wireOf({daily:[bucket(1,'codex',0,0,6000),bucket(0,'codex',0,0,4000)]});
 const c=overviewCost(wire,refs,now);
 assert.ok(c,'no bucket has priced tokens, yet the cost object stays');
 const html=overview.render({...viewData(wire),cost:c},{...ui,days:7});
 assert.match(html,/class="ov-total">10k</,'all tokens, not the output-only 1');
 assert.doesNotMatch(html,/≈\$/);assert.doesNotMatch(html,/ov-per|class="ov-chart"/);
 assert.match(html,/100% of use has no public price/);
});

test('macrevc-1057-8 a lower day with more layers never grows taller than the dashed line',()=>{
 const six=['A','B','C','D','E','F'].map((n,i)=>acc(n,['#6aa8ff','#ff9a6a','#9a6aff','#6affb0','#ffd86a','#ff6a9a'][i]));
 // Day 6: one subscription, the $50 maximum. Day 5: six subscriptions, $49 in total (five gaps).
 const list=six.map((a,i)=>({a,daily:dailyOf(a,[null,null,null,null,null,i===0?9:8,i===0?50:0])}));
 const svg=overviewBars({now,accounts:six,daily:[],cost:{daily:[],hourly:[]}},ui,list);
 const line=Number(/class="ov-grid" d="M0 ([\d.]+)H/.exec(svg)[1]);
 const tops=[...svg.matchAll(/class="ov-bar"[^>]*d="M[\d.]+,[\d.]+V[\d.]+Q[\d.]+,([\d.]+) /g)].map(m=>Number(m[1]));
 assert.ok(tops.length>=6);
 assert.ok(Math.min(...tops)>=line-0.1,`a bar top ${Math.min(...tops)} is above the line ${line}`);
});
