// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {isFaderLongPress} from '../../../cockpit/.tmp/compiled/src/fader-press.js';

test('fader hold uses the 520 ms release boundary and rejects invalid clocks',()=>{
 assert.equal(isFaderLongPress(1000,1519),false);
 assert.equal(isFaderLongPress(1000,1520),true);
 for(const [start,end] of [[20,19],[NaN,600],[0,Infinity],[-1,520]])assert.equal(isFaderLongPress(start,end),false);
});
