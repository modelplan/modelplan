// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {leaderAnchor,routeLeader,segmentClear} from '../../../cockpit/study/rocket-r1/help-routing.js';
test('help leaders route around live reading rectangles',()=>{
 const viewport={width:500,height:500},blocks=[{x:180,y:150,width:100,height:100}],start={x:100,y:200},end={x:350,y:200};
 const points=routeLeader(start,end,blocks,viewport);assert.deepEqual(points[0],start);assert.deepEqual(points.at(-1),end);assert.ok(points.length>2);
 for(let i=1;i<points.length;i++)assert.ok(segmentClear(points[i-1],points[i],blocks));
 const target={x:300,y:100,width:40,height:40};assert.ok(leaderAnchor(target,{x:296,y:120},blocks,viewport));
});
