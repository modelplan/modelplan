import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const pin = JSON.parse(await readFile(join(root, 'cli-pin.json'), 'utf8'));
const cli = (version, run = `printf '%s\\n' "$@" > "$HOME/args"; echo '{"hints":1}'`) => `#!/bin/sh\ncase "$1" in version) echo "modelplan ${version}";; *) ${run};; esac\n`;

// No test downloads anything: the pinned copy is already in place, or a fetch failed recently
// (then the background fetch waits 10 minutes), or fetching is off.
async function setup({ fetch = false } = {}) {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-cc-'));
  const env = { PATH: '/usr/bin:/bin', HOME: home, MODELPLAN_CACHE: join(home, 'mpcache'), ...(fetch ? {} : { MODELPLAN_PLUGIN_CLI: 'off' }) };
  const sh = (script, input = '{"session_id":"s"}', args = []) => execFileSync('sh', [join(root, 'hooks', script), ...args], { env, input, encoding: 'utf8' });
  const put = async (dir, body) => { await mkdir(dir, { recursive: true }); await writeFile(join(dir, 'modelplan'), body); await chmod(join(dir, 'modelplan'), 0o755); return join(dir, 'modelplan'); };
  const cliRoot = join(home, '.cache/modelplan-cli');
  return {
    home, env, sh, state: join(home, '.cache/modelplan-claude-code'), cliRoot,
    pinned: (body = cli(pin.version)) => put(join(cliRoot, pin.version), body),
    install: version => put(join(home, '.local/bin'), cli(version)),
    fetchFailed: async why => { await mkdir(cliRoot, { recursive: true }); await writeFile(join(cliRoot, 'fetch-result'), `${pin.version} failed: ${why}\n`); },
  };
}

