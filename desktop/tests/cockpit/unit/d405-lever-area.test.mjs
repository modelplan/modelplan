// SPDX-License-Identifier: MIT
// D405 (owner 2026-11-24, direction 06): the effort names move from the scale column into the two gaps between the
// levers and are shown twice; the card's token count is set larger, so its line keeps the share only while both fit.
import test from 'node:test';
import assert from 'node:assert/strict';
import {faderModel,scaleView,lcdView,stripAria,levelK,LADDER} from '../../../cockpit/study/rocket-r1/fader-view.js';
import {setLanguage} from '../../../cockpit/study/rocket-r1/i18n.js';

globalThis.document??={documentElement:{}};
const e=LADDER.map((l,i)=>[l,40+i*3,.2*(i+1),60*(i+1)]);
const fader=(o={})=>({id:'m',name:'GPT-6.1 Sol',short:'Sol 6.1',rec:'Med',e,current:'High',currentFast:false,tier:null,live:true,pinned:false,others:{},accounts:['a'],sessions:[],...o});
const channel=f=>faderModel({faders:[f],accounts:[{id:'a',colour:'#6aa8ff'}]},{bank:0,bankSize:3,selModel:null,previews:{},view:null}).channels[0];

test('D405 the scale is two gap columns, each with every effort name, Low to Max, on its detent row',()=>{
 setLanguage('en');
 const html=scaleView(),cols=[...html.matchAll(/<span class="sc-travel" data-gap="(\d)">(.*?)<\/span>/g)];
 assert.deepEqual(cols.map(c=>c[1]),['1','2']);
 for(const [,,body] of cols){
  const levels=[...body.matchAll(/data-level="(\w+)"[^>]*style="--k:([\d.]+)"/g)].map(m=>[m[1],Number(m[2])]);
  assert.deepEqual(levels.map(l=>l[0]),LADDER);
  for(const [l,k] of levels)assert.equal(k,levelK(l));
 }
 assert.doesNotMatch(html,/sc-lcd/,'no empty LCD placeholder in the scale');
});

test('D405 the token count keeps its share on the line only while both fit the larger type',()=>{
 setLanguage('en');
 for(const [tokens,share,want] of [[212e6,.17,['212M','17%']],[1e3,1,['1k','100%']],[480e6,.81,['480M','81%']],[125e6,1,['125M']],[1000e9,1,['1000B']],[12.5e6,.05,['12.5M','5%']],[12.5e6,.45,['12.5M']]]){
  const c=channel(fader({use:{tokens,share}}));
  assert.deepEqual(c.card.use,want,`${tokens} ${share}`);
  // The share stays in the accessible name and on the bar.
  assert.match(stripAria(c),new RegExp(String(Math.round(share*100))+'%'));assert.equal(c.card.bar,share);
 }
});

test('D405 the token count is its own element on the card, the share beside it',()=>{
 setLanguage('en');
 const html=lcdView(channel(fader({use:{tokens:212e6,share:.17}})));
 assert.match(html,/<span class="cd-use"><b class="cd-tok">212M<\/b> <span class="cd-pct">17%<\/span><\/span>/);
 const solo=lcdView(channel(fader({use:{tokens:1000e9,share:1}})));
 assert.match(solo,/<span class="cd-use"><b class="cd-tok">1000B<\/b><\/span>/);
});
