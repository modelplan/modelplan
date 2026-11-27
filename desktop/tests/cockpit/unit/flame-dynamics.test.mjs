// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {flameDynamics} from '../../../cockpit/.tmp/compiled/src/prototype-base.js';

// D454: per-nozzle flame timings stay inside the approved ranges for every possible nozzle index, and are deterministic.
test('per-nozzle flame dynamics stay in range for every index and repeat exactly',()=>{
 for(let j=0;j<64;j++){
  const v=Object.fromEntries(flameDynamics(j));
  assert.deepEqual(flameDynamics(j),flameDynamics(j));
  const fps=4/parseFloat(v['--fp']);assert.ok(fps>=8.3&&fps<=9.7,`fps ${j} ${fps}`);
  const fb=parseFloat(v['--fb']);assert.ok(fb>=1.3&&fb<=1.7,`breath ${j} ${fb}`);
  const fl=parseFloat(v['--fl']);assert.ok(fl>=.9&&fl<=1.3,`flicker ${j} ${fl}`);
 }
 for(const k of ['--fp','--fb','--fl','--fbo'])assert.equal(new Set([0,1,2,3].map(j=>Object.fromEntries(flameDynamics(j))[k])).size,4,k);
});
