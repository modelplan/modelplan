// SPDX-License-Identifier: MIT
// G3-202 (owner row 38): the tall porthole HUD's vertical axis ran 6 px from the top of its chart, too tall for the curved
// glass, and touched the porthole's inner rim. The axis now starts 5 px lower in the tall chart; the compact strip is unchanged.
import test from 'node:test';
import assert from 'node:assert/strict';
import {hudAxisPath} from '../../../cockpit/.tmp/compiled/src/hud-axis.js';

test('the tall chart axis starts 11 px from the top and ends where it did',()=>{
 assert.equal(hudAxisPath(162,77,8,9,6,12),'M8 11V65H153');
});
test('the compact strip keeps its axis',()=>{
 assert.equal(hudAxisPath(86,30,8,9,6,12),'M8 6V18H77');
});
