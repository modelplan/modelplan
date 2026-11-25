// SPDX-License-Identifier: MIT
// v1.1 calendar plugin (CKP-PLG-06/07): local-time maths (DST, midnight crossing, folding), the strict data shape and
// the shaping from the cockpit display data. Runs in America/Los_Angeles (DST ends 2026-11-01, starts 2026-03-08).
process.env.TZ='America/Los_Angeles';
import test from 'node:test';
import assert from 'node:assert/strict';
import {capture} from '../fixture.mjs';
import {HOUR,addDays,startOfDay,dayOffset,stripWindow,dayWindow,hourMarks,midnights,dayPieces,packLanes,nextMinute,wallHours,hhmm} from '../../../cockpit/.tmp/compiled/src/calendar-time.js';
import {parseCalendarData,calendarFromCockpit,abbreviation,shortName,CALENDAR_MAX_BYTES} from '../../../cockpit/.tmp/compiled/src/calendar-data.js';
import {duration,dayEvents,calendarPlugin} from '../../../cockpit/.tmp/compiled/src/calendar-plugin.js';
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
 // A picked day's window covers the whole local day.
 const w=dayWindow(local(2026,11,1,15));
 assert.deepEqual([w.from,w.to],[local(2026,11,1),local(2026,11,2)]);assert.equal(w.to-w.from,25*HOUR);
 // Hour labels: 01 twice on the fall-back day, no 02 on the spring-forward day.
 assert.deepEqual(hourMarks(w,1).slice(0,4).map(m=>m.hour),[1,1,2,3]);
 assert.deepEqual(hourMarks(dayWindow(local(2026,3,8,5)),1).slice(0,3).map(m=>m.hour),[1,3,4]);
});

