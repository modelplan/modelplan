// SPDX-License-Identifier: MIT
// D131 / COL-2.1-18: the app's copy of the shared maker colour table, its alternate shades and the collision rule.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {MAKERS,TOOLS} from '../../../cockpit/.tmp/compiled/src/livery-table.js';
import {brandColour,resolveColours,deltaE,COLLISION_DELTA_E,NEUTRAL} from '../../../cockpit/.tmp/compiled/src/livery.js';
const cockpit=fileURLToPath(new URL('../../../cockpit/',import.meta.url));
const lum=hex=>{const [r,g,b]=[1,3,5].map(i=>{const c=parseInt(hex.slice(i,i+2),16)/255;return c<=0.03928?c/12.92:((c+0.055)/1.055)**2.4;});return 0.2126*r+0.7152*g+0.0722*b;};
const ratio=(a,b)=>{const [x,y]=[lum(a),lum(b)].sort((p,q)=>q-p);return (x+0.05)/(y+0.05);};

test('COL-2.1-18 Set 1 (owner 11-12): ChatGPT green, Zhipu blue, assigned yellow and rose; Claude orange; no near-white or grey',()=>{
 assert.equal(MAKERS.openai.colour,'#10a37f');assert.equal(MAKERS.zhipuai.colour,'#3859ff');assert.equal(MAKERS.xai.colour,'#f5e642');assert.equal(TOOLS.cursor.colour,'#f79dcb');assert.equal(MAKERS.anthropic.colour,'#d97757');
 assert.equal(brandColour('openai'),'#10a37f');assert.equal(brandColour('glm'),'#3859ff');assert.equal(brandColour('xai'),'#f5e642');assert.equal(brandColour('cursor'),'#f79dcb');assert.equal(brandColour('claude'),'#d97757');
 assert.equal(brandColour('no-such-vendor'),NEUTRAL);
 const text=readFileSync(new URL('../../../cockpit/src/livery-table.ts',import.meta.url),'utf8');
 for(const old of ['#ececec','#b9c2cc','#656d76','#8f96a0','#eef2f6'])assert.ok(!text.includes(old),'old colour '+old);
});
test('COL-2.1-18 Set 1 collision fallbacks: GLM next to Kimi takes #8dabfd, xAI next to OpenCode takes #978c0d; the four do not collide with each other',()=>{
 assert.equal(MAKERS.zhipuai.alt,'#8dabfd');assert.equal(MAKERS.xai.alt,'#978c0d');
 assert.ok(deltaE('#3859ff','#007cff')<COLLISION_DELTA_E&&deltaE('#f5e642','#b5d65a')<COLLISION_DELTA_E);
 assert.deepEqual(resolveColours(['kimi','glm']),['#007cff','#8dabfd']);
 assert.deepEqual(resolveColours(['opencode','xai']),['#b5d65a','#978c0d']);
 assert.deepEqual(resolveColours(['glm','xai']),['#3859ff','#f5e642']);
 const four=resolveColours(['openai','glm','xai','cursor','claude']);assert.deepEqual(four,['#10a37f','#3859ff','#f5e642','#f79dcb','#d97757']);
});
test('COL-2.1-18 no cockpit source hard-codes the old per-vendor colours',()=>{
 for(const file of ['field-model','prototype-engine','session-binding','prototype-deck','prototype-tape']){
  const text=readFileSync(new URL('../../../cockpit/src/'+file+'.ts',import.meta.url),'utf8');
  for(const old of ['#6aa8ff','#ff9a6a','#8f7dff','#63d69c','#c08cff','#eef2f6','#b5d65a','#ececec','#b9c2cc'])assert.ok(!text.includes(old),file+' still names '+old);
 }
});
test('COL-2.1-18 drift check: the generated table matches its vendored copy of the shared table',()=>{
 execFileSync(process.execPath,[cockpit+'sync-livery.mjs','--check'],{stdio:'pipe'});
});
test('COL-2.1-18 every maker has a six-digit colour and one alternate shade that is not the colour',()=>{
 for(const [key,s] of Object.entries({...MAKERS,...TOOLS})){
  assert.match(s.colour,/^#[0-9a-f]{6}$/,key);assert.match(s.alt,/^#[0-9a-f]{6}$/,key);
  assert.ok(deltaE(s.colour,s.alt)>=COLLISION_DELTA_E,key+': the alternate must be told apart from the colour');
 }
});
test('COL-2.1-18 collision rule: only close makers in the same view; the later one takes its alternate; deterministic',()=>{
 assert.ok(deltaE('#d97757','#007cff')>COLLISION_DELTA_E);
 assert.deepEqual(resolveColours(['claude','kimi']),['#d97757','#007cff']);
 assert.deepEqual(resolveColours(['glm']),['#3859ff']);
 assert.deepEqual(resolveColours(['kimi','glm']),resolveColours(['kimi','glm']));
 // The same vendor twice (two accounts) shares one colour; unknown vendors stay neutral and do not collide.
 assert.deepEqual(resolveColours(['claude','claude',null,'claude']),['#d97757','#d97757',NEUTRAL,'#d97757']);
});
test('COL-2.1-18 contrast: every colour reads on the night metal (3:1); on the day metal the dark alternate does',()=>{
 const night='#1c1d1f',day='#b7bcc1';
 for(const [key,s] of Object.entries({...MAKERS,...TOOLS})){
  assert.ok(ratio(s.colour,night)>=3,key+' brand colour on night: '+ratio(s.colour,night).toFixed(2));
  assert.ok(ratio(s.alt,night)>=2.5||ratio(s.alt,day)>=1.8,key+' alternate readable on one theme');
 }
});
test('COL-2.1-18 day rule: 40% of each Set 1 colour toward black keeps every mark >= 3.4:1 on the day metal',()=>{
 const day='#b7bcc1',mix=h=>'#'+[1,3,5].map(i=>Math.round(parseInt(h.slice(i,i+2),16)*0.4).toString(16).padStart(2,'0')).join('');
 const expected={'#10a37f':'#064133','#3859ff':'#162466','#f5e642':'#625c1a','#f79dcb':'#633f51','#8dabfd':'#384465','#978c0d':'#3c3805'};
 for(const [c,d] of Object.entries(expected)){assert.equal(mix(c),d);assert.ok(ratio(d,day)>=3.4,c+' day '+ratio(d,day).toFixed(2));}
});
