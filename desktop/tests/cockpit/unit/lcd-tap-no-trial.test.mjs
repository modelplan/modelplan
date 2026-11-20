// SPDX-License-Identifier: MIT
// G3-87 (build 14c, owner): pressing a fader's LCD without moving the fader put it in trial mode (LCD "试 = ★", the
// comparison's trial slot lit "= ★ High"). Pressing the LCD only selects the model for the comparison; a trial exists
// only while the fader sits on another effort than the real cap (current, or ★ when current is unreported), and moving
// it back onto the real cap ends the trial (CKP-FAD-09, CKP-FAD-17).
import test from 'node:test';
import assert from 'node:assert/strict';
import {faderModel,lcdView} from '../../../cockpit/study/rocket-r1/fader-view.js';
import {comparison} from '../../../cockpit/study/rocket-r1/mfd-pages/views.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/faders.js';
import '../../../cockpit/study/rocket-r1/strings/mfd.js';

globalThis.document??={documentElement:{}}; // setLanguage sets the page language
const e=[['Low',42.38,0.073,0.123],['Med',52.6,0.2,0.2],['High',57.6,0.35,0.3],['XHigh',61.1,0.6,0.45],['Max',70.3,1.1,0.8]];
const fader=current=>({id:'model0',name:'GPT-6.1 Terra',short:'Terra 6.1',rec:'High',e,current,currentFast:false,tier:null,live:!!current,pinned:false,others:{},accounts:[],sessions:[]});
// The deck's state after pressing the LCD (prototype-deck.ts pressStrip → openCompare): the comparison is open with the
// current effort as its trial argument (none when unreported) and no preview (ghost).
const channel=(current,{previews={},trial}={})=>faderModel({faders:[fader(current)],accounts:[]},
 {bank:0,bankSize:3,selModel:'model0',previews,view:{modelId:'model0',trial:trial??current??undefined,fast:null,from:'fader',key:'model0'}}).channels[0];
const view={models:[{id:'model0',name:'GPT-6.1 Terra',short:'Terra 6.1',rec:'High',pool:null,e}],speedTiers:{},sessionRanking:[],accounts:[],now:0};
const ui={lang:'zh',scope:null,fill:{cmp:{w:300,h:60}}};
// v8 comparison (CKP-MFD-33): a trial is the blue tick/number on the bars and the blue chart column.
const tried=html=>/data-role="trial"/.test(html);

test('G3-87: pressing the LCD with current unreported opens the comparison without a trial',()=>{
 setLanguage('zh');
 const c=channel(null);
 assert.equal(c.trial,null);assert.ok(c.bars.every(b=>!b.trial));
 assert.doesNotMatch(lcdView(c),/试/);
 const html=comparison(view,ui,{modelId:'model0',current:null,currentFast:false});
 // No trial anywhere (no blue tick, number or column, no lit ladder key); ★ is still marked.
 assert.equal(tried(html),false);assert.doesNotMatch(html,/pc-band-trial|class="lad[^"]*try/);assert.match(html,/class="pc-star"[^>]*data-role="rec"/);
});

test('G3-87: pressing the LCD with a reported current opens the comparison without a trial',()=>{
 setLanguage('zh');
 const c=channel('Med');
 assert.equal(c.trial,null);assert.doesNotMatch(lcdView(c),/试/);
});

test('G3-87: moving the fader to another effort is a trial; moving it back onto the real cap ends it',()=>{
 setLanguage('zh');
 const moved=channel(null,{previews:{model0:'XHigh'},trial:'XHigh'});
 assert.equal(moved.trial.effort,'XHigh');assert.match(lcdView(moved),/试 XHigh/);
 const html=comparison(view,ui,{modelId:'model0',current:null,trial:'XHigh',currentFast:false});
 assert.equal(tried(html),true);assert.match(html,/pc-band-trial"[^>]*data-effort="XHigh"/);
 // Back on ★ (the real cap's position while current is unreported): no trial.
 const back=channel(null,{previews:{model0:'High'},trial:'High'});
 assert.equal(back.trial,null);assert.equal(back.ghostK,null);assert.doesNotMatch(lcdView(back),/试/);
 // With a reported current, ★ is still a trial (试 = ★) and current ends it.
 assert.equal(channel('Med',{previews:{model0:'High'},trial:'High'}).trial.matchesRec,true);
 assert.equal(channel('Med',{previews:{model0:'Med'},trial:'Med'}).trial,null);
});
