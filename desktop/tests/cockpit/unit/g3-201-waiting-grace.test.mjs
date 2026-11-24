// SPDX-License-Identifier: MIT
// G3-201 (owner row 42): opening the cockpit from the menu bar sometimes flashed the engine's "waiting" line. The page is
// un-hidden when its bridge is ready (CKP-SHELL-33: the rack comes out with whatever it has), a moment before the first
// display lands. The waiting and cleared lines now fade in only after a grace, so a display that arrives within it never
// shows them; the empty state (a real, lasting answer) is not delayed.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const css=read('../../../cockpit/web/cockpit.css'),view=read('../../../cockpit/src/view.ts');

test('the waiting and cleared lines carry a marker the stylesheet delays',()=>{
 assert.match(view,/root\.dataset\.engineWait=key==='empty'\?'':key/);
 const rule=css.match(/\[data-engine-wait\]:not\(\[data-engine-wait=""\]\) \.ck-eng \.ec-empty\{([^}]*)\}/);
 assert.ok(rule,'a delayed rule for the waiting line exists');
 assert.match(rule[1],/animation:[^;]*ec-wait-in/);
 assert.match(css,/@keyframes ec-wait-in\{from\{opacity:0\}to\{opacity:1\}\}/);
 assert.match(rule[1],/opacity:0/);
 assert.match(rule[1],/animation:[^;]*(\.[0-9]+|[0-9]+)s[^;]*(\.[0-9]+|[0-9]+)s[^;]*forwards/);
});
