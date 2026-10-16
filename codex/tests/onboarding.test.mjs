import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findCli } from '../quota.mjs';
import { installCli } from '../install.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const fakeCli = async dir => {
  await mkdir(dir, { recursive: true });
  await writeFile(join(dir, 'modelplan'), '#!/bin/sh\necho "fake $*"\n');
  await chmod(join(dir, 'modelplan'), 0o755);
  return join(dir, 'modelplan');
};

test('the native manifest is what Codex reads: no Agent Plugins $schema, hooks and onboarding resolve', async () => {
  const manifest = JSON.parse(await readFile(join(root, '.codex-plugin/plugin.json'), 'utf8'));
  const pkg = JSON.parse(await readFile(join(root, 'package.json'), 'utf8'));
  // With the agent-plugins.org $schema Codex treats the plugin as an Agent Plugin and skips its hooks.
  assert.equal(manifest.$schema, undefined);
  await assert.rejects(stat(join(root, 'plugin.json')), 'a root plugin.json would shadow the native manifest');
  assert.equal(manifest.version, pkg.version);
  for (const p of [manifest.hooks, manifest.mcpServers, manifest.extensions['com.openai'].onboardingSkill, manifest.interface.logo])
    assert.ok((await stat(join(root, p))).isFile(), p);
});

test('the bundled installer is the repository install.sh', async () => {
  assert.equal(await readFile(join(root, 'install-cli.sh'), 'utf8'), await readFile(join(root, '../install.sh'), 'utf8'));
});

test('findCli looks past a short PATH into ~/.local/bin', async () => {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-cli-'));
  assert.equal(findCli({ env: { PATH: '' }, home, platform: 'linux' }), null);
  const bin = await fakeCli(join(home, '.local/bin'));
  assert.equal(findCli({ env: { PATH: '/usr/bin' }, home, platform: 'linux' }), bin);
  await rm(home, { recursive: true });
});

test('install runs only when needed and reports a failure with the manual command', async () => {
  let ran = 0;
  assert.equal((await installCli({ platform: 'win32', run: async () => ran++ })).status, 'unsupported');
  assert.equal((await installCli({ platform: 'linux', find: () => '/x/modelplan', run: async () => ran++ })).status, 'present');
  assert.equal(ran, 0);
  let found = null;
  const ok = await installCli({ platform: 'darwin', find: () => found, run: async () => { found = '/h/.local/bin/modelplan'; return { code: 0, output: 'Installed' }; } });
  assert.deepEqual([ok.status, ok.path], ['installed', '/h/.local/bin/modelplan']);
  const bad = await installCli({ platform: 'linux', find: () => null, run: async () => ({ code: 1, output: 'curl: (6)' }) });
  assert.equal(bad.status, 'failed');
  assert.match(bad.command, /install\.sh \| sh$/);
});

test('session hook: a notice at most once a week without the CLI, nothing with it', async () => {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-hook-'));
  const env = { PATH: '/usr/bin:/bin', HOME: home, PLUGIN_ROOT: root, PLUGIN_DATA: join(home, 'data') };
  const run = (script, e = env) => execFileSync('sh', [join(root, 'hooks', script)], { env: e, input: '{}', encoding: 'utf8' });
  const first = JSON.parse(run('cli-hint.sh'));
  assert.match(first.systemMessage, /modelplan CLI/);
  assert.equal(first.hookSpecificOutput.hookEventName, 'SessionStart');
  assert.equal(run('cli-hint.sh'), '', 'shown once a week');
  assert.equal(run('advise.sh'), '', 'no CLI, no hints, no error');
  await fakeCli(join(home, '.local/bin'));
  await rm(join(home, 'data'), { recursive: true });
  assert.equal(run('cli-hint.sh'), '', 'CLI in ~/.local/bin is found even off PATH');
  assert.equal(run('advise.sh').trim(), 'fake advise --hook codex');
  await rm(home, { recursive: true });
});
