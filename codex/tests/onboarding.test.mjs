import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findCli, MIN_CLI } from '../quota.mjs';
import { fetchCli, fetchInBackground } from '../install.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const pin = JSON.parse(await readFile(join(root, 'cli-pin.json'), 'utf8'));
const script = (version, run = `printf '%s\\n' "$@" > "$HOME/args"; echo '{"hints":1}'`) => `#!/bin/sh\ncase "$1" in version) echo "modelplan ${version}";; *) ${run};; esac\n`;
const put = async (dir, body) => { await mkdir(dir, { recursive: true }); await writeFile(join(dir, 'modelplan'), body); await chmod(join(dir, 'modelplan'), 0o755); return join(dir, 'modelplan'); };
const home = () => mkdtemp(join(tmpdir(), 'modelplan-codex-'));
const pinnedDir = h => join(h, '.cache/modelplan-cli', pin.version);
const hook = (h, input = '{"session_id":"t"}') => execFileSync('sh', [join(root, 'hooks/modelplan-quota-hints.sh')], { env: { PATH: '/usr/bin:/bin', HOME: h, PLUGIN_ROOT: root }, input, encoding: 'utf8' });

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

test('one CLI pin for the hook, the dashboard and the docs', async () => {
  assert.equal(MIN_CLI, pin.version);
  assert.equal(pin.release, `https://github.com/modelplan/modelplan/releases/download/v${pin.version}`);
  for (const k of ['darwin_arm64', 'darwin_amd64', 'linux_arm64', 'linux_amd64']) assert.match(pin.sha256[k], /^[0-9a-f]{64}$/, k);
  assert.match(await readFile(join(root, 'hooks/modelplan-quota-hints.sh'), 'utf8'), /cli-pin\.json/);
  for (const f of ['README.md', 'README.zh-CN.md', 'skills/setup/SKILL.md']) {
    const text = await readFile(join(root, f), 'utf8');
    for (const [, v] of text.matchAll(/(?:CLI|modelplan) v?(\d+\.\d+\.\d+)/g)) assert.equal(v, pin.version, `${f} names CLI ${v}`);
    assert.doesNotMatch(text, /0\.4\+|install_modelplan_cli.*~\/\.local\/bin|Not now|暂不安装/, f);
  }
});

// Codex review, isolated repro 2: the dashboard picked a non-executable modelplan on PATH while
// the hook's shell found the working one. Both skip it, both prefer the plugin's pinned copy,
// then a current copy over an older one earlier on PATH.
test('the dashboard and the hook pick the same CLI', async () => {
  const h = await home();
  const [broken, old, cur] = [join(h, 'broken'), join(h, 'old'), join(h, '.local/bin')];
  await mkdir(broken, { recursive: true });
  await writeFile(join(broken, 'modelplan'), 'not a program');
  await put(old, script('0.5.1'));
  await put(cur, script(pin.version));
  const PATH = `${broken}:${old}:/usr/bin:/bin`;
  const shell = () => execFileSync('sh', [join(root, 'hooks/find-cli.sh')], { env: { PATH, HOME: h }, encoding: 'utf8' }).trim();
  const both = want => { assert.equal(findCli({ env: { PATH }, home: h, platform: 'linux' }), want); assert.equal(shell(), want); };
  both(join(cur, 'modelplan'));
  const own = await put(pinnedDir(h), script(pin.version));
  both(own);
  await rm(own); await rm(join(cur, 'modelplan'));
  both(join(old, 'modelplan'));
  assert.equal(await readFile(join(root, 'hooks/find-cli.sh'), 'utf8'), await readFile(join(root, '../claude-code/hooks/find-cli.sh'), 'utf8'), 'one finder for both plugins');
  assert.equal(await readFile(join(root, 'hooks/fetch-cli.sh'), 'utf8'), await readFile(join(root, '../claude-code/hooks/fetch-cli.sh'), 'utf8'), 'one fetcher for both plugins');
  await rm(h, { recursive: true });
});

