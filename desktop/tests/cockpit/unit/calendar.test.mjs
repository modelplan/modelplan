// SPDX-License-Identifier: MIT
// v1.1 calendar plugin (CKP-PLG-06/07): local-time maths (DST, midnight crossing, folding), the strict data shape and
// the shaping from the cockpit display data. Runs in America/Los_Angeles (DST ends 2026-11-01, starts 2026-03-08).
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {capture} from '../fixture.mjs';
import {HOUR,addDays,startOfDay,dayOffset,stripWindow,hourMarks,midnights,dayPieces,packLanes,nextMinute,wallHours,hhmm} from '../../../cockpit/.tmp/compiled/src/calendar-time.js';
import {parseCalendarData,calendarFromCockpit,abbreviation,CALENDAR_MAX_BYTES} from '../../../cockpit/.tmp/compiled/src/calendar-data.js';
import {beyond,dayHasEvents,calendarPlugin} from '../../../cockpit/.tmp/compiled/src/calendar-plugin.js';
import {PluginRegistry} from '../../../cockpit/.tmp/compiled/src/plugin-registry.js';
import {builtinPlugins} from '../../../cockpit/.tmp/compiled/src/plugin-builtins.js';

const local=(y,m,d,h=0,min=0)=>new Date(y,m-1,d,h,min).getTime();
const NOW=local(2026,11,11,11,20);

test('the test runs in the Pacific time zone',()=>{assert.equal(new Date(Date.UTC(2026,10,11,19,20)).getHours(),11);});

test('day boundaries are local midnights: DST days have 25 and 23 hours',()=>{
 const fall=local(2026,11,1,12);// fall back at 02:00
 assert.equal(addDays(fall,1)-startOfDay(fall),25*HOUR);
 const spring=local(2026,3,8,12);// spring forward at 02:00
 assert.equal(addDays(spring,1)-startOfDay(spring),23*HOUR);
 assert.equal(dayOffset(local(2026,10,31,23,30),local(2026,11,1,0,30)),1);
 assert.equal(dayOffset(local(2026,11,1,0,30),local(2026,11,1,23,30)),0);
 // The 明 view of a DST day covers the whole local day.
 const w=stripWindow(local(2026,10,31,9),local(2026,11,1,15));
 assert.deepEqual([w.from,w.to],[local(2026,11,1),local(2026,11,2)]);assert.equal(w.to-w.from,25*HOUR);
 // Hour labels: 01 twice on the fall-back day, no 02 on the spring-forward day.
 assert.deepEqual(hourMarks(w,1).slice(0,4).map(m=>m.hour),[1,1,2,3]);
 assert.deepEqual(hourMarks(stripWindow(local(2026,3,7,9),local(2026,3,8,5)),1).slice(0,3).map(m=>m.hour),[1,3,4]);
});

test('the now view runs 36 hours from now with each local midnight marked',()=>{
 const w=stripWindow(NOW,null);
 assert.equal(w.to-w.from,36*HOUR);
 assert.deepEqual(midnights(w),[local(2026,11,12)]);
 assert.deepEqual(hourMarks(w,3).slice(0,3).map(m=>[hhmm(m.at),m.hour]),[['12:00',12],['15:00',15],['18:00',18]]);
 // From 23:00 the window holds two midnights.
 assert.deepEqual(midnights(stripWindow(local(2026,11,11,23),null)),[local(2026,11,12),local(2026,11,13)]);
 assert.equal(nextMinute(NOW+5000),local(2026,11,11,11,21));
 assert.equal(nextMinute(local(2026,11,11,23,59,)),local(2026,11,12));
});

test('a peak crossing midnight (GLM 22:00–02:00) is one block in the day view and two pieces in the week',()=>{
 const from=local(2026,11,11,22),to=local(2026,11,12,2);
 assert.deepEqual(dayPieces(from,to,startOfDay(NOW),7),[{day:0,start:22,end:24,cont:false},{day:1,start:0,end:2,cont:true}]);
 // Across the fall-back night the wall clock is still the measure (00:00–02:00 local).
 assert.deepEqual(dayPieces(local(2026,10,31,22),local(2026,11,1,2),local(2026,10,31),2),[{day:0,start:22,end:24,cont:false},{day:1,start:0,end:2,cont:true}]);
 assert.equal(wallHours(local(2026,11,12,1,30)),1.5);
 // Nothing outside the seven days.
 assert.deepEqual(dayPieces(local(2026,11,20,5),local(2026,11,20,11),startOfDay(NOW),7),[]);
});

