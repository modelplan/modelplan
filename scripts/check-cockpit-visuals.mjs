// SPDX-License-Identifier: MIT
// Verify the exact reserved visual inputs distributed by the cockpit bundle.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { lstatSync,readFileSync,readdirSync } from 'node:fs';
import { resolve,relative,sep } from 'node:path';
const license='LicenseRef-ModelPlan-Visuals-1.0';
const digest=b=>createHash('sha256').update(b).digest('hex');
export function verifyCockpitVisuals(root) {
 const base=resolve(root,'desktop/official-visuals');
 for(const part of ['desktop','desktop/official-visuals','desktop/official-visuals/cockpit'])assert.ok(!lstatSync(resolve(root,part)).isSymbolicLink(),'symlink in reserved visual root');
 const bytes=readFileSync(resolve(base,'cockpit/bundle-manifest.json'));
 const policy=JSON.parse(readFileSync(resolve(root,'source-policy.json'),'utf8'));
 assert.equal(digest(bytes),policy.reservedVisuals.cockpitManifestSha256,'cockpit manifest hash');
 const manifest=JSON.parse(bytes.toString('utf8'));
 assert.equal(manifest['SPDX-License-Identifier'],license);
 assert.equal(manifest.schemaVersion,1);
 assert.match(manifest.notice,/LicenseRef-ModelPlan-Visuals-1\.0.*VISUAL-LICENSE\.md/);
 assert.match(readFileSync(resolve(base,'LICENSE.md'),'utf8'),/LicenseRef-ModelPlan-Visuals-1\.0/);
 assert.ok(Array.isArray(manifest.files));
 const seen=new Set();
 for(const entry of manifest.files){
  assert.deepEqual(Object.keys(entry).sort(),['file','sha256']);
  const name=entry.file;
  assert.ok(typeof name==='string' && !name.includes('\\') && name.split('/').every(p=>p&&p!=='.'&&p!=='..'),'reserved visual outside official-visuals');
  assert.ok(!seen.has(name),'duplicate cockpit visual');seen.add(name);
  const file=resolve(base,name),rel=relative(base,file);
  assert.ok(rel&&!rel.startsWith('..'+sep)&&rel!=='..','reserved visual outside official-visuals');
  let current=base;for(const part of name.split('/')){current=resolve(current,part);assert.ok(!lstatSync(current).isSymbolicLink(),'symlink in reserved visual path');}
  assert.ok(lstatSync(file).isFile());assert.equal(digest(readFileSync(file)),entry.sha256,`cockpit visual hash: ${name}`);
 }
 const expected=new Set(['logo.svg','LICENSE.md','cockpit/study-strip.css','cockpit/cockpit.css','cockpit/SOURCES.md','cockpit/shell6.css']);
 const walk=(dir,prefix)=>{for(const e of readdirSync(resolve(base,dir),{withFileTypes:true})){const n=prefix+e.name;assert.ok(!e.isSymbolicLink());if(e.isDirectory())walk(dir+'/'+e.name,n+'/');else {assert.ok(e.isFile());expected.add(n);}}};
 walk('cockpit/study-strip','cockpit/study-strip/');walk('runtime','runtime/');
 assert.deepEqual([...seen].sort(),[...expected].sort(),'cockpit visual manifest must list every shipped reserved file');
 return manifest;
}
