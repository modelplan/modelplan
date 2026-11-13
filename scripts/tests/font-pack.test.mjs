// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { verifyFontPack } from '../check-font-pack.mjs';

const source = fileURLToPath(new URL('../..', import.meta.url));
const prefix = 'desktop/third-party/fonts';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'u9-fonts-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const pack = join(root, prefix);
  cpSync(join(source, prefix), pack, { recursive: true });
  const policy = JSON.parse(readFileSync(join(source, 'source-policy.json')));
  const manifest = JSON.parse(readFileSync(join(pack, 'manifest.json')));
  function save() {
    const raw = JSON.stringify(manifest);
    writeFileSync(join(pack, 'manifest.json'), raw);
    policy.thirdPartyFonts.manifestSha256 = hash(raw);
    writeFileSync(join(root, 'source-policy.json'), JSON.stringify(policy));
  }
  function refresh(file) {
    const bytes = readFileSync(join(pack, file));
    Object.assign(manifest.files.find(f => f.file === file), { sha256: hash(bytes), bytes: bytes.length });
    save();
  }
  save();
  return { root, pack, policy, manifest, save, refresh };
}

test('validates the complete OFL-only static font set offline', () => {
  assert.equal(verifyFontPack(source).fontCount, 12);
});
test('rejects altered bytes and a manifest changed without a policy update', t => {
  const f = fixture(t), font = f.manifest.files.find(e => e.kind === 'font');
  const original = readFileSync(join(f.pack, font.file));
  const changed = Buffer.from(original); changed[changed.length - 1] ^= 1;
  writeFileSync(join(f.pack, font.file), changed);
  assert.throws(() => verifyFontPack(f.root), /hash/);
  writeFileSync(join(f.pack, font.file), original);
  writeFileSync(join(f.pack, 'manifest.json'), JSON.stringify({ ...f.manifest, license: 'MIT' }));
  assert.throws(() => verifyFontPack(f.root), /manifest hash/);
});
test('rejects a missing or truncated family OFL and a missing NOTICE row', t => {
  const f = fixture(t), license = f.manifest.families[0].licenseFile;
  const original = readFileSync(join(f.pack, license));
  rmSync(join(f.pack, license));
  assert.throws(() => verifyFontPack(f.root), /ENOENT/);
  writeFileSync(join(f.pack, license), original.subarray(0, 100)); f.refresh(license);
  assert.throws(() => verifyFontPack(f.root), /OPEN FONT LICENSE/);
  writeFileSync(join(f.pack, license), original); f.refresh(license);
  writeFileSync(join(f.pack, 'NOTICE.md'), '<!-- SPDX-License-Identifier: MIT -->\n'); f.refresh('NOTICE.md');
  assert.throws(() => verifyFontPack(f.root), /NOTICE/);
});
test('rejects relicensing, unused weights, unknown metadata and duplicate files', t => {
  for (const change of ['licence', 'weights', 'field', 'duplicate']) {
    const f = fixture(t);
    if (change === 'licence') f.manifest.files.find(e => e.kind === 'font').license = 'MIT';
    if (change === 'weights') f.manifest.families[0].weights.push(900);
    if (change === 'field') f.manifest.extra = 'unapproved';
    if (change === 'duplicate') f.manifest.files.push(f.manifest.files[0]);
    f.save();
    assert.throws(() => verifyFontPack(f.root), /licen[cs]e|weight|field|duplicate/);
  }
});
test('rejects extra files, path traversal and directory symlinks', t => {
  const f = fixture(t);
  writeFileSync(join(f.pack, 'extra.woff2'), 'unapproved');
  assert.throws(() => verifyFontPack(f.root), /outside font manifest/);
  rmSync(join(f.pack, 'extra.woff2'));
  const original = f.manifest.files[0].file;
  f.manifest.files[0].file = '../outside'; f.save();
  assert.throws(() => verifyFontPack(f.root), /unapproved/);
  f.manifest.files[0].file = original; f.save();
  rmSync(join(f.pack, 'manrope'), { recursive: true });
  symlinkSync(join(source, prefix, 'manrope'), join(f.pack, 'manrope'));
  assert.throws(() => verifyFontPack(f.root), /symlink/);
});
test('rejects remote CSS bindings and private provenance even with updated hashes', t => {
  const f = fixture(t);
  const css = readFileSync(join(f.pack, 'fonts.css'), 'utf8');
  writeFileSync(join(f.pack, 'fonts.css'), css.replace("url('./manrope/", "url('https://example.com/manrope/"));
  f.refresh('fonts.css');
  assert.throws(() => verifyFontPack(f.root), /stylesheet bindings/);
  writeFileSync(join(f.pack, 'fonts.css'), css); f.refresh('fonts.css');
  f.manifest.families[0].source = '/home/private/font'; f.save();
  assert.throws(() => verifyFontPack(f.root), /private provenance/);
});
test('rejects a reserved-licence registry binding', t => {
  const f = fixture(t);
  f.policy.thirdPartyFonts.license = 'LicenseRef-ModelPlan-Visuals-1.0'; f.save();
  assert.throws(() => verifyFontPack(f.root), /licence/);
});
test('real CLI validates a standalone public pack without private files', t => {
  const f = fixture(t);
  mkdirSync(join(f.root, 'scripts'));
  cpSync(join(source, 'scripts/check-font-pack.mjs'), join(f.root, 'scripts/check-font-pack.mjs'));
  const run = () => spawnSync(process.execPath, [join(f.root, 'scripts/check-font-pack.mjs')], { encoding: 'utf8' });
  assert.equal(run().status, 0);
  rmSync(join(f.pack, 'NOTICE.md'));
  assert.notEqual(run().status, 0);
});
