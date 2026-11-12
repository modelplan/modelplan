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

test('COL-2.1-18 the vendored copy is the shared table: real brand colours, GLM is the light neutral, not purple or green',()=>{
 assert.equal(MAKERS.zhipuai.colour,'#b9c2cc');assert.equal(MAKERS.openai.colour,'#ececec');assert.equal(MAKERS.anthropic.colour,'#d97757');
 assert.equal(brandColour('glm'),'#b9c2cc');assert.equal(brandColour('claude'),'#d97757');assert.equal(brandColour('openai'),'#ececec');
 assert.equal(brandColour('no-such-vendor'),NEUTRAL);
});
test('COL-2.1-18 no cockpit source hard-codes the old per-vendor colours',()=>{
 for(const file of ['field-model','prototype-engine','session-binding','prototype-deck','prototype-tape']){
  const text=readFileSync(new URL('../../../cockpit/src/'+file+'.ts',import.meta.url),'utf8');
  for(const old of ['#6aa8ff','#ff9a6a','#8f7dff','#63d69c','#c08cff','#eef2f6','#b5d65a'])assert.ok(!text.includes(old),file+' still names '+old);
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
 assert.ok(deltaE('#ececec','#b9c2cc')<COLLISION_DELTA_E&&deltaE('#ececec','#eef2f6')<COLLISION_DELTA_E);
 assert.ok(deltaE('#d97757','#007cff')>COLLISION_DELTA_E);
 assert.deepEqual(resolveColours(['claude','kimi']),['#d97757','#007cff']);
 assert.deepEqual(resolveColours(['glm']),['#b9c2cc']);
 const [a,b]=resolveColours(['openai','glm']);assert.equal(a,'#ececec');assert.equal(b,MAKERS.zhipuai.alt);
 const [c,d]=resolveColours(['glm','openai']);assert.equal(c,'#b9c2cc');assert.equal(d,MAKERS.openai.alt);
 assert.deepEqual(resolveColours(['openai','glm']),resolveColours(['openai','glm']));
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
