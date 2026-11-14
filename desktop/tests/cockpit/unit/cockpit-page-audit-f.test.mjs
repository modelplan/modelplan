// SPDX-License-Identifier: MIT
// Audit F (11-11, cockpit web page logic): pure-logic checks for the findings that do not need a browser. The deck
// wiring (bank paging, re-delivery, the ghost element) is covered by browser/cockpit-page-audit-f.spec.mjs in CI.
process.env.TZ='America/Los_Angeles'; // before any Date use: finding 6 crosses the 2026-11-01 DST change
import test from 'node:test';
import assert from 'node:assert/strict';
import {positionalRemap,refreshComparison,comparisonInput} from '../../../cockpit/.tmp/compiled/src/fader-identity.js';
import {fieldModel} from '../../../cockpit/.tmp/compiled/src/field-model.js';
import {frontierPoints,frontierSvg} from '../../../cockpit/study/rocket-r1/mfd-pages/frontier.js';
import {comparison} from '../../../cockpit/study/rocket-r1/mfd-pages/views.js';
import {overviewBars,heatCells} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';
import {md} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}}; // setLanguage sets the page language
const e=[['Low',42.38,0.073,0.123],['Med',52.6,0.2,0.2],['High',57.6,0.35,0.3],['XHigh',61.1,0.6,0.45],['Max',70.3,1.1,0.8]];
const fader=(over={})=>({id:'model0',sourceId:'gpt-6.1-terra',name:'GPT-6.1 Terra',short:'Terra 6.1',rec:'High',e,current:'Med',currentFast:false,...over});
const ui={lang:'en',scope:null,fill:{cmp:{w:300,h:60}}};
const cmpOf=(f,open)=>{const {model,args}=comparisonInput(f,open,null);return comparison({models:[model],speedTiers:{},sessionRanking:[],accounts:[],now:0},ui,args);};
// The v8 comparison is share bars and a chart (CKP-MFD-33), not a table: the current and trial columns are bands keyed by effort.
const head=(html,role)=>html.match(new RegExp(`<rect class="pc-band pc-band-${role}"[^>]*data-effort="([^"]*)"`))?.[1]??'--';

test('audit F 1: positional fader ids follow the published model across a reordering delivery, and drop when it is gone',()=>{
 // A,B,C,D,E with D in a trial at model3; D's session ends and E's stays, so the adapter reorders to A,B,C,E,D.
 const move=positionalRemap(['A','B','C','D','E'],['A','B','C','E','D']);
 assert.equal(move('model3'),'model4');assert.equal(move('model4'),'model3');assert.equal(move('model0'),'model0');
 assert.equal(positionalRemap(['A','B','C','D'],['A','B','C'])('model3'),null);
 assert.equal(move('model9'),null);
 assert.equal(move('gpt-6.1-terra'),'gpt-6.1-terra'); // a published id (the publication's selectedModel) passes through
});

test('audit F 2: the comparison measures against the session effort reported now, not the one when it opened',()=>{
 setLanguage('en');
 const open={modelId:'model0',trial:'XHigh'};
 assert.equal(head(cmpOf(fader({current:'Med'}),open),'current'),'Med');
 // Same comparison, a later delivery: the session reports High.
 const later=cmpOf(fader({current:'High'}),open);
 assert.equal(head(later,'current'),'High');
 // The ability bar's current number is High's share of the top effort (57.6 / 70.3 = 82%), not the old Med's (52.6 / 70.3 = 75%).
 assert.equal([...later.matchAll(/<text class="pc-num pc-current"[^>]*>(\d+)</g)][0]?.[1],'82');
 // The session ended: current is unreported again, table dashes (CKP-MFD-19).
 assert.equal(head(cmpOf(fader({current:null}),open),'current'),'--');
 assert.equal(comparisonInput(fader({currentFast:true}),open,null).args.currentFast,true);
 // The deck's held state: a real trial survives a new reading; an LCD-opened card (trial = the old current) follows it.
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:false,trial:'XHigh'},{current:'High',currentFast:true}),
  {modelId:'model0',current:'High',currentFast:true,trial:'XHigh'});
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:false,trial:'Med'},{current:'High',currentFast:false}),
  {modelId:'model0',current:'High',currentFast:false});
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:false,trial:'Med'},{current:'Med',currentFast:false}),
  {modelId:'model0',current:'Med',currentFast:false,trial:'Med'});
 // A Fast choice on the same effort is a real trial (a Fast-only trial, on or off): it survives a new reading; the same
 // effort with Fast left as reported is still untouched and follows.
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:false,trial:'Med',fast:true},{current:'High',currentFast:false}),
  {modelId:'model0',current:'High',currentFast:false,trial:'Med',fast:true});
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:true,trial:'Med',fast:false},{current:'High',currentFast:true}),
  {modelId:'model0',current:'High',currentFast:true,trial:'Med',fast:false});
 assert.deepEqual(refreshComparison({modelId:'model0',current:'Med',currentFast:false,trial:'Med',fast:false},{current:'High',currentFast:false}),
  {modelId:'model0',current:'High',currentFast:false,fast:false});
});