test('overlapping peaks sit side by side; touching ones do not share a group',()=>{
 const lanes=packLanes([{id:'a',start:0,end:10},{id:'b',start:5,end:15},{id:'c',start:15,end:20},{id:'d',start:6,end:8}]);
 const by=Object.fromEntries(lanes.map(x=>[x.item.id,[x.lane,x.lanes]]));
 assert.deepEqual(by,{a:[0,3],b:[1,3],d:[2,3],c:[0,1]});
});

const week={version:1,
 subs:[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}}],
 peaks:[{sub:2,from:local(2026,11,11,22),to:local(2026,11,12,2),tentative:false}],
 resets:[{sub:0,at:local(2026,11,11,12,30),kind:'5h'},{sub:0,at:local(2026,11,12,9),kind:'week'},{sub:1,at:local(2026,11,13,6),kind:'week'}],
 spans:[{sub:0,kind:'cards',from:NOW,to:local(2026,11,13,18),count:1},{sub:2,kind:'announced',from:local(2026,11,10,10),to:local(2026,11,16),count:null}]};

test('the folded line holds what lies beyond 36 hours, earliest first; dots mark days with events',()=>{
 const later=beyond(parseCalendarData(week),stripWindow(NOW,null));
 assert.deepEqual(later.map(x=>[x.kind,x.at]),[['week',local(2026,11,13,6)],['span',local(2026,11,16)]]);
 const data=parseCalendarData(week);
 assert.deepEqual([0,1,2].map(i=>dayHasEvents(data,NOW,i)),[true,true,true]);
 assert.equal(dayHasEvents({...data,resets:[],peaks:[],spans:[]},NOW,1),false);
});

test('calendar data has a strict, bounded shape',()=>{
 const ok=parseCalendarData(week);
 assert.deepEqual(ok,week);assert.ok(Object.isFrozen(ok)&&Object.isFrozen(ok.subs[0]));
 assert.ok(JSON.stringify(week).length<CALENDAR_MAX_BYTES);
 for(const bad of [null,[],{...week,extra:1},{...week,version:2},
  {...week,subs:[{...week.subs[0],abbr:'CLAUDE'}]},{...week,subs:[{...week.subs[0],colour:'orange'}]},{...week,subs:[{...week.subs[0],name:{en:'a\u0007',zh:'b'}}]},
  {...week,peaks:[{sub:3,from:NOW,to:null,tentative:false}]},{...week,peaks:[{sub:0,from:NOW,to:NOW,tentative:false}]},{...week,peaks:[{sub:0,from:'2026-11-11',to:null,tentative:false}]},
  {...week,resets:[{sub:0,at:NOW,kind:'daily'}]},{...week,resets:[{sub:0,at:1.5,kind:'5h'}]},{...week,resets:Array.from({length:65},()=>({sub:0,at:NOW,kind:'5h'}))},
  {...week,spans:[{sub:0,kind:'other',from:NOW,to:null,count:null}]},{...week,spans:[{sub:0,kind:'cards',from:NOW,to:NOW-1,count:null}]},
  {...week,subs:Array.from({length:17},()=>week.subs[0])}])
  assert.equal(parseCalendarData(bad),null,JSON.stringify(bad)?.slice(0,80));
 // The plugin declares this shape and bound to the framework.
 assert.equal(calendarPlugin.data.maxBytes,CALENDAR_MAX_BYTES);assert.equal(calendarPlugin.data.parse,parseCalendarData);
 assert.deepEqual(new PluginRegistry(builtinPlugins).list().map(p=>p.id),['placeholder','calendar']);
 assert.equal(calendarPlugin.defaultEnabled,true);assert.ok(calendarPlugin.expand);
 assert.equal(calendarPlugin.nextDeadline(null,NOW),local(2026,11,11,11,21));
});

test('the framework refuses plugin declarations without a bounded data shape',()=>{
 const base={id:'x',title:{en:'X','zh-CN':'X'},icon:'',defaultEnabled:false,settings:[],render(){}};
 assert.throws(()=>new PluginRegistry([{...base,update(){return true;}}]),/bounded shape/);
 assert.throws(()=>new PluginRegistry([{...base,update(){return true;},data:{maxBytes:1e9,parse:()=>null}}]),/bounded shape/);
 assert.throws(()=>new PluginRegistry([{...base,derive(){return null;}}]),/derive needs update/);
 assert.throws(()=>new PluginRegistry([{...base,expand:{title:{en:'',"zh-CN":''},render(){}}}]),/overlay/);
 assert.doesNotThrow(()=>new PluginRegistry([{...base,update(){return true;},data:{maxBytes:1024,parse:()=>null}}]));
});