test('a prompt hook and a SessionStart hook after compaction; the CLI pin is the release the scripts read', async () => {
  const { hooks } = JSON.parse(await readFile(join(root, 'hooks/hooks.json'), 'utf8'));
  assert.deepEqual(Object.keys(hooks), ['UserPromptSubmit', 'SessionStart']);
  const [{ hooks: [h] }] = hooks.UserPromptSubmit;
  assert.equal(h.command, 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/modelplan-quota-hints.sh"');
  const [{ matcher, hooks: [s] }] = hooks.SessionStart;
  assert.equal(matcher, 'compact|resume');
  assert.equal(s.command, 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"');
  assert.match(pin.version, /^\d+\.\d+\.\d+$/);
  assert.equal(pin.release, `https://github.com/modelplan/modelplan/releases/download/v${pin.version}`);
  for (const k of ['darwin_arm64', 'darwin_amd64', 'linux_arm64', 'linux_amd64']) assert.match(pin.sha256[k], /^[0-9a-f]{64}$/, k);
  for (const f of ['fetch-cli.sh', 'find-cli.sh'])
    assert.equal(await readFile(join(root, 'hooks', f), 'utf8'), await readFile(join(root, '../codex/hooks', f), 'utf8'), `${f} is shared with the Codex plugin`);
  assert.equal(await readFile(join(root, 'cli-pin.json'), 'utf8'), await readFile(join(root, '../codex/cli-pin.json'), 'utf8'), 'both plugins pin the same CLI');
});

test('commands reach the CLI through the plugin, never a bare modelplan on PATH', async () => {
  for (const f of await readdir(join(root, 'commands'))) {
    const md = await readFile(join(root, 'commands', f), 'utf8');
    for (const [, line] of md.matchAll(/!`([^`]*)`/g)) {
      assert.match(line, /^sh "\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/[a-z-]+\.sh"/, `${f}: ${line}`);
      assert.ok((await stat(join(root, 'hooks', line.match(/hooks\/([a-z-]+\.sh)/)[1]))).isFile());
    }
  }
});

test('the pinned copy comes first, is announced once, and needs no question', async () => {
  const { home, sh, state, pinned, install } = await setup();
  await install('9.9.9'); // a newer CLI the user installed does not win over the plugin's own
  const p = await pinned();
  await mkdir(state, { recursive: true });
  await writeFile(join(state, 'statusline-declined'), '');
  assert.equal(sh('find-cli.sh', ''), p + '\n');
  assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
  const args = (await readFile(join(home, 'args'), 'utf8')).split('\n');
  assert.deepEqual(args.slice(0, 4), ['advise', '--hook', 'claude-code', '--add-system']);
  assert.match(args[4], new RegExp(`已就绪插件配套的 modelplan CLI ${pin.version.replace(/\./g, '\\.')}`));
  sh('modelplan-quota-hints.sh');
  assert.equal(await readFile(join(home, 'args'), 'utf8'), 'advise\n--hook\nclaude-code\n', 'announced once');
  await rm(home, { recursive: true });
});

test('not fetched yet: quiet, no question; a failed fetch says why, at most weekly', async () => {
  const { home, sh, state, cliRoot, fetchFailed } = await setup({ fetch: true });
  // Another pin's failure is not this one's: say nothing, and do not reach the network.
  await mkdir(cliRoot, { recursive: true });
  await writeFile(join(cliRoot, 'fetch-result'), '0.0.1 failed: older pin\n');
  await mkdir(join(cliRoot, `.lock-${pin.version}`)); // a fetch "in progress"
  assert.equal(sh('modelplan-quota-hints.sh'), '');
  assert.match(await readFile(join(state, 'hook-result'), 'utf8'), /^skipped: cli not ready/);
  assert.match(sh('setup-status.sh', ''), /^cli: the plugin's CLI [\d.]+ is not fetched yet/m);
  await fetchFailed('download failed (curl: (6) Could not resolve host; network, proxy or GitHub unreachable)');
  const n = JSON.parse(sh('modelplan-quota-hints.sh'));
  assert.match(n.systemMessage, /没能下载插件配套的 modelplan CLI[\s\S]*download failed[\s\S]*\/modelplan:setup/);
  assert.equal(n.hookSpecificOutput, undefined, 'shown to the user only; the model never hears of setup');
  assert.equal(sh('modelplan-quota-hints.sh'), '', 'not again within a week');
  assert.match(sh('setup-status.sh', ''), /^cli: fetch of the plugin's CLI [\d.]+ failed: download failed/m);
  await rm(home, { recursive: true });
});

test('a user-installed older CLI keeps giving hints while the pinned one is not there', async () => {
  const { home, sh, install, fetchFailed } = await setup({ fetch: true });
  await install('0.5.5');
  await fetchFailed('checksum mismatch (got abc); nothing installed');
  assert.match(JSON.parse(sh('modelplan-quota-hints.sh')).systemMessage, /checksum mismatch/, 'the failure is told');
  assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 }, 'then its own hints');
  assert.match(sh('setup-status.sh', ''), /^cli: 0\.5\.5 at .* is older than the plugin's [\d.]+; fetching [\d.]+ failed: checksum mismatch/m);
  await rm(home, { recursive: true });
});

test('fetching off: a CLI the user installed is used, and nothing is said', async () => {
  const { home, sh, state, install } = await setup();
  await install(pin.version);
  await mkdir(state, { recursive: true });
  await writeFile(join(state, 'statusline-declined'), '');
  assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
  assert.match(sh('setup-status.sh', ''), /^cli: ok [\d.]+, installed by you at .*\.local\/bin\/modelplan$/m);
  await rm(home, { recursive: true });
});

test('automatic hints default on, persist off/on, and leave explicit commands available', async () => {
  const { home, sh, state, pinned } = await setup({ fetch: true });
  try {
    assert.equal(sh('automatic-hints.sh', '', ['status']), 'automatic-hints: on\n');
    assert.equal(sh('automatic-hints.sh', '', ['off']), 'automatic-hints: off\n');
    assert.equal(sh('modelplan-quota-hints.sh'), '', 'no output even with a missing CLI');
    await assert.rejects(stat(state), 'off does not run or fetch a CLI');
    await pinned();
    assert.equal(sh('modelplan-quota-hints.sh'), '', 'off survives a new hook invocation');
    await assert.rejects(stat(join(home, 'args')), 'CLI not called by disabled hook');
    assert.match(sh('setup-status.sh', ''), /^automatic-hints: off$/m);
    assert.match(sh('setup-status.sh', ''), /^hints: off by choice/m);
    assert.deepEqual(JSON.parse(sh('run-cli.sh', '', ['lineup', '--json'])), { hints: 1 });
    assert.equal(await readFile(join(home, 'args'), 'utf8'), 'lineup\n--json\n');
    assert.equal(sh('automatic-hints.sh', '', ['on']), 'automatic-hints: on\n');
    assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
    assert.throws(() => sh('automatic-hints.sh', '', ['invalid']));
    assert.equal(sh('automatic-hints.sh', '', ['status']), 'automatic-hints: on\n');
  } finally { await rm(home, { recursive: true }); }
});

test('an absent status line is optional and never nags during prompts', async () => {
  const { home, sh, state, pinned } = await setup();
  try {
    await pinned();
    await mkdir(state, { recursive: true });
    await writeFile(join(state, `announced-${pin.version}`), '');
    assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
    assert.equal(await readFile(join(home, 'args'), 'utf8'), 'advise\n--hook\nclaude-code\n');
    assert.match(sh('setup-status.sh', ''), /^statusline: optional display, not set up/m);
    assert.match(sh('setup-status.sh', ''), /^hints: computed on the last run/m);
  } finally { await rm(home, { recursive: true }); }
});

test('a failing CLI run is recorded with its exit code and never shown as working', async () => {
  const { home, sh, state, pinned } = await setup();
  await pinned(cli(pin.version, 'echo "cache unreadable" >&2; exit 7'));
  await mkdir(state, { recursive: true });
  for (const f of ['statusline-declined', `announced-${pin.version}`]) await writeFile(join(state, f), '');
  assert.equal(sh('modelplan-quota-hints.sh'), '', 'the prompt goes on');
  assert.equal((await readFile(join(state, 'hook-result'), 'utf8')).trim(), 'failed: exit 7: cache unreadable');
  const s = sh('setup-status.sh', '');
  assert.match(s, /^cli: ok [\d.]+, the plugin's own copy/m);
  assert.match(s, /^hook: last ran 0 min ago on this machine \(any session\), plugin [\d.]+, result: failed: exit 7: cache unreadable$/m);
  assert.match(s, /^hook-last-success: never$/m);
  assert.match(s, /^hints: failing/m);
  await rm(home, { recursive: true });
});

test('fetch-cli records why it failed and leaves no CLI behind', async () => {
  const { home } = await setup();
  const plug = join(home, 'plug');
  await mkdir(join(plug, 'hooks'), { recursive: true });
  await writeFile(join(plug, 'hooks/fetch-cli.sh'), await readFile(join(root, 'hooks/fetch-cli.sh')));
  const zero = '0'.repeat(64);
  await writeFile(join(plug, 'cli-pin.json'), `{\n  "version": "9.9.9",\n  "release": "https://127.0.0.1:9/none",\n  "sha256": {\n    "darwin_arm64": "${zero}",\n    "darwin_amd64": "${zero}",\n    "linux_arm64": "${zero}",\n    "linux_amd64": "${zero}"\n  }\n}\n`);
  const env = { PATH: '/usr/bin:/bin', HOME: home };
  assert.throws(() => execFileSync('sh', [join(plug, 'hooks/fetch-cli.sh')], { env, encoding: 'utf8', stdio: 'pipe' }));
  assert.match(await readFile(join(home, '.cache/modelplan-cli/fetch-result'), 'utf8'), /^9\.9\.9 failed: (download failed|unsupported)/);
  await assert.rejects(stat(join(home, '.cache/modelplan-cli/9.9.9/modelplan')));
  // Background mode does not retry a fresh failure, and off means off.
  assert.equal(execFileSync('sh', ['-c', `sh "${join(plug, 'hooks/fetch-cli.sh')}" --background; echo $?`], { env, encoding: 'utf8' }).trim(), '1');
  assert.equal(execFileSync('sh', ['-c', `sh "${join(plug, 'hooks/fetch-cli.sh')}"; echo $?`], { env: { ...env, MODELPLAN_PLUGIN_CLI: 'off' }, encoding: 'utf8' }).trim(), '1');
  await rm(home, { recursive: true });
});

test('setup lists the other plans read through CodexBar, as the CLI reports them', async () => {
  const { home, sh, pinned } = await setup();
  await pinned(cli(pin.version, `[ "$1" = codexbar ] && printf 'CodexBar CLI: /c/CodexBarCLI (pinned 0.76.0)\\n  zai          ok\\n  cursor       unavailable no session\\n               → signed in to cursor.com\\n'`));
  const out = sh('setup-status.sh', '');
  assert.match(out, /^codexbar \(other plans, optional\):\n  CodexBar CLI: \/c\/CodexBarCLI \(pinned 0\.76\.0\)\n    zai {10}ok\n    cursor {7}unavailable no session\n/m);
  await rm(home, { recursive: true });
});

test('after compaction the pinned CLI gets the SessionStart input; nothing else runs or is recorded', async () => {
  const { home, sh, state, pinned, install } = await setup();
  const input = '{"session_id":"s","hook_event_name":"SessionStart","source":"compact"}';
  assert.equal(sh('session-start.sh', input), '', 'no CLI yet: silent');
  await install('0.0.1');
  assert.equal(sh('session-start.sh', input), '', 'an older CLI would read the input as a prompt');
  const sessionCli = (await readFile(join(root, 'hooks/session-start.sh'), 'utf8')).match(/^session_cli=(\S+)$/m)[1];
  assert.equal((await readFile(join(root, '../codex/hooks/session-start.sh'), 'utf8')).match(/^session_cli=(\S+)$/m)[1], sessionCli, 'both plugins need the same CLI');
  await pinned(cli('0.5.50', 'echo bad'));
  assert.equal(sh('session-start.sh', input), '', 'a CLI before SessionStart support is never asked, even when pinned');
  await pinned(cli(sessionCli, `cat > "$HOME/input"; printf '%s\\n' "$@" > "$HOME/args"; echo '{"resent":1}'`));
  assert.deepEqual(JSON.parse(sh('session-start.sh', input)), { resent: 1 });
  assert.equal(await readFile(join(home, 'input'), 'utf8'), input);
  assert.deepEqual((await readFile(join(home, 'args'), 'utf8')).trim().split('\n'), ['advise', '--hook', 'claude-code']);
  await assert.rejects(stat(state), 'records nothing');
  await mkdir(join(home, '.config/modelplan/claude-code'), { recursive: true });
  await writeFile(join(home, '.config/modelplan/claude-code/automatic-hints'), 'off');
  assert.equal(sh('session-start.sh', input), '', 'automatic hints off');
});
