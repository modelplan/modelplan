// SPDX-License-Identifier: MIT
// Validate only public runtime data. No rendering, downloads or private source required.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, lstatSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { keys, pngSize, privateText } from './visual-pack-format.mjs';
const license = 'LicenseRef-ModelPlan-Visuals-1.0';
const prefix = 'desktop/official-visuals/runtime/porthole-stills/';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const common = ['file', 'kind', 'sha256', 'bytes', 'license', 'size'];
const metadata = { 'manifest.json': 'porthole-manifest', 'SHA256SUMS': 'porthole-checksums',
  'BADGE-NOTICE.txt': 'porthole-notice', 'README.md': 'porthole-notice' };
function finite(v, positive = false) { assert.ok(Number.isFinite(v) && Math.abs(v) <= 1000000 && (!positive || v > 0), 'invalid runtime coordinate'); }
function point(p) { keys(p, ['x', 'y']); finite(p.x); finite(p.y); }
function size(p) { keys(p, ['width', 'height']); finite(p.width, true); finite(p.height, true); }
function label(v) { assert.ok(typeof v === 'string' && v.length > 0 && v.length < 100 && !/[\x00-\x1f]/.test(v), 'invalid display label'); }
function walk(directory, relative = '') {
  const files = [];
  for (const item of readdirSync(directory)) {
    const name = relative ? `${relative}/${item}` : item, stat = lstatSync(join(directory, item));
    assert.ok(!stat.isSymbolicLink(), 'symlink in porthole pack');
    if (stat.isDirectory()) {
      assert.ok(['assets', 'assets/projected'].includes(name), 'directory outside manifest');
      files.push(...walk(join(directory, item), name));
    } else { assert.ok(stat.isFile(), 'non-file in pack'); files.push(name); }
  }
  return files;
}
export function verifyPortholePack(root = fileURLToPath(new URL('..', import.meta.url))) {
  root = resolve(root);
  for (const part of ['desktop', 'desktop/official-visuals', 'desktop/official-visuals/runtime', prefix]) {
    assert.ok(!lstatSync(join(root, part)).isSymbolicLink(), 'symlink in porthole path');
  }
  const directory = join(root, prefix), raw = readFileSync(join(directory, 'manifest.json'));
  assert.ok(!privateText.test(raw.toString()), 'private string in porthole manifest');
  const m = JSON.parse(raw);
  assert.ok(!privateText.test(JSON.stringify(m)), 'private string in decoded porthole manifest');
  keys(m, ['schemaVersion', 'SPDX-License-Identifier', 'copyright', 'trademarkNotice', 'fileCount', 'pngBytes',
    'defaultProjectionId', 'files', 'sprites', 'backgrounds', 'projections', 'animation']);
  assert.equal(m.schemaVersion, 1); assert.equal(m['SPDX-License-Identifier'], license);
  assert.match(m.copyright, /Copyright.*2026.*ModelPlan/); assert.match(m.trademarkNotice, /ModelPlan.*trademark/i);
  assert.equal(m.fileCount, 980); assert.equal(m.files.length, 980);
  const files = new Map(), descriptors = [], pngs = {};
  let bytes = 0;
  for (const f of m.files) {
    keys(f, [...common, 'theme', 'scale']);
    assert.match(f.file, /^assets\/(?:projected\/)?[a-z0-9][a-z0-9.-]*\.png$/);
    assert.ok(!files.has(f.file), 'duplicate porthole file');
    assert.ok(['porthole-body', 'porthole-flame', 'porthole-halo', 'porthole-background'].includes(f.kind));
    assert.ok(['day', 'night'].includes(f.theme)); assert.ok([1, 2].includes(f.scale));
    assert.equal(f.license, license); assert.match(f.sha256, /^[a-f0-9]{64}$/);
    assert.ok(Number.isSafeInteger(f.bytes) && f.bytes > 0);
    const stat = lstatSync(join(directory, f.file)); assert.ok(stat.isFile() && !stat.isSymbolicLink(), 'linked or missing porthole file');
    const data = readFileSync(join(directory, f.file));
    assert.equal(data.length, f.bytes, 'porthole byte size mismatch'); assert.equal(sha256(data), f.sha256, 'porthole hash mismatch');
    assert.deepEqual(pngSize(data), f.size, 'porthole PNG dimensions');
    files.set(f.file, f); bytes += f.bytes; pngs[prefix + f.file] = f.sha256; descriptors.push(f);
  }
  assert.equal(bytes, m.pngBytes); assert.ok(bytes <= 4 * 1024 * 1024, '4 MiB porthole budget exceeded');
  const referenced = new Set();
  function reference(file, kind, theme, scale, dimensions) {
    const f = files.get(file); assert.ok(f, 'missing runtime PNG reference');
    assert.equal(f.kind, 'porthole-' + kind, 'reference kind mismatch'); assert.equal(f.theme, theme); assert.equal(f.scale, scale);
    if (dimensions) assert.deepEqual(f.size, dimensions, 'runtime layer dimensions');
    assert.ok(!referenced.has(file), 'duplicate runtime PNG reference'); referenced.add(file);
  }
  const sprites = new Set(), models = new Set();
  assert.equal(m.sprites.length, 136);
  for (const s of m.sprites) {
    keys(s, ['modelId', 'name', 'theme', 'scale', 'variant', 'size', 'anchor', 'flameAnchor', 'logicalSize', 'body', 'flame']);
    label(s.modelId); label(s.name); assert.match(s.modelId, /^[a-z0-9.-]+$/);
    assert.ok(['day', 'night'].includes(s.theme) && [1, 2].includes(s.scale) && ['standard', 'heavy'].includes(s.variant));
    const key = [s.modelId, s.theme, s.variant, s.scale].join('/'); assert.ok(!sprites.has(key), 'duplicate sprite recipe'); sprites.add(key); models.add(s.modelId);
    assert.deepEqual(s.logicalSize, { width: 112, height: 192 }); assert.deepEqual(s.size, { width: 112 * s.scale, height: 192 * s.scale });
    point(s.anchor); point(s.flameAnchor);
    assert.equal(s.body, `assets/${s.modelId}-${s.theme}-${s.variant}-${s.scale}x.png`);
    assert.equal(s.flame, `assets/${s.modelId}-${s.theme}-${s.variant}-flame-${s.scale}x.png`);
    reference(s.body, 'body', s.theme, s.scale, s.size); reference(s.flame, 'flame', s.theme, s.scale, s.size);
  }
  assert.equal(models.size, 17);
  for (const id of models) for (const theme of ['day', 'night']) for (const variant of ['standard', 'heavy']) for (const scale of [1, 2]) {
    assert.ok(sprites.has([id, theme, variant, scale].join('/')), 'incomplete sprite variants');
  }
  assert.equal(m.backgrounds.length, 8);
  for (const b of m.backgrounds) {
    keys(b, ['theme', 'layout', 'profile', 'scale', 'size', 'file']);
    assert.ok([640, 890].includes(b.layout) && ['tall', 'short'].includes(b.profile)); assert.equal(b.scale, 2); size(b.size);
    assert.equal(b.file, `assets/background-${b.theme}-${b.layout}-${b.profile}-${b.scale}x.png`);
    reference(b.file, 'background', b.theme, b.scale, b.size);
  }
  const ids = new Set(); assert.equal(m.projections.length, 28);
  for (const p of m.projections) {
    keys(p, ['id', 'theme', 'layout', 'width', 'height', 'background', 'backgroundScale', 'models']);
    assert.match(p.id, /^[a-f0-9]{12}$/); assert.ok(!ids.has(p.id), 'duplicate projection'); ids.add(p.id);
    assert.ok([640, 890].includes(p.layout) && ['day', 'night'].includes(p.theme)); finite(p.width, true); finite(p.height, true); assert.equal(p.backgroundScale, 2);
    assert.equal(p.background, `assets/projected/${p.id}-background.png`);
    reference(p.background, 'background', p.theme, 2, { width: p.width * 2, height: p.height * 2 });
    const modelIds = new Set(); assert.ok(p.models.length > 0 && p.models.length <= 7);
    for (const model of p.models) {
      keys(model, ['id', 'variant', 'root', 'nose', 'nozzle', 'body', 'flame', 'halo']); label(model.id); assert.ok(models.has(model.id), 'unknown projected model');
      assert.ok(!modelIds.has(model.id), 'duplicate projected model'); modelIds.add(model.id);
      assert.ok(['standard', 'heavy', 'racer'].includes(model.variant)); point(model.root); point(model.nose); point(model.nozzle);
      for (const kind of ['body', 'flame', 'halo']) {
        const l = model[kind]; keys(l, ['left', 'top', 'width', 'height', 'pixelScale', 'pixelScale1x', 'file', 'file1x', ...(kind === 'body' ? [] : ['blend', 'encoding'])]);
        for (const k of ['left', 'top']) finite(l[k]); for (const k of ['width', 'height', 'pixelScale', 'pixelScale1x']) finite(l[k], true);
        assert.equal(l.pixelScale, kind === 'halo' ? .5 : 2); assert.equal(l.pixelScale1x, kind === 'halo' ? .25 : 1);
        if (kind !== 'body') { assert.equal(l.blend, 'plus-lighter'); assert.equal(l.encoding, 'premultiplied display-sRGB contribution; straight RGB/alpha PNG'); }
        for (const [key, scale, factor] of [['file', 2, l.pixelScale], ['file1x', 1, l.pixelScale1x]]) {
          assert.equal(l[key], `assets/projected/${p.id}-${model.id}-${kind}-${scale}x.png`);
          reference(l[key], kind, p.theme, scale, { width: Math.ceil(l.width * factor), height: Math.ceil(l.height * factor) });
        }
      }
    }
  }
  assert.equal(m.defaultProjectionId, '4ff2bad27654');
  const initial = m.projections.find(p => p.id === m.defaultProjectionId);
  assert.ok(initial && initial.models.length === 7 && initial.theme === 'night' && initial.layout === 890, 'default still missing');
  keys(m.animation, ['opacity', 'scaleX', 'scaleY', 'reduceMotion']);
  for (const k of ['opacity', 'scaleX', 'scaleY']) { assert.equal(m.animation[k].length, 2); m.animation[k].forEach(v => finite(v, true)); }
  assert.equal(m.animation.reduceMotion, 'static'); assert.deepEqual([...referenced].sort(), [...files.keys()].sort(), 'unreferenced PNG');
  const lines = readFileSync(join(directory, 'SHA256SUMS'), 'utf8').split('\n').filter(l => l && !l.startsWith('#'));
  assert.deepEqual(lines, [...files.values()].sort((a, b) => a.file < b.file ? -1 : a.file > b.file ? 1 : 0).map(f => `${f.sha256}  ${f.file}`), 'checksums differ from manifest');
  for (const [file, kind] of Object.entries(metadata)) {
    const data = readFileSync(join(directory, file)); const text = data.toString();
    assert.ok(!privateText.test(text), 'private text in porthole metadata');
    assert.ok(text.includes('SPDX-License-Identifier' + (file.endsWith('.json') ? '"' : '') + ':') && text.includes(license), 'metadata licence');
    if (file === 'BADGE-NOTICE.txt') assert.ok(text.includes('Badge interiors are abstract colour fields containing no recognisable third-party logos.'), 'badge notice missing');
    descriptors.push({ file, kind, sha256: sha256(data), bytes: data.length, license, size: null });
  }
  assert.deepEqual(walk(directory).sort(), [...files.keys(), ...Object.keys(metadata)].sort(), 'file outside porthole manifest');
  const policy = JSON.parse(readFileSync(join(root, 'source-policy.json'), 'utf8'));
  assert.deepEqual(Object.fromEntries(Object.entries(policy.reservedVisuals.binaries).filter(([p]) => p.startsWith(prefix))), pngs, 'porthole policy registry mismatch');
  return { manifestSha256: sha256(raw), pngCount: files.size, pngBytes: bytes, descriptors };
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { descriptors, ...result } = verifyPortholePack(); console.log('U12 porthole pack:', result);
}
