// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { verifyVisualPack } from '../check-visual-pack.mjs';

const license = 'LicenseRef-ModelPlan-Visuals-1.0';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'u9-pack-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const pack = join(root, 'desktop/official-visuals/runtime');
  mkdirSync(pack, { recursive: true });
  const manifest = { schemaVersion: 1, 'SPDX-License-Identifier': license,
    copyright: 'Copyright (c) 2026 ModelPlan. All rights reserved.',
    trademarkNotice: 'ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.',
    files: [], baselines: [] };
  const policy = { reservedVisuals: { binaries: {} } };
  function add(file, kind, extra = {}) {
    const bytes = kind === 'notice' ? Buffer.from(`<!-- SPDX-License-Identifier: ${license} -->\nModelPlan trademark notice.\n`) : png;
    mkdirSync(join(pack, file, '..'), { recursive: true });
    writeFileSync(join(pack, file), bytes);
    const entry = { file, kind, sha256: hash(bytes), bytes: bytes.length, license,
      size: kind === 'notice' ? null : { width: 1, height: 1 }, ...extra };
    manifest.files.push(entry);
    if (kind !== 'notice') policy.reservedVisuals.binaries['desktop/official-visuals/runtime/' + file] = entry.sha256;
    return entry;
  }
  add('README.md', 'notice');
  for (const theme of ['day', 'night']) for (const state of ['idle', 'pressed']) for (const scale of [2, 3]) {
    const entry = add(`ignition-a5/a5-cap-${theme}-${state}-44x44@${scale}x.png`, 'ignition-cap', { theme, state, scale });
    manifest.baselines.push({ file: entry.file, sha256: entry.sha256, theme, state, scale });
  }
  for (const [part, size] of [['inner-contact-shadow', 52], ['outer-contact-shadow', 56], ['recessed-guard', 52]]) {
    for (const scale of [2, 3]) add(`ignition-a5/a5-${part}-${size}x${size}@${scale}x.png`, 'ignition-layer', { scale });
  }
  for (const tier of [640, 890]) for (const scale of [1, 2]) {
    for (const layer of ['canopy', 'pane', 'window', 'aperture', 'solid-outline']) {
      add(`canopy-c01/${layer}-${tier}-${scale}x.png`, 'canopy-layer', { tier, scale });
    }
  }
  function save() {
    writeFileSync(join(pack, 'manifest.json'), JSON.stringify(manifest));
    writeFileSync(join(root, 'source-policy.json'), JSON.stringify(policy));
  }
  save();
  return { root, pack, manifest, policy, save };
}

test('checks every file, licence, baseline, PNG size and policy hash', t => {
  const f = fixture(t);
  assert.equal(verifyVisualPack(f.root).pngCount, 34);
});

test('rejects changed PNG bytes, dimensions and unregistered files', t => {
  const f = fixture(t);
  const file = f.manifest.files.find(x => x.file.endsWith('.png'));
  writeFileSync(join(f.pack, file.file), Buffer.concat([png, Buffer.from('changed')]));
  assert.throws(() => verifyVisualPack(f.root), /hash|size/);
  writeFileSync(join(f.pack, file.file), png);
  file.size.width = 2; f.save();
  assert.throws(() => verifyVisualPack(f.root), /dimensions/);
  file.size.width = 1; f.save();
  writeFileSync(join(f.pack, 'unlisted.png'), png);
  assert.throws(() => verifyVisualPack(f.root), /outside manifest/);
});

test('rejects private provenance, missing licences and wrong registry hashes', t => {
  const f = fixture(t);
  f.manifest.sourceRoot = 'private-root'; f.save();
  assert.throws(() => verifyVisualPack(f.root), /field|private/);
  delete f.manifest.sourceRoot;
  f.manifest.files[1].license = 'MIT'; f.save();
  assert.throws(() => verifyVisualPack(f.root), /licen[cs]e/);
  f.manifest.files[1].license = license;
  const key = Object.keys(f.policy.reservedVisuals.binaries)[0];
  f.policy.reservedVisuals.binaries[key] = '0'.repeat(64); f.save();
  assert.throws(() => verifyVisualPack(f.root), /registry/);
});

test('rejects paths, links, missing or mismatched baselines and unrelated art', t => {
  const f = fixture(t);
  const original = f.manifest.files[1].file;
  f.manifest.files[1].file = '../outside.png'; f.save();
  assert.throws(() => verifyVisualPack(f.root), /path|file/);
  f.manifest.files[1].file = original;
  f.manifest.baselines[0].sha256 = '0'.repeat(64); f.save();
  assert.throws(() => verifyVisualPack(f.root), /baseline/);
  f.manifest.baselines[0].sha256 = f.manifest.files[1].sha256; f.save();
  symlinkSync(join(f.pack, original), join(f.pack, 'link.png'));
  assert.throws(() => verifyVisualPack(f.root), /symlink/);
});

test('rejects a private string even when its text hash is updated', t => {
  const f = fixture(t);
  const notice = f.manifest.files[0];
  const bytes = Buffer.concat([readFileSync(join(f.pack, notice.file)), Buffer.from('\ndesign-handoffs/not-public\n')]);
  writeFileSync(join(f.pack, notice.file), bytes);
  notice.sha256 = hash(bytes); notice.bytes = bytes.length; f.save();
  assert.throws(() => verifyVisualPack(f.root), /private/);
});

test('rejects compressed PNG metadata even with matching manifest and registry', t => {
  const f = fixture(t), entry = f.manifest.files[1];
  const payload = Buffer.concat([Buffer.from('provenance\0\0'), deflateSync(Buffer.from('sourceRoot=not-public'))]);
  const chunk = Buffer.alloc(payload.length + 12);
  chunk.writeUInt32BE(payload.length); chunk.write('zTXt', 4); payload.copy(chunk, 8);
  const bytes = Buffer.concat([png.subarray(0, png.length - 12), chunk, png.subarray(png.length - 12)]);
  writeFileSync(join(f.pack, entry.file), bytes);
  entry.sha256 = hash(bytes); entry.bytes = bytes.length;
  f.policy.reservedVisuals.binaries['desktop/official-visuals/runtime/' + entry.file] = entry.sha256;
  f.save();
  assert.throws(() => verifyVisualPack(f.root), /PNG metadata/);
});

test('rejects escaped private JSON strings and unlisted empty directories', t => {
  const f = fixture(t);
  f.manifest.copyright += ' design-handoffs/hidden';
  f.save();
  const path = join(f.pack, 'manifest.json');
  writeFileSync(path, readFileSync(path, 'utf8').replace('design-handoffs', 'd\\u0065sign-handoffs'));
  assert.throws(() => verifyVisualPack(f.root), /private/);
  f.manifest.copyright = 'Copyright (c) 2026 ModelPlan. All rights reserved.'; f.save();
  mkdirSync(join(f.pack, 'unlisted-directory'));
  assert.throws(() => verifyVisualPack(f.root), /outside manifest/);
});
