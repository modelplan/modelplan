// SPDX-License-Identifier: MIT
// CKP-MFD-19 + build 14c, on the v8 comparison (CKP-MFD-33): a fader trial on GPT-6.1 Terra with no live session
// (current unreported, trial XHigh, ★ High). Nothing stands in for the unreported current (no white tick, number or
// column; the note says "current unknown"), and the share chart is still drawn with ★ and the trial marked.
import test from 'node:test';
import assert from 'node:assert/strict';
import {comparison,configShare} from '../../../cockpit/study/rocket-r1/mfd-pages/views.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

// Published GPT-6.1 Terra efforts (ability, cost, time), rounded; the fader drops "non-reasoning".
const terra={id:'model0',name:'GPT-6.1 Terra',short:'Terra 6.1',rec:'High',pool:null,
 e:[['Low',42.38,0.073,0.123],['Med',52.6,0.2,0.2],['High',57.6,0.35,0.3],['XHigh',61.1,0.6,0.45],['Max',70.3,1.1,0.8]]};
globalThis.document??={documentElement:{}}; // setLanguage sets the page language
const view={models:[terra],speedTiers:{},sessionRanking:[],accounts:[],now:0};
const ui={lang:'en',scope:null,fill:{cmp:{w:300,h:60}}};
const nums=html=>[...html.matchAll(/<text class="pc-num pc-(\w+)"[^>]*>(\d+)</g)].map(m=>[m[1],m[2]+'%']);

test('CKP-MFD-19: with current unknown nothing stands in for it; the trial and ★ are still drawn',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:null,trial:'XHigh',currentFast:false});
 assert.match(html,/<em>current unknown<\/em>/);
 assert.doesNotMatch(html,/data-role="current"/);assert.doesNotMatch(html,/pc-band-current/);
 // XHigh: 61.1 / 70.3 and 0.6 / 1.1 of the top effort (Max).
 assert.deepEqual(nums(html),[['trial','87%'],['trial','55%']]);
 assert.match(html,/<svg class="cmp-chart" data-scale="share"/);
 assert.equal((html.match(/<polyline points=/g)??[]).length,3);
 assert.match(html,/class="pc-band pc-band-trial"[^>]*data-effort="XHigh"/);
 assert.match(html,/class="pc-star"[^>]*data-role="rec"/);
});
test('a reported current is the white tick, number and column',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:'Med',trial:'XHigh',currentFast:false});
 assert.deepEqual(nums(html),[['current','75%'],['trial','87%'],['current','18%'],['trial','55%']]);
 assert.match(html,/class="pc-band pc-band-current"[^>]*data-effort="Med"/);
 assert.doesNotMatch(html,/current unknown/);
});
test('configShare: shares of the top effort, for a standard or a fast configuration',()=>{
 const s=configShare(terra,null,'High');
 assert.ok(Math.abs(s.abl-57.6/70.3)<1e-9&&Math.abs(s.cost-.35/1.1)<1e-9&&Math.abs(s.time-.3/.8)<1e-9);
 assert.deepEqual(configShare(terra,null,'Max'),{abl:1,cost:1,time:1});
 const fast=configShare(terra,{speed:1.5,cost:2.5},'High',true);
 assert.ok(Math.abs(fast.cost-.35*2.5/1.1)<1e-9&&Math.abs(fast.time-.3/1.5/.8)<1e-9&&fast.abl===s.abl);
 // A tier that does not state its speed leaves the fast time unknown instead of a made-up number.
 assert.equal(configShare(terra,{speed:1,cost:2.5,taskTimeUnknown:true},'High',true).time,null);
 assert.equal(configShare(terra,null,'Nope'),null);
});

// macrevc-885-1: the reference is the model's published top effort (the top of the ladder), whatever its ability; each
// metric is measured against its own reference value and stays unknown when that value is missing.
test('CKP-MFD-33: the top effort is the top of the published ladder; a missing reference metric gives that metric only as unknown',()=>{
 const m={id:'synthetic',rec:'High',e:[['Low',40,1,1],['High',60,2,2],['Max',null,4,4]]};
 assert.deepEqual(configShare(m,null,'High'),{abl:null,cost:.5,time:.5}); // Max has no ability: High's ability is not "100%"
 assert.deepEqual(configShare(m,null,'Max'),{abl:null,cost:1,time:1});
 const odd={id:'odd',rec:'High',e:[['Low',40,1,1],['High',60,2,2],['Max',50,4,4]]}; // Max is less able than High
 assert.deepEqual(configShare(odd,null,'Max'),{abl:1,cost:1,time:1});
 assert.equal(configShare(odd,null,'High').abl,1.2);
 assert.equal(configShare(odd,null,'High').cost,.5);
 const noCost={id:'nc',rec:'High',e:[['Low',40,1,1],['High',60,2,2],['Max',70,null,4]]};
 assert.deepEqual(configShare(noCost,null,'High'),{abl:60/70,cost:null,time:.5});
});
