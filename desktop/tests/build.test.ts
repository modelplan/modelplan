import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const desktop = fileURLToPath(new URL('..', import.meta.url));
const dist = join(desktop, 'app/dist');
const official = join(desktop, 'official-visuals');
const read = (p: string) => readFileSync(join(dist, p), 'utf8');
const build = (...args: string[]) =>
  execFileSync(process.execPath, ['build.mjs', ...args], { cwd: desktop, encoding: 'utf8', stdio: 'pipe', env: { ...process.env, GITHUB_ACTIONS: '' } });
const officialFiles = (dir = official): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap(e => (e.isDirectory() ? officialFiles(join(dir, e.name)) : [join(dir, e.name)]));

// One test, in order: the official build first, then the community build, so app/dist ends as the default.
test('--official assembles desktop/official-visuals/; the default community build contains none of it', () => {
  build('--official');
  assert.equal(JSON.parse(read('build-edition.json')).edition, 'official');
  assert.equal(read('VISUAL-LICENSE.md'), readFileSync(join(official, 'LICENSE.md'), 'utf8'));
  assert.ok(read('app.css').endsWith(readFileSync(join(official, 'theme.css'), 'utf8')));
  assert.ok(read('main.js').includes('M0-8.2C2.8-6.2'), 'official logo is bundled');

  build();
  assert.equal(JSON.parse(read('build-edition.json')).edition, 'community');
  assert.ok(!existsSync(join(dist, 'VISUAL-LICENSE.md')));
  assert.equal(read('app.css'), readFileSync(join(desktop, 'app/style.css'), 'utf8'));
  const out = readdirSync(dist).map(f => readFileSync(join(dist, f)));
  for (const f of officialFiles()) {
    const bytes = readFileSync(f);
    assert.ok(!out.some(o => o.equals(bytes)), 'community build contains ' + f);
  }
  const js = read('main.js');
  assert.ok(!js.includes('M0-8.2C2.8-6.2') && !js.includes('LicenseRef-ModelPlan-Visuals'), 'community bundle carries official visuals');
});

test('an external visual package must lie outside the checkout', () => {
  assert.throws(() => build('--visual-package', official), /external_visual_package_must_be_outside_public_checkout/);
  assert.throws(() => build('--official', 'extra'), /usage/);
});
