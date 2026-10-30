// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { verifyPortholePack } from '../check-porthole-pack.mjs';
import { verifyVisualPack } from '../check-visual-pack.mjs';
const root = fileURLToPath(new URL('../..', import.meta.url));
const pack = 'desktop/official-visuals/runtime/porthole-stills';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture(t) {
  mkdirSync(join(root, '.tmp'), { recursive: true });
  const dir = mkdtempSync(join(root, '.tmp/porthole-check-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  cpSync(join(root, pack), join(dir, pack), { recursive: true });
  cpSync(join(root, 'source-policy.json'), join(dir, 'source-policy.json'));
  const directory = join(dir, pack), path = join(directory, 'manifest.json');
  const manifest = JSON.parse(readFileSync(path, 'utf8'));
  const policy = JSON.parse(readFileSync(join(dir, 'source-policy.json'), 'utf8'));
  function save() { writeFileSync(path, JSON.stringify(manifest)); writeFileSync(join(dir, 'source-policy.json'), JSON.stringify(policy)); }
  function replacePng(entry, bytes) {
    writeFileSync(join(directory, entry.file), bytes); entry.sha256 = hash(bytes); entry.bytes = bytes.length;
    manifest.pngBytes = manifest.files.reduce((n, f) => n + f.bytes, 0);
    policy.reservedVisuals.binaries[pack + '/' + entry.file] = entry.sha256;
    const checksums = '# SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0\n' + [...manifest.files].sort((a,b) => a.file < b.file ? -1 : 1).map(f => `${f.sha256}  ${f.file}\n`).join('');
    writeFileSync(join(directory, 'SHA256SUMS'), checksums); save();
  }
  return { dir, directory, path, manifest, policy, save, replacePng };
}
test('checks all 980 stills, both scales, runtime layers and default still through the official root checker', () => {
  assert.equal(verifyPortholePack(root).pngCount, 980);
  assert.equal(verifyPortholePack(root).pngBytes, 3441609);
  assert.equal(verifyVisualPack(root).pngCount, 1014);
});
test('rejects drifted PNG bytes and mismatched dimensions', t => {
  const f = fixture(t), entry = f.manifest.files[0], path = join(f.directory, entry.file), original = readFileSync(path);
  writeFileSync(path, Buffer.concat([original, Buffer.from('changed')]));
  assert.throws(() => verifyPortholePack(f.dir), /size|hash/);
  writeFileSync(path, original); entry.size.width++; f.save();
  assert.throws(() => verifyPortholePack(f.dir), /dimensions/);
});
test('rejects extra images and unlisted empty directories', t => {
  const f = fixture(t); writeFileSync(join(f.directory, 'assets/unlisted.png'), readFileSync(join(f.directory, f.manifest.files[0].file)));
  assert.throws(() => verifyPortholePack(f.dir), /outside porthole manifest/);
  rmSync(join(f.directory, 'assets/unlisted.png')); mkdirSync(join(f.directory, 'controls'));
  assert.throws(() => verifyPortholePack(f.dir), /directory outside manifest/);
});
test('rejects checksum drift, policy registry drift and missing reserved licence', t => {
  const f = fixture(t), sums = join(f.directory, 'SHA256SUMS'), original = readFileSync(sums);
  writeFileSync(sums, original.toString().replace(/[a-f0-9]{64}/, '0'.repeat(64)));
  assert.throws(() => verifyPortholePack(f.dir), /checksums/);
  writeFileSync(sums, original); const key = pack + '/' + f.manifest.files[0].file;
  f.policy.reservedVisuals.binaries[key] = '0'.repeat(64); f.save();
  assert.throws(() => verifyPortholePack(f.dir), /registry/);
  f.policy.reservedVisuals.binaries[key] = f.manifest.files[0].sha256; f.manifest.files[0].license = 'MIT'; f.save();
  assert.throws(() => verifyPortholePack(f.dir));
});
test('rejects private provenance fields, escaped paths and nested render metadata', t => {
  const f = fixture(t); f.manifest.provenance = 'unapproved'; f.save();
  assert.throws(() => verifyPortholePack(f.dir), /field/); delete f.manifest.provenance;
  f.manifest.copyright += ' /mnt/shared/not-public'; f.save();
  writeFileSync(f.path, readFileSync(f.path, 'utf8').replace('/mnt/shared', '/mnt\\u002fshared'));
  assert.throws(() => verifyPortholePack(f.dir), /private/);
  f.manifest.copyright = 'Copyright (c) 2026 ModelPlan. All rights reserved.';
  f.manifest.projections[0].models[0].world = [0, 0, 0]; f.save();
  assert.throws(() => verifyPortholePack(f.dir), /field/);
});
test('rejects missing runtime references, changed crop geometry and an absent default still', t => {
  const f = fixture(t), layer = f.manifest.projections[0].models[0].body, file = layer.file;
  layer.file = 'assets/missing.png'; f.save(); assert.throws(() => verifyPortholePack(f.dir));
  layer.file = file; layer.width++; f.save(); assert.throws(() => verifyPortholePack(f.dir), /layer dimensions/);
  layer.width--; f.manifest.defaultProjectionId = '000000000000'; f.save(); assert.throws(() => verifyPortholePack(f.dir));
});
test('rejects symlinked images and directories', t => {
  const f = fixture(t), file = f.manifest.files[0].file; rmSync(join(f.directory, file));
  symlinkSync(join(root, pack, file), join(f.directory, file));
  assert.throws(() => verifyPortholePack(f.dir), /linked|symlink/);
});
test('rejects compressed PNG metadata even after all hash records are updated', t => {
  const f = fixture(t), entry = f.manifest.files[0], png = readFileSync(join(f.directory, entry.file));
  const payload = Buffer.concat([Buffer.from('provenance\0\0'), deflateSync(Buffer.from('not-public'))]);
  const chunk = Buffer.alloc(payload.length + 12); chunk.writeUInt32BE(payload.length); chunk.write('zTXt', 4); payload.copy(chunk, 8);
  f.replacePng(entry, Buffer.concat([png.subarray(0, png.length - 12), chunk, png.subarray(png.length - 12)]));
  assert.throws(() => verifyPortholePack(f.dir), /PNG metadata/);
});
test('requires the approved badge notice and complete model variants', t => {
  const f = fixture(t), notice = join(f.directory, 'BADGE-NOTICE.txt'), text = readFileSync(notice, 'utf8');
  writeFileSync(notice, text.replace('no recognisable third-party logos', 'unspecified'));
  assert.throws(() => verifyPortholePack(f.dir), /badge notice/);
  writeFileSync(notice, text); f.manifest.sprites[0].modelId = f.manifest.sprites[1].modelId + '-extra'; f.save();
  assert.throws(() => verifyPortholePack(f.dir));
});
