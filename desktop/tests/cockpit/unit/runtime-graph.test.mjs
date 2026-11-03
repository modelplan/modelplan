// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyRuntimeGraph} from '../runtime-graph.mjs';

test('community import graph detects missing modules and traversal',()=>{
 const sources={
  'src/main.js':"import '../study/rocket-r1/engine-model.js'; import '../study/rocket-r1/strings/mfd.js';",
  'study/rocket-r1/engine-model.js':'export const engine = true;',
  'study/rocket-r1/strings/mfd.js':'export const strings = true;',
 };
 const manifest={files:Object.fromEntries(Object.keys(sources).map(name=>[name,'synthetic']))};
 const read=path=>sources[path.slice('/synthetic/'.length)];
 verifyRuntimeGraph('/synthetic/',manifest,read);
 const missing={files:{...manifest.files}};delete missing.files['study/rocket-r1/strings/mfd.js'];
 assert.throws(()=>verifyRuntimeGraph('/synthetic/',missing,read),/missing bundled module/);
 sources['src/main.js']="import '../../outside.js';";
 assert.throws(()=>verifyRuntimeGraph('/synthetic/',manifest,read),/import escapes bundle/);
});
