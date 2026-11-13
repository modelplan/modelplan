// SPDX-License-Identifier: MIT
// D131 / COL-2.1-18: the app's copy of the shared maker colour table, its alternate shades and the collision rule.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fieldModel} from '../../../cockpit/.tmp/compiled/src/field-model.js';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {MAKERS,TOOLS} from '../../../cockpit/.tmp/compiled/src/livery-table.js';
import {rocketColour,brandColour,resolveColours,deltaE,COLLISION_DELTA_E,NEUTRAL} from '../../../cockpit/.tmp/compiled/src/livery.js';
const cockpit=fileURLToPath(new URL('../../../cockpit/',import.meta.url));
const lum=hex=>{const [r,g,b]=[1,3,5].map(i=>{const c=parseInt(hex.slice(i,i+2),16)/255;return c<=0.03928?c/12.92:((c+0.055)/1.055)**2.4;});return 0.2126*r+0.7152*g+0.0722*b;};
const ratio=(a,b)=>{const [x,y]=[lum(a),lum(b)].sort((p,q)=>q-p);return (x+0.05)/(y+0.05);};

test('COL-2.1-18 D250 (owner 11-13, supersedes D211 Set 1): the old pastel palette, completed, for UI accents',()=>{
 const want={openai:'#6aa8ff',anthropic:'#ff9a6a',zhipuai:'#8f7dff',kimi:'#ff8fcf',xai:'#8594a4',google:'#4eccd3',minimax:'#f16f7e',meta:'#a6dcff',alibaba:'#4ab89a',deepseek:'#00aad6',xiaomi:'#e89700'};
 for(const [k,c] of Object.entries(want))assert.equal(MAKERS[k].colour,c,k);
 assert.deepEqual([TOOLS.cursor.colour,TOOLS.copilot.colour,TOOLS.opencode.colour],['#eef2f6','#c08cff','#b5d65a']);
 assert.deepEqual([brandColour('openai'),brandColour('glm'),brandColour('xai'),brandColour('cursor'),brandColour('claude')],['#6aa8ff','#8f7dff','#8594a4','#eef2f6','#ff9a6a']);
 assert.equal(brandColour('no-such-vendor'),NEUTRAL);
 const text=readFileSync(new URL('../../../cockpit/src/livery-table.ts',import.meta.url),'utf8').replace(/,rocket:'#[0-9a-f]{6}'/g,''); // the website colour survives only as `rocket`
 for(const old of ['#10a37f','#3859ff','#f5e642','#f79dcb','#d97757','#8dabfd','#978c0d','#ececec','#b9c2cc','#8f96a0'])assert.ok(!text.includes(old),'old colour '+old);
});
test('COL-2.1-18 D250 alternates: same tone, clearly darker; Cursor takes a mid grey; collisions use them',()=>{
 const alts={openai:'#1352a1',anthropic:'#a0440a',zhipuai:'#4422a0',kimi:'#a03878',xai:'#374452',google:'#0b7176',minimax:'#900d30',meta:'#5084a4',alibaba:'#025e4b',deepseek:'#0e5166',xiaomi:'#794e08'};
 for(const [k,c] of Object.entries(alts)){assert.equal(MAKERS[k].alt,c,k);assert.ok(lum(c)<lum(MAKERS[k].colour),k+' alt is darker');}
 assert.equal(TOOLS.cursor.alt,'#6f7782');assert.equal(TOOLS.cursor.altFrom,'app');assert.ok(ratio('#6f7782','#ffffff')>=3.5,'Cursor alt reads on light backgrounds');
 assert.ok(deltaE('#8f7dff','#c08cff')<COLLISION_DELTA_E&&deltaE('#8594a4','#c08cff')<COLLISION_DELTA_E);
 assert.deepEqual(resolveColours(['copilot','glm']),['#c08cff','#4422a0']);
 assert.deepEqual(resolveColours(['glm','xai']),['#8f7dff','#374452']);
 assert.deepEqual(resolveColours(['kimi','glm']),['#ff8fcf','#8f7dff']);
 assert.deepEqual(resolveColours(['openai','glm','cursor','claude']),['#6aa8ff','#8f7dff','#eef2f6','#ff9a6a']);
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
 assert.ok(deltaE('#ff9a6a','#ff8fcf')>COLLISION_DELTA_E);
 assert.deepEqual(resolveColours(['claude','kimi']),['#ff9a6a','#ff8fcf']);
 assert.deepEqual(resolveColours(['glm']),['#8f7dff']);
 assert.deepEqual(resolveColours(['kimi','glm']),resolveColours(['kimi','glm']));
 // The same vendor twice (two accounts) shares one colour; unknown vendors stay neutral and do not collide.
 assert.deepEqual(resolveColours(['claude','claude',null,'claude']),['#ff9a6a','#ff9a6a',NEUTRAL,'#ff9a6a']);
});
test('COL-2.1-18 contrast: every colour reads on the night metal (3:1); on the day metal the dark alternate does',()=>{
 const night='#1c1d1f',day='#b7bcc1';
 for(const [key,s] of Object.entries({...MAKERS,...TOOLS})){
  assert.ok(ratio(s.colour,night)>=3,key+' brand colour on night: '+ratio(s.colour,night).toFixed(2));
  assert.ok(ratio(s.alt,night)>=2.5||ratio(s.alt,day)>=1.8,key+' alternate readable on one theme');
 }
});
test('COL-2.1-18 day rule: 40% of each D250 colour toward black keeps every mark >= 3.4:1 on the day metal (Cursor starts from its grey alt)',()=>{
 const day='#b7bcc1',mix=h=>'#'+[1,3,5].map(i=>Math.round(parseInt(h.slice(i,i+2),16)*0.4).toString(16).padStart(2,'0')).join('');
 const expected={'#6aa8ff':'#2a4366','#8f7dff':'#393266','#8594a4':'#353b42','#6f7782':'#2c3034','#ff9a6a':'#663e2a','#4422a0':'#1b0e40','#374452':'#161b21'};
 const css=readFileSync(new URL('../../../cockpit/prototype/prototype-theme.css',import.meta.url),'utf8');assert.ok(css.includes('.mg:not(.orig)[style*="#eef2f6" i]')&&css.includes('color-mix(in srgb,#6f7782 40%,#000)'),'day CSS maps Cursor to its alt');
 for(const [c,d] of Object.entries(expected)){assert.equal(mix(c),d);assert.ok(ratio(d,day)>=3.4,c+' day '+ratio(d,day).toFixed(2));}
});
test('COL-2.1-18 owner 11-12: D250 palette is UI accents only; rockets keep the website livery, the shared copy stays verbatim',()=>{
 const shared=JSON.parse(readFileSync(new URL('../../../cockpit/src/livery-shared.json',import.meta.url),'utf8')).makers;
 assert.equal(shared.openai.colour,'#ececec');assert.equal(shared.zhipuai.colour,'#b9c2cc');assert.equal(shared.xai.colour,'#8f96a0');
 assert.ok(!('alt' in shared.zhipuai)&&!('alt' in shared.xai),'the vendored copy carries no app-only alternates');
 assert.deepEqual([rocketColour('openai'),rocketColour('glm'),rocketColour('xai')],['#ececec','#b9c2cc','#8f96a0']);
 assert.deepEqual([brandColour('openai'),brandColour('glm'),brandColour('xai')],['#6aa8ff','#8f7dff','#8594a4']);
 assert.deepEqual([rocketColour('claude'),rocketColour('kimi'),rocketColour('cursor')],['#d97757','#007cff','#f79dcb']);
  // The launch-field scene paints rockets: its developer colours are the rocket colours, not the UI accents.
 const m=dev=>fieldModel({id:'a',name:'Synthetic',developerId:dev,recommended:'medium',efforts:[{effort:'medium',label:'Med',star:true,ability:40,cost:.2,time:30}]});
 assert.equal(m('openai').colour,'#ececec');assert.equal(m('zhipuai').colour,'#b9c2cc');assert.equal(m('anthropic').colour,'#d97757');
 const field=readFileSync(new URL('../../../cockpit/src/field-model.ts',import.meta.url),'utf8');
 assert.ok(!/brandColour\(/.test(field),'field-model must not take UI accents');
});
