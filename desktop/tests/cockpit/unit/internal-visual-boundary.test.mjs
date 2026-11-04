// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import * as boundary from '../../../cockpit/internal-visual-boundary.mjs';

test('default edition remains community and official requires its existing flag',()=>{
 assert.equal(boundary.selectBuildEdition([]),'community');
 assert.equal(boundary.selectBuildEdition(['--official']),'official');
 for(const args of [['--community'],['--official','--internal-acceptance'],['--unknown']])assert.throws(()=>boundary.selectBuildEdition(args),/Usage/);
});
test('internal integration has no resource reader and remains unavailable',()=>{
 assert.deepEqual(Object.keys(boundary),['selectBuildEdition']);
 assert.throws(()=>boundary.selectBuildEdition(['--internal-acceptance']),/reviewed helper, pins and resource mapping are not integrated/);
 const build=fileURLToPath(new URL('../../../cockpit/build.mjs',import.meta.url));
 assert.throws(()=>execFileSync(process.execPath,[build,'--internal-acceptance'],{stdio:'pipe'}),error=>/reviewed helper, pins and resource mapping are not integrated/.test(error.stderr.toString()));
});
