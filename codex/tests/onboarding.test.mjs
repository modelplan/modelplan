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
  assert.equal((await installCli({ platform: 'linux', status: async () => ({ status: 'ok', path: '/x/modelplan', version: '0.5.4' }), run: async () => ran++ })).status, 'present');
  assert.equal(ran, 0);
  let found = null;
  const ok = await installCli({ platform: 'darwin', status: async () => found ? { status: 'ok', path: found, version: '0.5.4' } : { status: 'missing' }, run: async () => { found = '/h/.local/bin/modelplan'; return { code: 0, output: 'Installed' }; } });
  assert.deepEqual([ok.status, ok.path], ['installed', '/h/.local/bin/modelplan']);
  const bad = await installCli({ platform: 'linux', status: async () => ({ status: 'missing' }), run: async () => ({ code: 1, output: 'curl: (6)' }) });
  assert.equal(bad.status, 'failed');
  assert.match(bad.command, /install\.sh \| sh$/);
});

test('one hook: hints with a current CLI, a setup notice without one, asked once, quiet after "not now"', async () => {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-hook-'));
  const env = { PATH: '/usr/bin:/bin', HOME: home, PLUGIN_ROOT: root };
  const run = () => execFileSync('sh', [join(root, 'hooks/modelplan-quota-hints.sh')], { env, input: '{"session_id":"t"}', encoding: 'utf8' });
  const state = join(home, '.cache/modelplan-codex');
  const first = JSON.parse(run());
  assert.match(first.systemMessage, /未检测到可选的 modelplan CLI[\s\S]*not installed/);
  assert.equal(first.hookSpecificOutput.hookEventName, 'UserPromptSubmit');
  assert.match(first.hookSpecificOutput.additionalContext, /ask whether to install[\s\S]*run nothing for it/, 'the first notice asks the model to ask once');
  assert.ok((await stat(join(state, 'hook-ran'))).isFile(), 'every run leaves a heartbeat for the dashboard');
  assert.equal(run(), '', 'not again within a week');
  await rm(join(state, 'notice-missing'));
  const later = JSON.parse(run());
  assert.match(later.hookSpecificOutput.additionalContext, /only if the user asks/, 'later notices do not ask again');
  await rm(join(state, 'notice-missing'));
  await writeFile(join(state, 'cli-declined'), '');
  assert.equal(run(), '', 'declined: quiet');

  // An outdated CLI off PATH: the upgrade notice when due, the CLI's own hints otherwise.
  await rm(join(state, 'cli-declined'));
  const bin = join(home, '.local/bin');
  await mkdir(bin, { recursive: true });
  await writeFile(join(bin, 'modelplan'), '#!/bin/sh\ncase "$1" in version) echo "modelplan 0.5.1";; *) echo "{\\"hints\\":\\"$*\\"}";; esac\n');
  await chmod(join(bin, 'modelplan'), 0o755);
  const up = JSON.parse(run());
  assert.match(up.systemMessage, /0\.5\.1 低于 0\.5\.5/);
  assert.deepEqual(JSON.parse(run()), { hints: 'advise --hook codex' });
  await writeFile(join(bin, 'modelplan'), '#!/bin/sh\ncase "$1" in version) echo "modelplan 0.5.5";; *) echo "{\\"hints\\":\\"$*\\"}";; esac\n');
  await rm(join(state, 'notice-outdated'));
  assert.deepEqual(JSON.parse(run()), { hints: 'advise --hook codex' }, 'a current CLI: hints only, never a notice');
  await rm(home, { recursive: true });
});

test('a short "no" right after the ask is recorded by the hook, nothing else', async () => {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-reply-'));
  const env = { PATH: '/usr/bin:/bin', HOME: home, PLUGIN_ROOT: root };
  const say = prompt => execFileSync('sh', [join(root, 'hooks/modelplan-quota-hints.sh')], { env, input: JSON.stringify({ session_id: 't', prompt }), encoding: 'utf8' });
  const state = join(home, '.cache/modelplan-codex');
  say('hi');
  assert.equal(say('now fix the build'), '', 'a request is not a "no"');
  await assert.rejects(stat(join(state, 'cli-declined')));
  await rm(join(state, 'asked-missing'));
  await rm(join(state, 'notice-missing'));
  say('hi');
  const ack = JSON.parse(say('暂时不用'));
  assert.match(ack.systemMessage, /已记下/);
  assert.match(ack.hookSpecificOutput.additionalContext, /declined[\s\S]*run nothing/);
  assert.ok((await stat(join(state, 'cli-declined'))).isFile());
  await rm(home, { recursive: true });
});

test('setup status keeps each part apart and install verifies the version it ends with', async () => {
  const { setupStatus, decline, cliStatus, atLeast } = await import('../setup.mjs');
  const home = await mkdtemp(join(tmpdir(), 'modelplan-setup-'));
  let s = await setupStatus({ home, find: () => null });
  assert.deepEqual([s.cli.status, s.hook.lastRun, s.declined], ['missing', null, false]);
  await mkdir(join(home, '.cache/modelplan-codex'), { recursive: true });
  await writeFile(join(home, '.cache/modelplan-codex/hook-ran'), '0.12.0');
  s = await setupStatus({ home, find: () => null, pluginVersion: '0.13.0' });
  assert.deepEqual([s.hook.version, s.hook.current], ['0.12.0', false], 'an update whose hook has not run yet');
  assert.equal((await setupStatus({ home, find: () => null, pluginVersion: '0.12.0' })).hook.current, true);
  await decline({ home });
  assert.equal((await setupStatus({ home, find: () => null })).declined, true);
  assert.equal((await cliStatus({ find: () => '/x/modelplan', exec: async () => 'modelplan 0.5.1\n' })).status, 'outdated');
  assert.equal((await cliStatus({ find: () => '/x/modelplan', exec: async () => { throw Error('exec format error'); } })).status, 'failed');
  assert.ok(atLeast('0.10.0', '0.5.4') && !atLeast('0.5.3', '0.5.4'));
  // Install ran, but an older copy is still found first: reported as a failure, with where.
  const stuck = await installCli({ platform: 'darwin', run: async () => ({ code: 0, output: 'Installed' }), status: async () => ({ status: 'outdated', path: '/usr/local/bin/modelplan', version: '0.5.1' }) });
  assert.equal(stuck.status, 'failed');
  assert.match(stuck.output, /older modelplan 0\.5\.1 at \/usr\/local\/bin/);
  let n = 0;
  const upgraded = await installCli({ platform: 'linux', run: async () => ({ code: 0, output: '' }), status: async () => (n++ ? { status: 'ok', path: '/h/.local/bin/modelplan', version: '0.5.4' } : { status: 'outdated', version: '0.5.1' }) });
  assert.deepEqual([upgraded.status, upgraded.version], ['upgraded', '0.5.4']);
  await rm(home, { recursive: true });
});
