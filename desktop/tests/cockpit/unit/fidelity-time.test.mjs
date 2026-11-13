// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {dhm,relativeMoment} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';

test('prototype compact duration rounds with its exact m/h/d forms',()=>{
 for(const [minutes,text] of [[0,'0m'],[1.6,'2m'],[59.6,'60m'],[60,'1h00'],[138,'2h18'],[1440,'1d0h'],[3060,'2d3h']])assert.equal(dhm(minutes),text);
});
test('prototype relative time uses the supplied clock and keeps past and future distinct',()=>{
 const now=Date.parse('2026-11-03T12:00:00Z');
 for(const [delta,en,zh] of [[29000,'now','现在'],[90000,'in 2m','2m后'],[-90000,'2m ago','2m前'],[8280000,'in 2h18','2h18后'],[-90000000,'1d1h ago','1d1h前']]){
  assert.equal(relativeMoment(now+delta,{now,lang:'en'}),en);
  assert.equal(relativeMoment(now+delta,{now,lang:'zh-CN'}),zh);
 }
});
