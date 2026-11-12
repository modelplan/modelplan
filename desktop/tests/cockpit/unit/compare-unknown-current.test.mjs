// SPDX-License-Identifier: MIT
// Build 14c (owner): a fader trial on GPT-6.1 Terra with no live session (current unreported, trial XHigh, ★ High)
// showed no chart, because the chart's ratios were taken against the unreported current. The table keeps its dashes
// (CKP-MFD-19: never ★ as a stand-in); the chart is drawn relative to ★ = 1, with ★ and trial markers.
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

test('build 14c: with current unknown the table shows dashes (CKP-MFD-19) and the chart is drawn relative to ★',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:null,trial:'XHigh',currentFast:false});
 const values=cells(html),of=role=>values.filter(([r])=>r===role).map(([,v])=>v);
 assert.deepEqual(of('current'),['--','--','--']);
 // Never ★ as a stand-in for current in the table.
 assert.deepEqual(of('trial'),['—','—','—']);assert.deepEqual(of('rec'),['—','—','—']);
 assert.match(html,/current unknown · chart relative to ★/);
 assert.match(html,/<svg class="cmp-chart"[^>]*data-scale="log2"/);
 assert.equal((html.match(/<polyline points=/g)??[]).length,3);
 // ★ is the chart's ×1: its marks sit on the ×1 line; the trial (XHigh) is marked too.
 assert.match(html,/class="cfg cfg-rec" data-config="High:normal"/);assert.match(html,/class="cfg cfg-trial" data-config="XHigh:normal"/);
 assert.match(html,/data-effort="High" data-v="1"/);
});
test('a reported current stays the reference for the columns and the chart',()=>{
 setLanguage('en');
 const html=comparison(view,ui,{modelId:'model0',current:'Med',trial:'XHigh',currentFast:false});
 const values=cells(html),of=role=>values.filter(([r])=>r===role).map(([,v])=>v);
 assert.deepEqual(of('current'),['±0','×1.00','×1.00']);
 assert.equal(of('rec')[1],'×1.75');
 assert.doesNotMatch(html,/relative to ★/);assert.match(html,/<polyline points=/);
});
