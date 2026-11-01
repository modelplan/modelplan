// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync,readFileSync,writeFileSync,mkdtempSync,rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { verifyCockpitVisuals } from '../../../../scripts/check-cockpit-visuals.mjs';
const source=fileURLToPath(new URL('../../../official-visuals/',import.meta.url));
test('cockpit visual manifest rejects paths outside the reserved pack',()=>{
 const root=mkdtempSync(join(tmpdir(),'cockpit-visual-policy-'));
 try {
  const target=join(root,'desktop/official-visuals');cpSync(source,target,{recursive:true});
  cpSync(fileURLToPath(new URL('../../../../source-policy.json',import.meta.url)),join(root,'source-policy.json'));
  assert.doesNotThrow(()=>verifyCockpitVisuals(root));
  const file=join(target,'cockpit/bundle-manifest.json'),manifest=JSON.parse(readFileSync(file));
  manifest.files.push({file:'../other-reserved/asset.png',sha256:'0'.repeat(64)});writeFileSync(file,JSON.stringify(manifest));
  const policyFile=join(root,'source-policy.json'),policy=JSON.parse(readFileSync(policyFile));policy.reservedVisuals.cockpitManifestSha256=createHash('sha256').update(readFileSync(file)).digest('hex');writeFileSync(policyFile,JSON.stringify(policy));
  assert.throws(()=>verifyCockpitVisuals(root),/outside official-visuals/);
 } finally {rmSync(root,{recursive:true,force:true});}
});
