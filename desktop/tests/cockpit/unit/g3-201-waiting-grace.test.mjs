// SPDX-License-Identifier: MIT
// G3-201 (owner row 42): the waiting and cleared lines show only after the page has been SHOWN for a grace. The behaviour is
// proved on the built page by browser/g3-201-waiting-grace.spec.mjs (quick and slow first display, prewarmed page, reduce
// motion); this guards the mechanism: the page owns no timers (bundle audit), so the grace is a CSS animation delay that exists only under
// data-wait-shown, which the view removes while hidden and sets again on every show and every new line; never a CSS clock from install.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const css=read('../../../cockpit/web/cockpit.css'),view=read('../../../cockpit/src/view.ts');

test('the grace starts when the page is shown, and the stylesheet never runs its own clock',()=>{
 assert.match(view,/root\.dataset\.engineWait=key==='empty'\?'':key;const now=key==='cleared'&&painted;painted=key==='empty';armWait\(now\)/);
 assert.match(view,/visible\(value\)\{plugins\.setVisible\(value\);if\(value!==pageShown\)\{pageShown=value;painted=false;armWait\(\);\}/);
 assert.doesNotMatch(view,/set(?:Timeout|Interval)\(|requestAnimationFrame\(/);
 assert.match(view,/const stopWait=\(\)=>\{delete root\.dataset\.waitShown;\};/);
 assert.match(view,/pageShown&&root\.dataset\.engineWait\)\{void root\.offsetWidth;root\.dataset\.waitShown=now\?'now':'true';\}/);
 assert.match(css,/\[data-engine-wait\]:not\(\[data-engine-wait=""\]\) \.ck-eng \.ec-empty\{opacity:0\}/);
 assert.match(css,/(?<!html\[data-reduce-motion="true"\] )\[data-wait-shown="true"\] \.ck-eng \.ec-empty\{animation:ec-wait-in \.15s \.7s forwards\}/);
 assert.doesNotMatch(css,/\.ck-eng \.ec-empty\{[^}]*animation:ec-wait-in[^}]*\}\s*(?=\n\[data-engine-wait\])/);
 assert.match(css,/html\[data-reduce-motion="true"\] \[data-wait-shown="true"\] \.ck-eng \.ec-empty\{animation-duration:1ms\}/);
 assert.match(css,/@media\(prefers-reduced-motion:reduce\)\{\[data-wait-shown="true"\] \.ck-eng \.ec-empty\{animation-duration:1ms\}\}/);
});