function display() {
 const data=capture();delete data.details;
 const seed=data.projection.rows[0],iso=t=>new Date(t).toISOString(),fresh=iso(NOW+HOUR);
 // Two tools the user has (Claude Code verified, Codex) and a declared GLM plan for the peak.
 data.projection.rows=[['claude','Claude Code','claude'],['codex','Codex','openai'],['declared:glm-coding','GLM Coding','glm']].map(([id,name,vendor],i)=>{const row=structuredClone(seed);row.id=id;row.name={en:name,zh:name};row.vendorKey=vendor;row.order=i;
  row.accounts.forEach(a=>{a.valueState='current';a.freshUntil=fresh;if(i)a.subscriptionRef=null;a.accountLocator=null;a.windows=a.windows.slice(0,1).map(({modelScope,...w})=>({...w,current:true,remainingPercent:60,validUntil:fresh,resetsAt:iso(local(2026,11,11,12+i,30)),role:'session'}));});
  return row;});
 const weekly={...data.projection.rows[0].accounts[0].windows[0],id:'weekly',role:'weekly',resetsAt:iso(local(2026,11,12,9))};
 data.projection.rows[0].accounts[0].windows.push(weekly);
 const ref=data.projection.rows[0].accounts[0].subscriptionRef;
 data.details={version:1,sources:[],subscriptions:[{subscriptionRef:ref,resetCounts:[],resetCards:{state:'observed',count:2,items:[{id:'a',expiresAt:iso(local(2026,11,13,18))},{id:'b',expiresAt:iso(local(2026,11,20))}],sources:[{source:'x',observedAt:iso(NOW)}],truncated:false}}],sessions:[],sessionCoverage:'unavailable',alerts:[],
  resetEvents:[{version:1,id:'e1',rowId:'declared:glm-coding',provider:'zhipu',status:'announced',publishedAt:iso(local(2026,11,10,10)),expiresAt:iso(local(2026,11,20)),schedule:{from:iso(local(2026,11,16)),through:iso(local(2026,11,16,1)),precision:'window'},source:{kind:'publication',publicationId:'p'}},
   {version:1,id:'e2',rowId:'not-mine',provider:'x',status:'announced',publishedAt:iso(NOW),expiresAt:iso(local(2026,11,20)),source:{kind:'publication',publicationId:'p'}}],
  peaks:[{rowId:'declared:glm-coding',startsAt:iso(local(2026,11,11,22)),endsAt:iso(local(2026,11,12,2)),status:'confirmed'},{rowId:'codex',startsAt:iso(local(2026,11,11,14)),endsAt:null,status:'tentative'},{rowId:'not-mine',startsAt:iso(NOW),endsAt:null,status:'confirmed'}]};
 return {data,ref};
}

test('shaping from the display data: own subscriptions only, peaks, own 5 h and weekly resets, reset cards, announced resets',()=>{
 const {data,ref}=display();
 data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
 const cal=calendarFromCockpit(data,NOW);
 assert.ok(parseCalendarData(cal),'the shaped data passes the plugin shape');
 assert.deepEqual(cal.subs.map(s=>[s.abbr,s.colour]),[['CL','#ff9a6a'],['CX','#6aa8ff'],['GL','#8f7dff']]);
 assert.deepEqual(cal.peaks,[{sub:1,from:local(2026,11,11,14),to:null,tentative:true},{sub:2,from:local(2026,11,11,22),to:local(2026,11,12,2),tentative:false}]);
 assert.deepEqual(cal.resets.map(r=>[r.sub,r.kind,hhmm(r.at)]),[[0,'5h','12:30'],[1,'5h','13:30'],[2,'5h','14:30'],[0,'week','09:00']]);
 // Cards: the earliest expiry that has not passed, with the count; the announced reset takes effect mid-window, to the half hour.
 assert.deepEqual(cal.spans,[{sub:0,kind:'cards',from:NOW,to:local(2026,11,13,18),count:2},{sub:2,kind:'announced',from:local(2026,11,10,10),to:local(2026,11,16,0,30),count:null}]);
 // Later: the 5 h reset passed, the reading is no longer current, and the peak ended: they drop out.
 const late=calendarFromCockpit(data,local(2026,11,12,3));
 assert.deepEqual(late.resets,[]);assert.deepEqual(late.peaks.map(p=>p.sub),[1]);
});

test('shaping without details or peaks (an older engine) gives an empty but valid calendar',()=>{
 const {data}=display();delete data.details;data.subscriptions=[];
 const cal=calendarFromCockpit(data,NOW);
 assert.deepEqual([cal.peaks,cal.spans],[[],[]]);assert.equal(cal.resets.length,4);
 assert.ok(parseCalendarData(cal));
 assert.equal(abbreviation('tool-x',null,'Some Tool'),'SO');assert.equal(abbreviation('x',null,'工具'),'XX');
});
