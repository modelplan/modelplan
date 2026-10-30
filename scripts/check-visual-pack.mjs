// SPDX-License-Identifier: MIT
// Public-data-only integrity check. No private checkout or credentials are used.
import assert from 'node:assert/strict';
import { verifyPortholePack } from './check-porthole-pack.mjs';
import { keys, pngSize, privateText } from './visual-pack-format.mjs';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, lstatSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const license = 'LicenseRef-ModelPlan-Visuals-1.0';
const prefix = 'desktop/official-visuals/runtime/';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const common = ['file', 'kind', 'sha256', 'bytes', 'license', 'size'];

function expectedFiles(porthole) {
  const files = new Map([['README.md', { kind: 'notice' }]]);
  for (const theme of ['day', 'night']) for (const state of ['idle', 'pressed']) for (const scale of [2, 3]) {
    files.set(`ignition-a5/a5-cap-${theme}-${state}-44x44@${scale}x.png`, { kind: 'ignition-cap', theme, state, scale });
  }
  for (const [part, size] of [['inner-contact-shadow', 52], ['outer-contact-shadow', 56], ['recessed-guard', 52]]) {
    for (const scale of [2, 3]) files.set(`ignition-a5/a5-${part}-${size}x${size}@${scale}x.png`, { kind: 'ignition-layer', scale });
  }
  for (const tier of [640, 890]) for (const scale of [1, 2]) {
    for (const layer of ['canopy', 'pane', 'window', 'aperture', 'solid-outline']) {
      files.set(`canopy-c01/${layer}-${tier}-${scale}x.png`, { kind: 'canopy-layer', tier, scale });
    }
  }
  if (porthole) for (const f of porthole.descriptors) {
    const meta = { kind: f.kind };
    for (const k of ['theme', 'scale']) if (Object.hasOwn(f, k)) meta[k] = f[k];
    files.set('porthole-stills/' + f.file, meta);
  }
  return files;
}

function walk(directory, relative = '') {
  const files = [];
  for (const item of readdirSync(directory)) {
    const name = relative ? `${relative}/${item}` : item;
    const path = join(directory, item), stat = lstatSync(path);
    assert.ok(!stat.isSymbolicLink(), `symlink in runtime pack: ${name}`);
    if (stat.isDirectory()) {
      assert.ok(['ignition-a5', 'canopy-c01', 'porthole-stills', 'porthole-stills/assets', 'porthole-stills/assets/projected'].includes(name), 'directory outside manifest');
      files.push(...walk(path, name));
    }
    else {
      assert.ok(stat.isFile(), `non-file in runtime pack: ${name}`);
      files.push(name);
    }
  }
  return files;
}

export function verifyVisualPack(root = fileURLToPath(new URL('..', import.meta.url))) {
  root = resolve(root);
  for (const part of ['desktop', 'desktop/official-visuals', 'desktop/official-visuals/runtime']) {
    assert.ok(!lstatSync(join(root, part)).isSymbolicLink(), 'symlink in runtime path');
  }
  const directory = join(root, prefix), raw = readFileSync(join(directory, 'manifest.json'));
  assert.ok(!privateText.test(raw.toString('utf8')), 'private string in manifest');
  const manifest = JSON.parse(raw);
  assert.ok(!privateText.test(JSON.stringify(manifest)), 'private string in decoded manifest');
  keys(manifest, ['schemaVersion', 'SPDX-License-Identifier', 'copyright', 'trademarkNotice', 'files', 'baselines']);
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest['SPDX-License-Identifier'], license, 'manifest licence');
  assert.match(manifest.copyright, /Copyright.*2026.*ModelPlan/);
  assert.match(manifest.trademarkNotice, /ModelPlan.*trademark/i);
  assert.ok(Array.isArray(manifest.files) && Array.isArray(manifest.baselines), 'manifest lists required');
  const porthole = manifest.files.some(f => f.file?.startsWith('porthole-stills/')) ? verifyPortholePack(root) : null;
  const expected = expectedFiles(porthole), seen = new Map(), pngs = {};
  for (const entry of manifest.files) {
    keys(entry, [...common, 'theme', 'state', 'scale', 'tier'], common);
    assert.ok(typeof entry.file === 'string' && !entry.file.includes('\\') &&
      entry.file.split('/').every(p => p && p !== '.' && p !== '..'), 'invalid file path');
    assert.ok(expected.has(entry.file) && !seen.has(entry.file), 'unapproved or duplicate file');
    for (const [key, value] of Object.entries(expected.get(entry.file))) assert.equal(entry[key], value, `file ${key}`);
    assert.equal(entry.license, license, 'file licence');
    assert.match(entry.sha256, /^[a-f0-9]{64}$/);
    assert.ok(Number.isSafeInteger(entry.bytes) && entry.bytes > 0, 'file size');
    const path = join(directory, entry.file);
    assert.ok(lstatSync(path).isFile() && !lstatSync(path).isSymbolicLink(), 'file or symlink');
    const bytes = readFileSync(path);
    assert.equal(bytes.length, entry.bytes, 'file size mismatch');
    assert.equal(sha256(bytes), entry.sha256, 'file hash mismatch');
    assert.ok(!privateText.test(bytes.toString('utf8')), 'private string in runtime file');
    if (entry.size === null) {
      assert.equal(entry.size, null, 'notice dimensions');
      assert.ok(bytes.toString().includes('SPDX-License-Identifier') && bytes.toString().includes(license), 'notice licence');
      if (entry.kind === 'notice') assert.match(bytes.toString(), /ModelPlan.*trademark/i);
    } else {
      keys(entry.size, ['width', 'height']);
      assert.deepEqual(pngSize(bytes), entry.size, 'PNG dimensions mismatch');
      pngs[prefix + entry.file] = entry.sha256;
    }
    seen.set(entry.file, entry);
  }
  assert.deepEqual([...seen.keys()].sort(), [...expected.keys()].sort(), 'incomplete approved runtime pack');
  assert.deepEqual(walk(directory).sort(), ['manifest.json', ...seen.keys()].sort(), 'file outside manifest');
  const baselineFiles = new Set();
  for (const baseline of manifest.baselines) {
    keys(baseline, ['file', 'sha256', 'theme', 'state', 'scale']);
    const entry = seen.get(baseline.file);
    assert.ok(entry?.kind === 'ignition-cap' && !baselineFiles.has(baseline.file), 'invalid baseline file');
    for (const key of ['sha256', 'theme', 'state', 'scale']) assert.equal(baseline[key], entry[key], `baseline ${key}`);
    baselineFiles.add(baseline.file);
  }
  assert.equal(baselineFiles.size, 8, 'eight approved baseline exports required');
  const policy = JSON.parse(readFileSync(join(root, 'source-policy.json'), 'utf8'));
  const registry = Object.fromEntries(Object.entries(policy.reservedVisuals.binaries).filter(([path]) => path.startsWith(prefix)));
  assert.deepEqual(registry, pngs, 'source-policy binary registry mismatch');
  return { manifestSha256: sha256(raw), pngCount: Object.keys(pngs).length,
    pngBytes: manifest.files.filter(e => e.size !== null).reduce((n, e) => n + e.bytes, 0) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const result = verifyVisualPack();
  console.log(`U9 runtime pack: ${result.pngCount} PNGs, ${result.pngBytes} bytes; manifest ${result.manifestSha256}`);
}
