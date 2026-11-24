// SPDX-License-Identifier: MIT
// G3-201 (owner row 42): the waiting and cleared lines show only after the page has been SHOWN for a grace. The behaviour is
// proved on the built page by browser/g3-201-waiting-grace.spec.mjs (quick and slow first display, prewarmed page, reduce
// motion); this guards the mechanism: the grace is a timer the view starts on visibility, never a CSS clock from install.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const css=read('../../../cockpit/web/cockpit.css'),view=read('../../../cockpit/src/view.ts');

test('the grace starts when the page is shown, and the stylesheet never runs its own clock',()=>{
 assert.match(view,/root\.dataset\.engineWait=key==='empty'\?'':key;armWait\(\)/);
 assert.match(view,/visible\(value\)\{plugins\.setVisible\(value\);if\(value!==pageShown\)\{pageShown=value;armWait\(\);\}\}/);
 assert.doesNotMatch(css,/ec-wait-in[^}]*\.7s/);
 assert.match(css,/:not\(\[data-wait-shown\]\) \.ck-eng \.ec-empty\{opacity:0\}/);
 assert.match(css,/html\[data-reduce-motion="true"\] \[data-wait-shown\] \.ck-eng \.ec-empty\{animation:none\}/);
 assert.match(css,/@media\(prefers-reduced-motion:reduce\)\{\[data-wait-shown\] \.ck-eng \.ec-empty\{animation:none\}\}/);
});
