// SPDX-License-Identifier: MIT
// COL-2.1-15: identity colours of the vendors whose logo is grey or white stay near their real brand colours.
// The palette is read through its production consumer (memberColour, which paints the engine key, the fader and the
// session lamp), not by calling a private table.
import test from 'node:test';
import assert from 'node:assert/strict';
import {memberColour,vendorPalette} from '../../../cockpit/.tmp/compiled/src/session-binding.js';
const colourOf=vendorKey=>memberColour({row:{vendorKey}});
test('COL-2.1-15 Cursor, Copilot and OpenCode carry their brand-near accents through memberColour',()=>{
 assert.equal(colourOf('cursor'),'#f79dcb');
 assert.equal(colourOf('copilot'),'#c08cff');
 assert.equal(colourOf('opencode'),'#b5d65a');
});
test('COL-2.1-15 every accent is a plain six-digit colour and distinct per vendor; unknown vendors stay neutral',()=>{
 const accents=Object.values(vendorPalette).map(v=>v.colour);
 for(const accent of accents)assert.match(accent,/^#[0-9a-f]{6}$/);
 assert.equal(new Set(accents).size,accents.length,'two vendors share one identity colour');
 assert.notEqual(colourOf(null),colourOf('cursor'));
 assert.equal(colourOf('no-such-vendor'),colourOf(null));
});
