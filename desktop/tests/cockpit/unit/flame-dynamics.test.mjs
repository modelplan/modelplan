// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {flameDynamics} from '../../../cockpit/.tmp/compiled/src/prototype-base.js';

const dyn=j=>Object.fromEntries(flameDynamics(j));
const sec=v=>parseFloat(v);

// D454/D468: per-nozzle flame timings stay inside the approved ranges for every possible nozzle index, and are deterministic.
test('per-nozzle flame dynamics stay in range for every index and repeat exactly',()=>{
 for(let j=0;j<64;j++){
  const v=dyn(j);
  assert.deepEqual(flameDynamics(j),flameDynamics(j));
  const fps=4/sec(v['--fp']);assert.ok(fps>=6.99&&fps<=11.01,`fps ${j} ${fps}`);
  const fb=sec(v['--fb']);assert.ok(fb>=1.09&&fb<=1.91,`breath ${j} ${fb}`);
  const fl=sec(v['--fl']);assert.ok(fl>=.9&&fl<=1.3,`flicker ${j} ${fl}`);
  const fmin=sec(v['--fmin']);assert.ok(fmin>=.8&&fmin<=.95,`floor ${j} ${fmin}`);
  const lag=-sec(v['--fo']);assert.ok(lag>=0&&lag<sec(v['--fp']),`phase ${j} ${lag}`);
 }
});

// The first four nozzles must read as four different flames: spread frame rates, breath periods and start frames.
test('the four nozzles differ visibly: frame rate, breath period and starting frame',()=>{
 const v=[0,1,2,3].map(dyn);
 for(const k of ['--fp','--fb','--fl','--fbo','--fo','--fmin'])assert.equal(new Set(v.map(x=>x[k])).size,4,k);
 const fps=v.map(x=>4/sec(x['--fp'])),fb=v.map(x=>sec(x['--fb']));
 assert.ok(Math.max(...fps)-Math.min(...fps)>=3,`fps spread ${fps}`);
 assert.ok(Math.max(...fb)-Math.min(...fb)>=.6,`breath spread ${fb}`);
 // Start offsets as a share of each loop: 0, 1/3, 2/3, 1/2.
 const share=v.map(x=>-sec(x['--fo'])/sec(x['--fp']));
 [0,1/3,2/3,1/2].forEach((e,i)=>assert.ok(Math.abs(share[i]-e)<.01,`phase ${i} ${share[i]}`));
});
