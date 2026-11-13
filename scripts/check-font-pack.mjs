// SPDX-License-Identifier: MIT
// Offline integrity/licence check for the public third-party font distribution.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const prefix = 'desktop/third-party/fonts/';
const license = 'OFL-1.1';
const families = [
  ['manrope', 'Manrope', [500, 600, 700, 800]],
  ['dm-sans', 'DM Sans', [400, 500, 600, 700]],
  ['jetbrains-mono', 'JetBrains Mono', [400, 500, 600]],
  ['share-tech-mono', 'Share Tech Mono', [400]],
];
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const privateText = /sourceRoot|designCommit|designHead|design-handoffs|clients\/official-visuals|guanbear|modelplans\.ai|\/home\/|\/tmp\/|\/mnt\/shared/i;
function keys(value, allowed) {
  assert.ok(value && typeof value === 'object' && !Array.isArray(value), 'manifest object required');
  assert.deepEqual(Object.keys(value).sort(), [...allowed].sort(), 'unapproved or missing manifest field');
}
function walk(directory, relative = '') {
  return readdirSync(directory).flatMap(name => {
    const file = relative + name, path = join(directory, name), stat = lstatSync(path);
    assert.ok(!stat.isSymbolicLink(), 'symlink in font pack');
    if (stat.isDirectory()) {
      assert.ok(families.some(([id]) => id === file), 'directory outside font manifest');
      return walk(path, file + '/');
    }
    assert.ok(stat.isFile(), 'non-file in font pack');
    return [file];
  });
}

export function verifyFontPack(root = fileURLToPath(new URL('..', import.meta.url))) {
  root = resolve(root);
  for (const path of ['desktop', 'desktop/third-party', prefix]) {
    const stat = lstatSync(join(root, path));
    assert.ok(stat.isDirectory() && !stat.isSymbolicLink(), 'symlink or invalid font directory');
  }
  const directory = join(root, prefix);
  const actual = walk(directory); // Refuse symlink directories before reading through them.
  const policy = JSON.parse(readFileSync(join(root, 'source-policy.json')));
  const registry = policy.thirdPartyFonts;
  keys(registry, ['prefix', 'license', 'manifest', 'manifestSha256']);
  assert.equal(registry.prefix, prefix, 'third-party font prefix');
  assert.equal(registry.license, license, 'third-party font licence');
  assert.equal(registry.manifest, prefix + 'manifest.json');
  assert.ok(!Object.keys(policy.reservedVisuals.binaries).some(p => p.startsWith(prefix)), 'OFL fonts in reserved registry');
  const raw = readFileSync(join(root, registry.manifest));
  assert.equal(sha256(raw), registry.manifestSha256, 'font manifest hash mismatch');
  const manifest = JSON.parse(raw);
  assert.ok(!privateText.test(JSON.stringify(manifest)), 'private provenance in font manifest');
  keys(manifest, ['schemaVersion', 'license', 'families', 'files']);
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.license, license, 'font manifest licence');
  assert.equal(manifest.families.length, families.length, 'four approved font families required');
  const expected = new Map([
    ['README.md', { kind: 'readme', license: 'MIT' }],
    ['NOTICE.md', { kind: 'notice', license: 'MIT' }],
    ['fonts.css', { kind: 'stylesheet', license: 'MIT' }],
  ]);
  let stylesheet = '/* SPDX-License-Identifier: MIT */\n/* Static, normal-style Latin faces. Font binaries remain OFL-1.1. */\n\n';
  const notices = readFileSync(join(directory, 'NOTICE.md'), 'utf8');
  families.forEach(([id, name, weights], index) => {
    const family = manifest.families[index];
    keys(family, ['id', 'name', 'weights', 'package', 'version', 'source', 'licenseFile', 'copyright']);
    assert.deepEqual([family.id, family.name, family.weights], [id, name, weights], 'unapproved family or unused weight');
    assert.equal(family.package, '@fontsource/' + id);
    assert.equal(family.version, '5.3.0');
    assert.equal(family.source, `https://www.npmjs.com/package/@fontsource/${id}/v/5.3.0`);
    assert.equal(family.licenseFile, `${id}/OFL.txt`);
    const ofl = readFileSync(join(directory, family.licenseFile), 'utf8');
    assert.ok(ofl.startsWith(family.copyright + '\n') && family.copyright.startsWith('Copyright'), 'font copyright notice');
    assert.match(ofl, /SIL OPEN FONT LICENSE Version 1\.1 - 26 February 2007/);
    assert.match(ofl, /PERMISSION & CONDITIONS[\s\S]+TERMINATION[\s\S]+DISCLAIMER/);
    if (id === 'share-tech-mono') assert.match(ofl, /Reserved Font Name 'Share'/);
    assert.ok(notices.includes(`| ${name} | ${weights.join(', ')} |`) &&
      notices.includes(`(${family.licenseFile})`) && notices.includes(family.source), 'missing family NOTICE row');
    expected.set(family.licenseFile, { kind: 'license', license, family: id });
    for (const weight of weights) {
      const file = `${id}/${id}-latin-${weight}-normal.woff2`;
      expected.set(file, { kind: 'font', license, family: id, weight, style: 'normal' });
      stylesheet += `@font-face {\n  font-family: '${name}';\n  font-style: normal;\n  font-weight: ${weight};\n  font-display: swap;\n  src: url('./${file}') format('woff2');\n}\n\n`;
    }
  });
  const seen = new Set();
  let fontBytes = 0, fontCount = 0;
  for (const entry of manifest.files) {
    assert.ok(expected.has(entry.file) && !seen.has(entry.file), 'unapproved or duplicate font pack file');
    const meta = expected.get(entry.file);
    keys(entry, ['file', 'sha256', 'bytes', ...Object.keys(meta)]);
    for (const [key, value] of Object.entries(meta)) assert.equal(entry[key], value, 'font file ' + key);
    const bytes = readFileSync(join(directory, entry.file));
    assert.equal(bytes.length, entry.bytes, 'font file size mismatch');
    assert.equal(sha256(bytes), entry.sha256, 'font file hash mismatch');
    if (entry.kind === 'font') {
      assert.ok(bytes.length > 48 && bytes.toString('ascii', 0, 4) === 'wOF2', 'WOFF2 header');
      assert.equal(bytes.readUInt32BE(8), bytes.length, 'WOFF2 length');
      fontCount++; fontBytes += bytes.length;
    } else {
      const text = bytes.toString('utf8');
      assert.ok(Buffer.from(text).equals(bytes) && !privateText.test(text), 'non-text or private string in font metadata');
      assert.ok(!text.includes('LicenseRef-ModelPlan-Visuals-1.0'), 'reserved licence in OFL font pack');
      if (entry.license === 'MIT') assert.match(text, /SPDX-License-Identifier: MIT/);
    }
    seen.add(entry.file);
  }
  assert.deepEqual([...seen].sort(), [...expected.keys()].sort(), 'incomplete font manifest');
  assert.deepEqual(actual.sort(), ['manifest.json', ...seen].sort(), 'file outside font manifest');
  assert.equal(readFileSync(join(directory, 'fonts.css'), 'utf8').trimEnd(), stylesheet.trimEnd(), 'font stylesheet bindings');
  return { fontCount, fontBytes, manifestSha256: sha256(raw) };
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  console.log('U9 third-party fonts:', verifyFontPack());
}
