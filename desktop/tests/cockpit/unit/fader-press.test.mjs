// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {isFaderLongPress} from '../../../cockpit/.tmp/compiled/src/fader-press.js';

test('fader hold uses the 520 ms release boundary and rejects invalid clocks',()=>{
 assert.equal(isFaderLongPress(1000,1519),false);
 assert.equal(isFaderLongPress(1000,1520),true);
 for(const [start,end] of [[20,19],[NaN,600],[0,Infinity],[-1,520]])assert.equal(isFaderLongPress(start,end),false);
});

test('glm-450-1/2 cancelled and competing pointers never commit or replace the active press',async()=>{
 const {beginFaderPress,endFaderPress}=await import('../../../cockpit/.tmp/compiled/src/fader-press.js');
 assert.equal(typeof beginFaderPress,'function');assert.equal(typeof endFaderPress,'function');
 const first={pointer:1,started:1000,sourceId:'model-a',pinned:false},other={pointer:2,started:1100,sourceId:'model-b',pinned:false};
 assert.deepEqual(beginFaderPress(null,first),first);assert.deepEqual(beginFaderPress(first,other),first);
 assert.deepEqual(endFaderPress(first,2,1600,'up'),{active:first,commit:null});
 assert.deepEqual(endFaderPress(first,1,1600,'cancel'),{active:null,commit:null});
 assert.deepEqual(endFaderPress(first,1,1600,'up'),{active:null,commit:first});
 assert.deepEqual(endFaderPress(first,1,1519,'up'),{active:null,commit:null});
});