test('the server fetches the pinned CLI in the background; Retry fetches now and says why it failed', async () => {
  const calls = [];
  const run = (cmd, args) => { calls.push([cmd, ...args]); return { unref() {} }; };
  assert.equal(fetchInBackground({ platform: 'darwin', env: {}, run }), true);
  assert.match(calls[0].join(' '), /^sh .*hooks\/fetch-cli\.sh --background$/);
  assert.equal(fetchInBackground({ platform: 'darwin', env: { MODELPLAN_PLUGIN_CLI: 'off' }, run }), false);
  assert.equal(fetchInBackground({ platform: 'win32', env: {}, run }), false);
  assert.equal(calls.length, 1);
  assert.equal((await fetchCli({ platform: 'win32' })).status, 'unsupported');
  assert.equal((await fetchCli({ platform: 'linux', env: { MODELPLAN_PLUGIN_CLI: 'off' } })).status, 'off');
  const ready = await fetchCli({ platform: 'linux', env: {}, run: async () => ({ code: 0, output: '/h/.cache/modelplan-cli/x/modelplan' }), status: async () => ({ status: 'ok', path: '/h/.cache/modelplan-cli/x/modelplan', version: pin.version, source: 'plugin' }) });
  assert.deepEqual([ready.status, ready.source], ['ready', 'plugin']);
  const bad = await fetchCli({ platform: 'linux', env: {}, run: async () => ({ code: 1, output: `modelplan CLI ${pin.version}: checksum mismatch (got abc); nothing installed` }), status: async () => ({ status: 'failed' }) });
  assert.deepEqual([bad.status, bad.reason], ['failed', 'checksum mismatch (got abc); nothing installed']);
});

test('the hook downloads nothing: quiet until the CLI is there, a failed fetch told at most weekly', async () => {
  const h = await home();
  assert.equal(hook(h), '', 'not fetched yet: nothing to say');
  const state = join(h, '.cache/modelplan-codex');
  assert.equal((await readFile(join(state, 'hook-result'), 'utf8')).trim(), 'skipped: cli not ready');
  await mkdir(join(h, '.cache/modelplan-cli'), { recursive: true });
  await writeFile(join(h, '.cache/modelplan-cli/fetch-result'), `${pin.version} failed: download failed (curl: (6) Could not resolve host; network, proxy or GitHub unreachable)\n`);
  const n = JSON.parse(hook(h));
  assert.match(n.systemMessage, /没能下载插件配套的 modelplan CLI[\s\S]*download failed[\s\S]*重试/);
  assert.match(n.hookSpecificOutput.additionalContext, /only if the user asks/);
  assert.doesNotMatch(n.hookSpecificOutput.additionalContext, /ask whether|install it/, 'nothing to consent to');
  assert.equal(hook(h), '', 'not again within a week');
  await assert.rejects(stat(join(h, '.cache/modelplan-cli', pin.version)), 'the hook fetched nothing');
  // A CLI the user installed, older than the pin: its own hints meanwhile.
  await put(join(h, '.local/bin'), script('0.5.5'));
  assert.deepEqual(JSON.parse(hook(h)), { hints: 1 });
  await rm(h, { recursive: true });
});

test('the pinned copy, once there, is announced once with the hints', async () => {
  const h = await home();
  await put(pinnedDir(h), script(pin.version));
  assert.deepEqual(JSON.parse(hook(h)), { hints: 1 });
  const args = (await readFile(join(h, 'args'), 'utf8')).split('\n');
  assert.deepEqual(args.slice(0, 4), ['advise', '--hook', 'codex', '--add-system']);
  assert.match(args[4], /已就绪插件配套的 modelplan CLI/);
  hook(h);
  assert.equal(await readFile(join(h, 'args'), 'utf8'), 'advise\n--hook\ncodex\n');
  await rm(h, { recursive: true });
});

test('setup status: the plugin\'s CLI and the hook, each on its own', async () => {
  const { setupStatus, cliStatus } = await import('../setup.mjs');
  const h = await home();
  const st = (opts = {}) => cliStatus({ home: h, platform: 'linux', env: {}, ...opts });
  assert.equal((await st({ find: () => null })).status, 'fetching');
  assert.deepEqual([(await st({ find: () => null, fetchError: async () => 'download failed' })).status, (await st({ find: () => null, fetchError: async () => 'download failed' })).error], ['failed', 'download failed']);
  assert.equal((await st({ find: () => null, env: { MODELPLAN_PLUGIN_CLI: 'off' } })).status, 'missing');
  assert.equal((await st({ find: () => null, platform: 'win32' })).status, 'unsupported');
  const own = await put(pinnedDir(h), script(pin.version));
  const ss = c => [c.status, c.source];
  assert.deepEqual(ss(await st({ find: () => own })), ['ok', 'plugin']);
  const mine = await put(join(h, 'bin'), script('0.5.5'));
  assert.deepEqual(ss(await st({ find: () => mine })), ['outdated', 'user']);
  assert.equal((await st({ find: () => '/x/modelplan', exec: async () => { throw Error('exec format error'); } })).status, 'failed');
  await mkdir(join(h, '.cache/modelplan-codex'), { recursive: true });
  await writeFile(join(h, '.cache/modelplan-codex/hook-ran'), '0.13.0 def=111\n');
  let s = await setupStatus({ home: h, find: () => own, definition: async () => '222' });
  assert.deepEqual([s.hook.version, s.hook.current, s.hook.trust, s.hook.scope], ['0.13.0', false, 'unknown', 'machine'], 'a changed definition has not run yet');
  assert.equal((await setupStatus({ home: h, find: () => own, definition: async () => '111' })).hook.current, true, 'same definition, any plugin version');
  await writeFile(join(h, '.cache/modelplan-codex/hook-ran'), '0.12.0');
  assert.equal((await setupStatus({ home: h, find: () => own, definition: async () => '111' })).hook.current, null, 'an older heartbeat without a definition: unknown, not stale');
  await rm(h, { recursive: true });
});

