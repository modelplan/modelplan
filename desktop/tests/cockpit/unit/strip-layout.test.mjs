// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const strip=read('../../../official-visuals/cockpit/strip/strip.css'),web=read('../../../cockpit/web/cockpit.css');
const frame=read('../../../cockpit/src/prototype-frame.ts');
// The study strip puts its keys on a 42 px pitch: Settings 460, detach 502, Close 544. The effective left of a key is the
// last rule with the highest specificity; the override carries one more type selector than the shared sheet.
const leftOf=(css,selector)=>{const m=css.match(new RegExp(selector.replace(/[[\]]/g,'\\$&')+'\\{left:(\\d+)px'));return m?Number(m[1]):null};
const effectiveLeft=attr=>leftOf(web,`.ck-head button[${attr}]`)??leftOf(strip,`.ck-head [${attr}]`);
test('the strip keys leave no empty slot where the detach key was',()=>{
  const keys=[...frame.matchAll(/<button[^>]*class="key[^"]*"[^>]*\sdata-(settings|close)\b/g)].map(m=>'data-'+m[1]);
  assert.deepEqual(keys,['data-settings','data-close'],'the header carries Settings then Close only');
  assert.ok(!frame.includes('data-detach'),'no detach key in the header');
  const lefts=keys.map(k=>effectiveLeft(k.slice(0)));
  assert.deepEqual(lefts,[502,544],'Settings sits in the former detach slot, adjacent to Close');
  assert.equal(lefts[1]-lefts[0],42,'the study pitch between neighbouring keys');
  assert.ok(!lefts.includes(460),'the slot next to the lamp is not left holding a key while the middle one is empty');
});