test('D328: the column window is the next 12 hours from now, with a midnight marked only when one falls inside',()=>{
 const w=stripWindow(NOW);
 assert.equal(w.to-w.from,12*HOUR);assert.equal(w.from,NOW);
 assert.deepEqual(midnights(w),[]);
 assert.deepEqual(hourMarks(w,3).slice(0,3).map(m=>[hhmm(m.at),m.hour]),[['12:00',12],['15:00',15],['18:00',18]]);
 // From 23:00 the window holds one midnight (the 明 divider).
 assert.deepEqual(midnights(stripWindow(local(2026,11,11,23))),[local(2026,11,12)]);
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

const week={version:1,peakRules:'yes',
 subs:[{abbr:'CL',colour:'#ff9a6a',name:{en:'Claude',zh:'Claude'}},{abbr:'CX',colour:'#6aa8ff',name:{en:'Codex',zh:'Codex'}},{abbr:'GL',colour:'#8f7dff',name:{en:'GLM',zh:'GLM'}}],
 peaks:[{sub:2,from:local(2026,11,11,22),to:local(2026,11,12,2),tentative:false}],
 resets:[{sub:0,at:local(2026,11,11,12,30),kind:'5h'},{sub:0,at:local(2026,11,12,9),kind:'week'},{sub:1,at:local(2026,11,13,6),kind:'week'}],
 spans:[{sub:0,kind:'cards',from:NOW,to:local(2026,11,13,18),count:1},{sub:2,kind:'announced',from:local(2026,11,10,10),to:local(2026,11,16),count:null}]};

test('the bottom line durations read 10h40 and 35m',()=>{
 assert.equal(duration(10*HOUR+40*60000),'10h40');assert.equal(duration(2*HOUR+50*60000),'2h50');assert.equal(duration(35*60000),'35m');assert.equal(duration(HOUR),'1h00');
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
 // The plugin's accept is this shape, bounded as JSON first: a refusal is `undefined` (the framework keeps the last reading).
 assert.deepEqual(calendarPlugin.accept(week,undefined),parseCalendarData(week));
 assert.equal(calendarPlugin.accept({...week,extra:1},undefined),undefined);
 assert.equal(calendarPlugin.accept({...week,subs:[{...week.subs[0],name:{en:'x'.repeat(CALENDAR_MAX_BYTES),zh:'y'}}]},undefined),undefined,'over the byte bound');
 assert.deepEqual(new PluginRegistry(builtinPlugins).list().map(p=>p.id),['placeholder','calendar','resources']);
 assert.equal(calendarPlugin.defaultEnabled,true);
 assert.equal(calendarPlugin.nextDeadline(null,NOW),local(2026,11,11,11,21));
 assert.equal(calendarPlugin.nextDeadline(null,0),null,'no host time yet: no deadline');
});

const words=(key,vars)=>({full:key+(vars?JSON.stringify(vars):''),short:key+'Short'});
const context={locale:'en',settings:{},now:NOW,words};

test('D323/D328: the calendar draws its column and screen, and falls back to D293 cells and lines',()=>{
 const reading=calendarPlugin.accept(week,undefined);
 const column=calendarPlugin.column(reading,context),screen=calendarPlugin.screen(reading,context);
 assert.equal(typeof column.draw,'function');assert.equal(typeof screen.draw,'function');
 assert.ok(column.cells.length>=2&&column.cells.length<=3);
 assert.deepEqual(column.cells.slice(0,2).map(c=>c.tag.full),['plugin.calendarReset','plugin.calWeekReset']);
 assert.equal(column.cells[0].big,'12:30');assert.equal(column.cells[0].side.full,'plugin.calIn{"t":"1h10"}');
 assert.deepEqual([column.cells[0].subline.colour,column.cells[0].subline.text.full.startsWith('Claude '),column.cells[0].subline.text.short],['#ff9a6a',true,'Claude']);
 // The bottom line: the next peak, here GL at 22:00, 10h40 away.
 assert.equal(column.foot.label.full,'plugin.calendarPeak');assert.equal(column.foot.value.full,'plugin.calIn{"t":"10h40"}');
 assert.ok(screen.lines.length>0&&screen.lines.every(l=>typeof l.label==='string'&&typeof l.value==='string'));
 // While a peak runs: "GL peak now" and what is left.
 const live=calendarPlugin.column(calendarPlugin.accept(week,undefined),{...context,now:local(2026,11,11,23)});
 assert.equal(live.foot.label.full,'plugin.calPeakNow{"a":"GLM"}');assert.equal(live.foot.value.full,'plugin.calLeft{"t":"3h00"}');
 // Before the first reading or host time: one waiting cell, no foot, no draw.
 const waiting=calendarPlugin.column(undefined,{...context,now:0});
 assert.deepEqual(waiting.cells.map(c=>c.tag.full),['plugin.calendarWaiting']);assert.equal(waiting.foot,null);assert.equal(waiting.draw,null);
});

test('D328: a user with no peak rules gets D293 cells and "Peak: no peak rules", and no strip',()=>{
 const codexOnly={...week,peakRules:'no',subs:[week.subs[1]],peaks:[],resets:[{sub:0,at:local(2026,11,11,14,10),kind:'5h'},{sub:0,at:local(2026,11,13,6),kind:'week'}],spans:[]};
 const column=calendarPlugin.column(calendarPlugin.accept(codexOnly,undefined),context);
 assert.equal(column.draw,null,'column() returns no draw without peak data');
 assert.deepEqual(column.cells.map(c=>c.tag.full),['plugin.calendarReset','plugin.calWeekReset']);
 assert.equal(column.cells[0].big,'14:10');assert.equal(column.cells[0].side.full,'plugin.calIn{"t":"2h50"}');
 assert.equal(column.cells[1].big,'06:00');assert.equal(column.cells[1].subline.text.short,'Codex');
 assert.equal(column.foot.label.full,'plugin.calPeakLabel');assert.equal(column.foot.value.full,'plugin.calNoRules');
});

test('D328: a day picked in the week view swaps the bottom line to that day\'s events; today (or a rolled-over day) restores it',()=>{
 const reading=calendarPlugin.accept(week,undefined),memo={view:{day:local(2026,11,12),zoom:24,centre:null}};
 const picked=calendarPlugin.column(reading,{...context,memo});
 assert.match(picked.foot.label.full,/11\/12/);
 assert.equal(picked.foot.value.full,'Claude plugin.calWk 09:00');
 assert.deepEqual(dayEvents(parseCalendarData(week),local(2026,11,12),{r5:'5h',wk:'wk',peak:'peak'}),['Claude wk 09:00']);
 // An empty day says so.
 assert.equal(calendarPlugin.column(reading,{...context,memo:{view:{day:local(2026,11,14),zoom:24,centre:null}}}).foot.value.full,'plugin.calendarNone');
 // The day rolled over (picked day is today now): back to the default line.
 const rolled=calendarPlugin.column(reading,{...context,now:local(2026,11,12,3),memo});
 assert.equal(rolled.foot.label.full,'plugin.calPeakLabel');assert.equal(memo.view.day,null);
});

test('the framework refuses a plugin whose derive or nextDeadline is not a function',()=>{
 const base={id:'x',title:'plugin.calendarTitle',summary:'plugin.calendarSummary',icon:'',underline:'#87939e',defaultEnabled:false,settings:[],accept:()=>undefined,column:()=>({cells:[]}),screen:()=>({lines:[]})};
 assert.throws(()=>new PluginRegistry([{...base,derive:1}]),/Invalid cockpit plugin/);
 assert.throws(()=>new PluginRegistry([{...base,nextDeadline:'soon'}]),/Invalid cockpit plugin/);
 assert.doesNotThrow(()=>new PluginRegistry([{...base,derive:()=>null,nextDeadline:()=>null}]));
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
 data.details={version:1,sources:[],subscriptions:[{subscriptionRef:ref,resetCounts:[],resetCards:{state:'complete',count:2,items:[{id:'a',expiresAt:iso(local(2026,11,13,18))},{id:'b',expiresAt:iso(local(2026,11,20))}],sources:[{source:'x',observedAt:iso(NOW)}],truncated:false}}],sessions:[],sessionCoverage:'unavailable',alerts:[],
  resetEvents:[{version:1,id:'e1',rowId:'declared:glm-coding',provider:'zhipu',status:'announced',publishedAt:iso(local(2026,11,10,10)),expiresAt:iso(local(2026,11,20)),schedule:{from:iso(local(2026,11,16)),through:iso(local(2026,11,16,1)),precision:'window'},source:{kind:'publication',publicationId:'p'}},
   {version:1,id:'e2',rowId:'not-mine',provider:'x',status:'announced',publishedAt:iso(NOW),expiresAt:iso(local(2026,11,20)),source:{kind:'publication',publicationId:'p'}}],
  peaks:[{rowId:'declared:glm-coding',startsAt:iso(local(2026,11,11,22)),endsAt:iso(local(2026,11,12,2)),status:'confirmed'},{rowId:'codex',startsAt:iso(local(2026,11,11,14)),endsAt:null,status:'tentative'},{rowId:'not-mine',startsAt:iso(NOW),endsAt:null,status:'confirmed'}]};
 return {data,ref};
}

test('shaping from the display data: own subscriptions only, peaks, own 5 h and weekly resets, banked resets, announced resets',()=>{
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

// --- macrevc-844 findings -----------------------------------------------------------------------------------------
test('macrevc-844-3: a peak through the fall-back repeated hour keeps a positive, correctly placed interval; spring-forward too',()=>{
 const fall=dayPieces(Date.parse('2026-11-01T01:30:00-07:00'),Date.parse('2026-11-01T01:15:00-08:00'),local(2026,11,1),1);
 assert.equal(fall.length,1);assert.equal(fall[0].start,1.5);
 assert.ok(fall[0].end>fall[0].start,'45 real minutes is not zero height');assert.ok(Math.abs(fall[0].end-fall[0].start-0.75)<1e-9);
 // Across the transition the wall clock stays the measure (01:00 first pass to 04:00 is 01:00-04:00 on the clock).
 const across=dayPieces(Date.parse('2026-11-01T00:30:00-07:00'),Date.parse('2026-11-01T04:00:00-08:00'),local(2026,11,1),1);
 assert.deepEqual([across[0].start,across[0].end],[0.5,4]);
 const spring=dayPieces(Date.parse('2026-03-08T01:30:00-08:00'),Date.parse('2026-03-08T03:30:00-07:00'),local(2026,3,8),1);
 assert.deepEqual([spring[0].start,spring[0].end],[1.5,3.5]);assert.ok(spring[0].end>spring[0].start);
});

test('macrevc-844-4: missing peak data, no window and known no-rules are three states, and only the last says "No rules"',()=>{
 const {data}=display();
 // Feed absent (an older engine): unknown.
 const noFeed=structuredClone(data);delete noFeed.details;noFeed.subscriptions=[];
 assert.equal(calendarFromCockpit(noFeed,NOW).peakRules,'unknown');
 // Feed present, empty, the user has a declared plan: no window in the next 24 h, rules not disproved.
 const noWindow=structuredClone(data);noWindow.details.peaks=[];noWindow.subscriptions=[];
 assert.equal(calendarFromCockpit(noWindow,NOW).peakRules,'yes');
 // Feed present, empty, only tool rows (no declared plan): no peak rules.
 const noRules=structuredClone(data);noRules.details.peaks=[];noRules.subscriptions=[];noRules.projection.rows=noRules.projection.rows.filter(r=>!r.id.startsWith('declared:'));
 assert.equal(calendarFromCockpit(noRules,NOW).peakRules,'no');
 const column=peakRules=>calendarPlugin.column(calendarPlugin.accept({...week,peaks:[],peakRules},undefined),context).foot.value.full;
 assert.equal(column('no'),'plugin.calNoRules');
 assert.notEqual(column('yes'),'plugin.calNoRules');assert.equal(column('yes'),'plugin.calendarNone');
 assert.notEqual(column('unknown'),'plugin.calNoRules');assert.equal(column('unknown'),'plugin.calPeaksUnknown');
 // Host data that does not say is unknown; a bad value is refused.
 const {peakRules,...bare}={...week,peakRules:'yes'};
 assert.equal(parseCalendarData(bare).peakRules,'unknown');assert.equal(parseCalendarData({...week,peakRules:'maybe'}),null);
});

test('macrevc-844-5: a partial, truncated or short reset-card list is never an exact count or expiry',()=>{
 const shaped=(cards,at=NOW)=>{const {data,ref}=display();data.subscriptions=[{subscriptionRef:ref,accounts:[]}];Object.assign(data.details.subscriptions[0].resetCards,cards);return calendarFromCockpit(data,at).spans.filter(s=>s.kind==='cards');};
 assert.deepEqual(shaped({}).map(s=>s.count),[2],'complete list: exact');
 for(const cards of [{state:'partial'},{truncated:true},{count:3}]){
  const [s]=shaped(cards);assert.equal(s.count,null,JSON.stringify(cards));
 }
 // A partial list with no producer-stated earliest expiry has no date either.
 assert.equal(shaped({state:'partial'})[0].to,null);
 const earliest=new Date(local(2026,11,12,18)).toISOString();
 assert.equal(shaped({truncated:true,earliestExpiresAt:earliest})[0].to,local(2026,11,12,18));
 // Items without an expiry are still available cards (as the alert list counts them).
 assert.deepEqual(shaped({items:[{id:'a'},{id:'b'}]}).map(s=>[s.count,s.to]),[[2,null]]);
 const text=calendarPlugin.column(calendarPlugin.accept({...week,spans:[{sub:0,kind:'cards',from:NOW,to:null,count:null}]},undefined),context);
 assert.ok(!/×/.test(JSON.stringify(text.cells)));
});

test('macrevc-844-6: a card span with no expiry never becomes a date (column cell, strip text, week)',()=>{
 const reading=calendarPlugin.accept({...week,peakRules:'yes',spans:[{sub:0,kind:'cards',from:NOW,to:null,count:2}]},undefined);
 assert.ok(reading,'null expiry stays a valid shape');
 const cells=calendarPlugin.column(reading,{...context,now:NOW}).cells;
 for(const c of cells)assert.ok(!/1969|1970|12\/31|\b1\/1\b/.test(JSON.stringify(c)),JSON.stringify(c));
 const noPeak=calendarPlugin.column(calendarPlugin.accept({...week,peaks:[],peakRules:'no',resets:[],spans:[{sub:0,kind:'cards',from:NOW,to:null,count:null}]},undefined),context).cells;
 const card=noPeak.find(c=>c.tag.full==='plugin.calendarCards');assert.ok(card,'the cards cell is still shown');
 assert.ok(!/\d+\/\d+/.test(JSON.stringify(card.side)),JSON.stringify(card.side));
});

test('macrevc-844-8: after the producer\'s earliest expiry passes, a partial list keeps its live cards (no total, no later exact date)',()=>{
 const shaped=(at)=>{const {data,ref}=display();data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
  const iso=t=>new Date(t).toISOString(),first=NOW+60_000,later=NOW+3*HOUR;
  Object.assign(data.details.subscriptions[0].resetCards,{state:'partial',truncated:true,count:65,earliestExpiresAt:iso(first),items:Array.from({length:64},(_,i)=>({id:'c'+i,expiresAt:iso(i?later:first)}))});
  return calendarFromCockpit(data,at).spans.filter(x=>x.kind==='cards');};
 assert.deepEqual(shaped(NOW).map(x=>[x.count,x.to]),[[null,NOW+60_000]],'before the deadline: the stated earliest expiry');
 // Two minutes later the first card is gone; 63 listed cards are live.
 assert.deepEqual(shaped(NOW+120_000).map(x=>[x.count,x.to]),[[null,null]],'after: still shown, no total, no invented date');
 // Everything listed expired and the stated expiry passed: nothing known to be live.
 assert.deepEqual(shaped(NOW+4*HOUR),[]);
 // A complete list whose live cards have no expiry keeps them after the stated earliest passes.
 const {data,ref}=display();data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
 Object.assign(data.details.subscriptions[0].resetCards,{count:1,earliestExpiresAt:new Date(NOW-1000).toISOString(),items:[{id:'z'}]});
 assert.deepEqual(calendarFromCockpit(data,NOW).spans.filter(x=>x.kind==='cards').map(x=>[x.count,x.to]),[[1,null]]);
});

// --- D375: names, not codes; big time; distinct moments; no rules ------------------------------------------------------
test('D375: a long name keeps 6 characters and an ellipsis; a short one stays whole',()=>{
 assert.equal(shortName('Codex'),'Codex');assert.equal(shortName('OpenCode'),'OpenCo…');assert.equal(shortName('MiniMax'),'MiniMax');
 assert.equal(shortName('OpenCode Go'),'OpenCo…');
});

test('D375: no text the calendar writes carries a two-letter code (cells, bottom line, day events, titles)',()=>{
 const reading=calendarPlugin.accept(week,undefined),col=calendarPlugin.column(reading,context);
 const text=JSON.stringify([col.cells,col.foot,calendarPlugin.screen(reading,context).lines,dayEvents(parseCalendarData(week),local(2026,11,12),{r5:'5h',wk:'wk',peak:'peak'})]);
 assert.ok(!/\b(CL|CX|GL|CU)\b/.test(text),text);
 assert.match(text,/Claude/);
});

test('D375: two rows are two moments; the same moment is written once',()=>{
 const own=resets=>calendarPlugin.column(calendarPlugin.accept({...week,peakRules:'no',peaks:[],spans:[],subs:[week.subs[1]],resets},undefined),context);
 // 5 h and weekly reset: two rows, two times, each with the subscription's colour and name.
 const two=own([{sub:0,at:local(2026,11,11,14,10),kind:'5h'},{sub:0,at:local(2026,11,13,6),kind:'week'}]);
 assert.deepEqual(two.cells.map(c=>c.big),['14:10','06:00']);assert.deepEqual(two.cells.map(c=>c.subline.colour),['#6aa8ff','#6aa8ff']);
 // The 5 h window is over (nothing to read): the next reset IS the weekly one; it is written once, not under both rows.
 const one=own([{sub:0,at:local(2026,11,13,6),kind:'week'}]);
 assert.deepEqual(one.cells.map(c=>[c.tag.full,c.big]),[['plugin.calendarReset','06:00']]);
 assert.equal(one.cells[0].subline.text.full.startsWith('Codex plugin.calWinWeek'),true);
 // Nothing known: the "none" word, never a code.
 assert.deepEqual(own([]).cells.map(c=>c.tag.full),['plugin.calendarReset','plugin.calWeekReset']);
});

test('D375: an empty peaks list is "no rules"; a missing field is unknown (never the same line)',()=>{
 const {data}=display();data.subscriptions=[];data.projection.rows=data.projection.rows.filter(r=>!r.id.startsWith('declared:'));
 data.details.peaks=[];
 const foot=d=>calendarPlugin.column(calendarPlugin.accept(calendarFromCockpit(d,NOW),undefined),context).foot.value.full;
 assert.equal(foot(data),'plugin.calNoRules');
 delete data.details.peaks;
 assert.equal(foot(data),'plugin.calPeaksUnknown');
});

test('D406: reset-card notices with no stated time sit on the day they were published; direct resets stay a separate kind',()=>{
 const {data,ref}=display();
 data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
  const iso=t=>new Date(t).toISOString();
 const ev=(id,kind,publishedAt,schedule)=>({version:1,id,rowId:'codex',provider:'openai',kind,status:'announced',publishedAt:iso(publishedAt),expiresAt:iso(local(2026,11,20)),...(schedule?{schedule}:{}),source:{kind:'publication',publicationId:'p'}});
 data.details.resetEvents=[ev('c1','reset_credit',NOW),ev('c2','reset_credit',local(2026,11,10,9),{from:iso(local(2026,11,14,8)),through:iso(local(2026,11,14,8)),precision:'exact'}),ev('d1','direct_reset',NOW)];
 const cal=calendarFromCockpit(data,NOW);
 assert.ok(parseCalendarData(cal));
 const at=cal.spans.filter(x=>x.kind!=='cards').map(x=>[x.kind,x.from,x.to,x.count]);
 assert.deepEqual(at,[['credit',NOW,null,1],['credit',local(2026,11,14,8),local(2026,11,14,8),1],['announced',NOW,null,null]]);
});

test('D406 review: a point deadline before local midnight stays on its day; a confirmed banked reset keeps its status',()=>{
 const {data,ref}=display();
 data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
 const iso=t=>new Date(t).toISOString();
 const ev=(id,status,schedule)=>({version:1,id,rowId:'codex',provider:'openai',kind:'reset_credit',status,publishedAt:iso(local(2026,11,10,9)),expiresAt:iso(local(2026,11,20)),...(schedule?{schedule}:{}),source:{kind:'publication',publicationId:'p'}});
 const late=local(2026,11,14,23,50);
 data.details.resetEvents=[ev('a','announced',{from:iso(late),through:iso(late),precision:'exact'}),ev('b','confirmed')];
 const cal=calendarFromCockpit(data,NOW),credit=cal.spans.filter(x=>x.kind!=='cards');
 assert.equal(new Date(credit[0].to).getDate(),14,'23:50 is still the 14th');
 assert.deepEqual(credit.map(x=>x.kind),['credit','creditConfirmed']);
 assert.ok(parseCalendarData(cal));
});

test('D406 round 2: the half-hour floor is local: 00:05 in Asia/Kathmandu stays on its own day',()=>{
 const keep=process.env.TZ;process.env.TZ='Asia/Kathmandu';
 try{
  const {data,ref}=display();data.subscriptions=[{subscriptionRef:ref,accounts:[]}];
  const at=Date.UTC(2026,10,25,18,20);// 2026-11-26 00:05 in Kathmandu
  const iso=t=>new Date(t).toISOString();
  data.details.resetEvents=[{version:1,id:'k',rowId:'codex',provider:'openai',kind:'reset_credit',status:'announced',publishedAt:iso(at-3600e3),expiresAt:iso(at+9*86400e3),schedule:{from:iso(at),through:iso(at),precision:'exact'},source:{kind:'publication',publicationId:'p'}}];
  const span=calendarFromCockpit(data,at-7200e3).spans.find(x=>x.kind==='credit');
  assert.equal(new Date(span.to).getDate(),26);assert.equal(new Date(span.to).getHours(),0);
 }finally{process.env.TZ=keep;}
});