// Codex review, isolated repro 1: advise exited 7, the hook still exited 0 (it must not block the
// prompt) and only a heartbeat was left, so the dashboard showed "ran". Start and result are now
// separate, with the exit code and the first error line.
test('a failing CLI run is recorded as a failure, never as a working hook', async () => {
  const h = await home();
  await mkdir(join(h, '.cache/modelplan-codex'), { recursive: true });
  await writeFile(join(h, '.cache/modelplan-codex', `announced-${pin.version}`), '');
  const own = await put(pinnedDir(h), script(pin.version, 'echo "publication cache unreadable" >&2; exit 7'));
  assert.equal(hook(h), '', 'the prompt goes on');
  const state = join(h, '.cache/modelplan-codex');
  assert.equal((await readFile(join(state, 'hook-result'), 'utf8')).trim(), 'failed: exit 7: publication cache unreadable');
  await assert.rejects(stat(join(state, 'hook-ok')), 'no success recorded');
  const { setupStatus } = await import('../setup.mjs');
  const s = await setupStatus({ home: h, find: () => own });
  assert.match(s.hook.result, /^failed: exit 7/);
  assert.equal(s.hook.lastSuccess, null);
  assert.match(s.hook.definition, /^\d+$/, 'the heartbeat names the hook definition');
  assert.equal(s.hook.current, true);
  const { renderQuota } = await import('../render.mjs');
  const text = renderQuota({ status: 'unavailable' }, 'zh', { status: 'ok', events: [] }, { cli: s.cli, hook: s.hook, advice: { status: 'ok' }, adviceEvents: 0 });
  assert.match(text, /提醒计算失败（exit 7: publication cache unreadable），最近一次成功：从未/);
  assert.doesNotMatch(text, /设置完整/);
  await writeFile(own, script(pin.version, 'exit 0'));
  hook(h);
  const ok = await setupStatus({ home: h, find: () => own });
  assert.equal(ok.hook.result, 'ok');
  assert.ok(ok.hook.lastSuccess);
  assert.match(renderQuota({ status: 'unavailable' }, 'zh', { status: 'ok', events: [] }, { cli: ok.cli, hook: ok.hook, advice: { status: 'ok' }, adviceEvents: 0 }),
    /设置完整：CLI [\d.]+ · 钩子 0分前在本机运行（任一对话）· 提醒计算正常，当前没有需要提醒的事/);
  await rm(h, { recursive: true });
});

test('text output names each CLI state without asking to install anything', async () => {
  const { renderQuota } = await import('../render.mjs');
  const line = cli => renderQuota({ status: 'unavailable' }, 'zh', { status: 'unavailable', reason: 'cli_missing', events: [] }, { cli: { min: pin.version, ...cli }, hook: { lastRun: new Date().toISOString(), current: true, result: 'ok' }, advice: { status: 'unavailable' } });
  assert.match(line({ status: 'fetching' }), /正在下载插件配套的 modelplan CLI/);
  assert.match(line({ status: 'failed', path: null, fetchError: 'download failed' }), /下载失败（download failed）；可在看板点“重试”/);
  assert.match(line({ status: 'outdated', version: '0.5.5', path: '/u/modelplan', fetchError: null }), /正在使用你安装的 CLI 0\.5\.5（旧于插件配套的 [\d.]+），配套版本下载好后自动切换/);
  assert.match(line({ status: 'missing' }), /已关闭自动下载/);
  for (const s of ['fetching', 'missing', 'unsupported']) assert.doesNotMatch(line({ status: s }), /安装 CLI|暂不安装|curl/);
});
