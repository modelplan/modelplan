// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {formatCredits} from '../../../cockpit/study/rocket-r1/i18n.js';
import {tok} from '../../../cockpit/study/rocket-r1/mfd-pages/fmt.js';

test('credit balances retain their numeric precision rules in each supported locale',()=>{
 for(const locale of ['en','zh-CN'])for(const [value,expected] of [[19613.957,'19,614'],[1000000,'1,000,000'],[0.001,'<1'],[0.999,'<1'],[0,'0'],[1,'1'],[999.6,'1,000'],[null,'--']])assert.equal(formatCredits(value,locale),expected);
 assert.equal(tok(19613.957),'20k');
});
