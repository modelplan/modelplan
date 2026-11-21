// SPDX-License-Identifier: MIT
// G3-124: the ALERT lamp blinks exactly three times, then stays steadily lit; reduced motion never blinks.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
test('G3-124 the lamp blink is three iterations in the cockpit (the hash-pinned strip livery is overridden)',()=>{
 const cockpit=read('../../../cockpit/web/cockpit.css');
 assert.match(cockpit,/\.caution\.flash\{animation:cockpit-caution-blink 1s steps\(1,end\) 3!important\}/);
});
test('G3-124 reduced motion switches the blink off',()=>{
 const strip=read('../../../official-visuals/cockpit/strip/strip.css');
 assert.match(strip,/body\.reduced \.ck-head \.caution\.flash\{animation:none\}/);
 assert.match(strip,/prefers-reduced-motion:reduce\)\{\.ck-head \.caution\.flash\{animation:none\}/);
});
