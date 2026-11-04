// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInternalVisualReader } from '../lib/internal-visual-allowlist.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const asset = 'desktop/official-visuals/pack/synthetic.txt';
const content = Buffer.from('synthetic visual test bytes\n');
const edition = 'internal-acceptance';
const gitEnv = { PATH: process.env.PATH || '/usr/bin:/bin', GIT_CONFIG_NOSYSTEM: '1',
  GIT_CONFIG_GLOBAL: '/dev/null', GIT_TERMINAL_PROMPT: '0', LC_ALL: 'C' };

function fixture(t) {
  const repository = realpathSync(mkdtempSync(join(tmpdir(), 'm5-internal-visual-')));
  t.after(() => rmSync(repository, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', ['-C', repository, ...args], { encoding: 'utf8', env: gitEnv, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  const directory = join(repository, 'desktop/official-visuals/pack');
  mkdirSync(directory, { recursive: true });
  writeFileSync(join(directory, 'synthetic.txt'), content);
  writeFileSync(join(directory, 'unlisted.txt'), Buffer.from('different synthetic bytes'));
  symlinkSync('synthetic.txt', join(directory, 'link.txt'));
  symlinkSync('pack', join(repository, 'desktop/official-visuals/alias'));
  git('add', '--', 'desktop');
  const root = git('write-tree');
  const assetTree = git('rev-parse', root + ':desktop/official-visuals');
  const blob = git('rev-parse', ':' + asset);
  const linkBlob = git('rev-parse', ':desktop/official-visuals/pack/link.txt');
  const registry = { version: 1, edition, assetTree, entries: [{ path: asset, blob, sha256: hash(content), size: content.length }] };
  const registryBytes = Buffer.from(JSON.stringify(registry));
  const anchors = { repository, assetTree, registrySha256: hash(registryBytes) };
  const read = createInternalVisualReader(anchors);
  const request = changes => ({ edition, path: asset, registryBytes, ...changes });
  const withRegistry = manifest => {
    const bytes = Buffer.from(JSON.stringify(manifest));
    return { read: createInternalVisualReader({ ...anchors, registrySha256: hash(bytes) }), bytes };
  };
  return { repository, directory, git, assetTree, blob, linkBlob, registry, registryBytes, anchors, read, request, withRegistry };
}

test('uses an independently pinned asset subtree and registry; ignores worktree replacement', t => {
  const f = fixture(t);
  assert.deepEqual(f.read(f.request()), content);
  unlinkSync(join(f.directory, 'synthetic.txt'));
  symlinkSync('unlisted.txt', join(f.directory, 'synthetic.txt'));
  assert.deepEqual(f.read(f.request()), content);
});

test('a replacement registry cannot replace the consumer trust anchors', t => {
  const f = fixture(t);
  const replacement = Buffer.from(JSON.stringify({ ...f.registry, entries: [] }));
  assert.throws(() => f.read(f.request({ registryBytes: replacement, registrySha256: hash(replacement), assetTree: f.assetTree })), /rejected/);
  const wrongTree = createInternalVisualReader({ ...f.anchors, assetTree: '0'.repeat(40) });
  assert.throws(() => wrongTree(f.request()), /rejected/);
  assert.deepEqual(f.read(f.request()), content);
});

test('rejects other editions, unlisted paths, traversal and aliases', t => {
  const f = fixture(t);
  for (const edition of ['community', 'official', '', 'internal', undefined])
    assert.throws(() => f.read(f.request({ edition })), /rejected/);
  for (const path of ['desktop/official-visuals/pack/unlisted.txt', '../synthetic.txt',
    'desktop/official-visuals/pack/../pack/synthetic.txt', 'desktop/official-visuals//pack/synthetic.txt',
    'desktop/official-visuals/pack/./synthetic.txt', 'desktop/official-visuals/pack/%73ynthetic.txt',
    'desktop/official-visuals/pack\\synthetic.txt', '/desktop/official-visuals/pack/synthetic.txt'])
    assert.throws(() => f.read(f.request({ path })), /rejected/);
});

test('rejects symlink files and parent components even in a pinned registry', t => {
  const f = fixture(t);
  for (const [path, blob] of [['desktop/official-visuals/pack/link.txt', f.linkBlob], ['desktop/official-visuals/alias/synthetic.txt', f.blob]]) {
    const { read, bytes } = f.withRegistry({ ...f.registry, entries: [{ path, blob, sha256: hash(content), size: content.length }] });
    assert.throws(() => read(f.request({ path, registryBytes: bytes })), /rejected/);
  }
});

test('rejects invalid registry semantics, blob, content hash and size', t => {
  const f = fixture(t);
  for (const registry of [
    { ...f.registry, version: 2 }, { ...f.registry, edition: 'community' },
    { ...f.registry, assetTree: '0'.repeat(40) },
    { ...f.registry, entries: [{ ...f.registry.entries[0], blob: '0'.repeat(40) }] },
    { ...f.registry, entries: [{ ...f.registry.entries[0], sha256: '0'.repeat(64) }] },
    { ...f.registry, entries: [{ ...f.registry.entries[0], size: content.length + 1 }] },
    { ...f.registry, entries: [f.registry.entries[0], f.registry.entries[0]] },
  ]) {
    const { read, bytes } = f.withRegistry(registry);
    assert.throws(() => read(f.request({ registryBytes: bytes })), /rejected/);
  }
});

test('rejects malformed, noncanonical and oversized registry bytes', t => {
  const f = fixture(t);
  for (const bytes of [Buffer.alloc(0), Buffer.alloc(64 * 1024 + 1), Buffer.from('{'),
    Buffer.from('{"version":1,"version":1}'), Buffer.from(' {"version":1}')]) {
    const read = createInternalVisualReader({ ...f.anchors, registrySha256: hash(bytes) });
    assert.throws(() => read(f.request({ registryBytes: bytes })), /rejected/);
  }
});

test('an approved synthetic blob at the asset limit is readable', t => {
  const f = fixture(t);
  const bytes = Buffer.alloc(512 * 1024, 42);
  writeFileSync(join(f.directory, 'large.txt'), bytes);
  f.git('add', '--', 'desktop/official-visuals/pack/large.txt');
  const root = f.git('write-tree');
  const assetTree = f.git('rev-parse', root + ':desktop/official-visuals');
  const path = 'desktop/official-visuals/pack/large.txt';
  const blob = f.git('rev-parse', ':' + path);
  const registryBytes = Buffer.from(JSON.stringify({ version: 1, edition, assetTree, entries: [{ path, blob, size: bytes.length, sha256: hash(bytes) }] }));
  const read = createInternalVisualReader({ repository: f.repository, assetTree, registrySha256: hash(registryBytes) });
  assert.deepEqual(read({ edition, path, registryBytes }), bytes);
});

test('rejects a synthetic asset exceeding the asset limit', t => {
  const f = fixture(t);
  const bytes = Buffer.alloc(512 * 1024 + 1, 42);
  writeFileSync(join(f.directory, 'oversized.txt'), bytes);
  f.git('add', '--', 'desktop/official-visuals/pack/oversized.txt');
  const root = f.git('write-tree');
  const assetTree = f.git('rev-parse', root + ':desktop/official-visuals');
  const path = 'desktop/official-visuals/pack/oversized.txt';
  const blob = f.git('rev-parse', ':' + path);
  const registryBytes = Buffer.from(JSON.stringify({ version: 1, edition, assetTree, entries: [{ path, blob, size: bytes.length, sha256: hash(bytes) }] }));
  const read = createInternalVisualReader({ repository: f.repository, assetTree, registrySha256: hash(registryBytes) });
  assert.throws(() => read({ edition, path, registryBytes }), /rejected/);
});

test('rejects a missing tree object', t => {
  const f = fixture(t);
  const assetTree = '0'.repeat(40);
  const registryBytes = Buffer.from(JSON.stringify({ ...f.registry, assetTree }));
  const read = createInternalVisualReader({ repository: f.repository, assetTree, registrySha256: hash(registryBytes) });
  assert.throws(() => read(f.request({ registryBytes })), /rejected/);
});
