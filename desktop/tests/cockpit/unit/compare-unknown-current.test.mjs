// SPDX-License-Identifier: MIT
// Build 14c (owner): a fader trial on GPT-6.1 Terra with no live session (current unreported, trial XHigh, ★ High)
// showed "—" in every column and no chart, because every value was a ratio against the unreported current. With no
// current, the try and ★ columns and the chart are measured against ★; the current column stays "--".
import test from 'node:test';
import assert from 'node:assert/strict';
import {comparison} from '../../../cockpit/study/rocket-r1/mfd-pages/views.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

// Published GPT-6.1 Terra efforts (ability, cost, time), rounded; the fader drops "non-reasoning".
const terra={id:'model0',name:'GPT-6.1 Terra',short:'Terra 6.1',rec:'High',pool:null,
 e:[['Low',42.38,0.073,0.123],['Med',52.6,0.2,0.2],['High',57.6,0.35,0.3],['XHigh',61.1,0.6,0.45],['Max',70.3,1.1,0.8]]};
globalThis.document??={documentElement:{}}; // setLanguage sets the page language
const view={models:[terra],speedTiers:{},sessionRanking:[],accounts:[],now:0};
const ui={lang:'en',scope:null,fill:{cmp:{w:300,h:60}}};
const cells=html=>[...html.matchAll(/<td data-role="(\w+)"[^>]*><span class="cmp-value"[^>]*>([^<]*)</g)].map(m=>[m[1],m[2]]);

test('build 14c: with current unknown, the try and ★ columns have numbers measured against ★, and the chart has lines',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:null,trial:'XHigh',currentFast:false});
 const values=cells(html),of=role=>values.filter(([r])=>r===role).map(([,v])=>v);
 assert.deepEqual(of('current'),['--','--','--']);
 assert.deepEqual(of('rec'),['±0','×1.00','×1.00']);
 const trial=of('trial');assert.equal(trial.length,3);for(const v of trial)assert.match(v,/^[+−±]|^×/);
 assert.deepEqual(trial,['+3.5','×1.71','×1.50']);
 assert.match(html,/current unknown · vs ★/);
 assert.match(html,/<svg class="cmp-chart"[^>]*data-scale="log2"/);
 assert.match(html,/<polyline points=/);
 assert.match(html,/class="cfg cfg-rec"/);assert.match(html,/class="cfg cfg-trial"/);
});
test('a reported current stays the reference for the columns and the chart',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:'Med',trial:'XHigh',currentFast:false});
 const values=cells(html),of=role=>values.filter(([r])=>r===role).map(([,v])=>v);
 assert.deepEqual(of('current'),['±0','×1.00','×1.00']);
 assert.equal(of('rec')[1],'×1.75');
 assert.doesNotMatch(html,/vs ★/);assert.match(html,/<polyline points=/);
});
