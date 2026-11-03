// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {dirname,normalize,posix} from 'node:path';
import {fileURLToPath} from 'node:url';

test('community bundle contains the complete relative JavaScript import graph',()=>{
 const root=fileURLToPath(new URL('../../../cockpit/.tmp/community/',import.meta.url));
 const manifest=JSON.parse(readFileSync(root+'bundle-manifest.json','utf8'));
 const seen=new Set(),pending=['src/main.js'];
 while(pending.length){
  const name=pending.pop();if(seen.has(name))continue;seen.add(name);
  assert.ok(Object.hasOwn(manifest.files,name),`missing bundled module ${name}`);
  const source=readFileSync(root+name,'utf8');
  for(const match of source.matchAll(/\b(?:import|export)\s+(?:[^'";]*?\s+from\s*)?['"](\.[^'"]+)['"]/g)){
   const next=posix.normalize(posix.join(dirname(name),match[1]));
   assert.equal(normalize(next).startsWith('..'),false,`import escapes bundle: ${name}`);
   pending.push(next);
  }
 }
 assert.ok(seen.has('study/rocket-r1/engine-model.js'));
 assert.ok(seen.has('study/rocket-r1/strings/mfd.js'));
});
