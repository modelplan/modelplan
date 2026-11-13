// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {posix} from 'node:path';

export function verifyRuntimeGraph(root,manifest,read=readFileSync){
 const seen=new Set(),pending=['src/main.js'];
 while(pending.length){
  const name=pending.pop();if(seen.has(name))continue;seen.add(name);
  assert.ok(Object.hasOwn(manifest.files,name),`missing bundled module ${name}`);
  const source=read(root+name,'utf8');
  for(const match of source.matchAll(/\b(?:import|export)\s+(?:[^'";]*?\s+from\s*)?['"](\.[^'"]+)['"]/g)){
   const next=posix.normalize(posix.join(posix.dirname(name),match[1]));
   assert.ok(next!=='..'&&!next.startsWith('../'),`import escapes bundle: ${name}`);
   pending.push(next);
  }
 }
 assert.ok(seen.has('study/rocket-r1/engine-model.js'));
 assert.ok(seen.has('study/rocket-r1/strings/mfd.js'));
}
