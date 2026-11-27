// SPDX-License-Identifier: MIT
// D468 (owner, 2026-11-26; overrides D459's "parked detached = short"): the flame state machine. The host drives it with
// ignite(true/false) and attach/detach; the page maps the two to full, ember or out. A launch burns full, then the flame is
// out for good while the cockpit stays parked and detached (no ember, no glow); a return burns full, then ember; attached
// at rest is ember. The page itself runs no timer, so "stays out after N seconds" means no input can bring a flame back.
import test from 'node:test';
import assert from 'node:assert/strict';
import {thrustState} from '../../../cockpit/.tmp/compiled/src/thrust.js';

test('D468 attached at rest is ember',()=>assert.equal(thrustState(false,true),'ember'));
test('D468 igniting is full thrust, attached or not',()=>{assert.equal(thrustState(true,false),'full');assert.equal(thrustState(true,true),'full');});

test('D468 detach: full, then out, and out for as long as it stays parked',()=>{
 const seen=[thrustState(false,true),thrustState(true,false),thrustState(false,false)];
 assert.deepEqual(seen,['ember','full','out']);
 // Parked for N seconds: the host sends nothing more (the page has no timers), so the state cannot change; every later
 // evaluation with the same inputs is still out, never short, never ember.
 for(let s=0;s<600;s++)assert.equal(thrustState(false,false),'out');
});

test('D468 return to the rack: full, then ember once docked',()=>{
 assert.deepEqual([thrustState(false,false),thrustState(true,false),thrustState(true,true),thrustState(false,true)],['out','full','full','ember']);
});

test('D468 a dragged cockpit follows the same inputs: detached and not igniting is out',()=>assert.equal(thrustState(false,false),'out'));