test('audit F 3: of two points at the same cost only the more able one is on the frontier, in either order',()=>{
 const A={id:'a',rec:'High',e:[['High',40,1,0]]},B={id:'b',rec:'High',e:[['High',60,1,0]]};
 for(const models of [[A,B],[B,A]])assert.deepEqual(frontierPoints(models).map(p=>p.m.id),['b']);
});

test('audit F 4: the Effort chart marks the current effort when the session reports the wire key, not the label',()=>{
 setLanguage('en');
 const published={id:'gpt-6.1-sol',name:'GPT-6.1 Sol',developerId:'openai',recommended:'high',efforts:[
  {effort:'medium',label:'Med',ability:50,cost:1,time:1},{effort:'high',label:'High',star:true,ability:60,cost:2,time:2}]};
 const m=fieldModel(published);
 assert.deepEqual(m.e.map(r=>r[0]),['Med','High']); // the label is what the chart prints
 for(const [reported,label] of [['high','High'],['medium','Med'],['High','High']]){
  const svg=frontierSvg([m],{w:260,h:180,current:{[m.id]:reported}});
  assert.equal((svg.match(/class="fc-cur"/g)??[]).length,1,reported);
  assert.match(svg,new RegExp(`GPT-6.1 Sol[^"]*${label}[^"]*current`,'i'),reported);
 }
});

test('audit F 5: the comparison\'s website link names the published model, not the fader position',()=>{
 setLanguage('en');
 const html=cmpOf(fader(),{modelId:'model0'});
 assert.match(html,/href="[^"]*\/effort\?model=gpt-6\.1-terra"/);assert.doesNotMatch(html,/model=model0/);
});

test('audit F 6: daily bars and heatmap cells keep their calendar dates across the DST change',()=>{
 setLanguage('en');
 const now=new Date(2026,10,2,23,30).getTime(); // 2 Nov 2026 23:30 in Los Angeles, the day after DST ended
 const values=Array(182).fill(null);values[181]=1e6;values[180]=2e6;values[179]=3e6; // 2 Nov, 1 Nov, 31 Oct
 const a={id:'member0',short:'Pro',name:'Pro',colour:'#6aa8ff',vendor:'openai'};
 const d={now,accounts:[a],daily:[{accountId:a.id,values,imported:[],coverageStart:new Date(2026,9,1).getTime()}]};
 const view={lang:'en',days:7,stack:true,scope:null,fill:{}},list=[{a,daily:d.daily[0]}];
 const label=day=>md(new Date(2026,day[0],day[1],12).getTime(),view);
 const svg=overviewBars(d,view,list),tipOf=total=>svg.match(new RegExp(`data-total="${total}"[^>]*data-tip="([^"\\n&]*)`))?.[1];
 assert.ok(tipOf(3000000).startsWith(label([9,31])),tipOf(3000000));
 assert.ok(tipOf(2000000).startsWith(label([10,1])),tipOf(2000000));
 const {cells}=heatCells(d,view,list),dateOf=total=>md(cells.find(c=>c.total===total).at,view);
 assert.equal(dateOf(3e6),label([9,31]));assert.equal(dateOf(2e6),label([10,1]));assert.equal(dateOf(1e6),label([10,2]));
});
