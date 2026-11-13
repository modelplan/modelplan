// SPDX-License-Identifier: MIT
// SET-9-38: every user-visible cockpit string lives in the string tables, in both languages, and nothing in the page code
// chooses between languages inline. The pseudo-long locale (tests only) pads English by about 40 %.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readdirSync,readFileSync} from 'node:fs';
import {checkBudgets,tables} from '../../../cockpit/study/rocket-r1/i18n.js';
import '../../../cockpit/study/rocket-r1/strings/host.js';
import {pseudoLong} from '../pseudo-long.mjs';

const root=new URL('../../../cockpit/',import.meta.url);
const files=(dir,pick)=>readdirSync(new URL(dir,root),{recursive:true}).filter(pick).map(f=>[dir+f,readFileSync(new URL(dir+f,root),'utf8')]);
const code=text=>text.replace(/\/\*[\s\S]*?\*\//g,'').split('\n').filter(l=>!/^\s*\/\//.test(l)).map(l=>l.replace(/\s\/\/\s.*$/,'')).join('\n');
const cjk=/[一-鿿]/;
// Page code: src/*.ts and the study modules outside strings/ (i18n.js and views.js only carry CJK ranges in a regexp).
const pageCode=[...files('src/',f=>f.endsWith('.ts')&&!f.endsWith('.d.ts')),
 ...files('study/rocket-r1/',f=>f.endsWith('.js')&&!f.startsWith('strings')&&f!=='i18n.js')];

test('no page code chooses a language inline: no locale ternary, no CJK literal outside the string tables',()=>{
 const found=[];
 for(const [name,text] of pageCode){
  for(const [i,line] of code(text).split('\n').entries()){
   const regexpOnly=/\.test\(ch\)/.test(line);
   if(!regexpOnly&&cjk.test(line))found.push(`${name}:${i+1} CJK literal`);
   // `locale==='en'?'en':'zh-CN'` picks a locale code, not text; any other branch value is a string for a table.
   const localeCodes=new Set(['en','zh','zh-CN']);
   for(const m of line.matchAll(/(?:\blocale|\bui\.lang|\blang)\s*===?\s*'(?:en|zh-CN)'\s*\?\s*(['`])([^'`]*)\1\s*:\s*(['`])([^'`]*)\3/g))if(!localeCodes.has(m[2])||!localeCodes.has(m[4]))found.push(`${name}:${i+1} inline language ternary`);
  }
 }
 assert.deepEqual(found,[]);
});

const hostKeys=Object.keys(tables.en).filter(k=>k.startsWith('host.'));
test('every host string exists in both languages with the same variables and fits its length class',()=>{
 assert.ok(hostKeys.length>=60,'the page strings moved into the tables');
 const vars=v=>(typeof v==='object'?Object.values(v):[v]).flatMap(s=>s.match(/\{\w+\}/g)??[]).sort().filter((x,i,a)=>x!==a[i-1]).join();
 for(const key of hostKeys){
  assert.ok(tables['zh-CN'][key],key+' has no zh-CN');
  assert.equal(vars(tables.en[key]),vars(tables['zh-CN'][key]),key+' variables differ between languages');
 }
 assert.deepEqual(checkBudgets().filter(x=>x.key.startsWith('host.')),[]);
});

test('the pseudo-long locale pads English by about 40 % and keeps {vars} and plural forms',()=>{
 for(const key of hostKeys){
  const en=tables.en[key],long=pseudoLong(en);
  for(const [a,b] of typeof en==='object'?Object.keys(en).map(k=>[en[k],long[k]]):[[en,long]]){
   const plain=s=>s.replace(/\{\w+\}/g,'xxx');
   assert.ok(plain(b).length>=Math.ceil(plain(a).length*1.4),`${key}: ${a} -> ${b}`);
   assert.deepEqual(a.match(/\{\w+\}/g),b.match(/\{\w+\}/g),key);
   assert.ok(b.startsWith(a),key);
  }
 }
 assert.equal(pseudoLong('{n} more running'),'{n} more runningmorerun');
 assert.equal(pseudoLong('…'),'…');
});
