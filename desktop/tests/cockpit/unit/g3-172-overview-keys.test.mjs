// SPDX-License-Identifier: MIT
// G3-172: the Overview's chart key states follow the chart mode (Bars, or the day-by-hour Grid, D390).
import test from 'node:test';
import assert from 'node:assert/strict';
import {overview} from '../../../cockpit/study/rocket-r1/mfd-pages/overview.js';

const state=ui=>{const k=overview.optionKeys({range:'7d',lang:'en',...ui})[0];return [k.a.on,k.b.on];};
test('G3-172 the chart key lights the active mode',()=>{
 assert.deepEqual(state({chart:'bars'}),[true,false]);
 assert.deepEqual(state({chart:'grid'}),[false,true]);
 assert.deepEqual(state({}),[true,false]);
});
