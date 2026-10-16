import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = (version) => `#!/bin/sh\ncase "$1" in version) echo "modelplan ${version}";; *) printf '%s\\n' "$@" > "$HOME/args"; echo '{"hints":1}';; esac\n`;

async function setup() {
  const home = await mkdtemp(join(tmpdir(), 'modelplan-cc-'));
  const env = { PATH: '/usr/bin:/bin', HOME: home, MODELPLAN_CACHE: join(home, 'mpcache') };
  const sh = (script, input = '{"session_id":"s"}') => execFileSync('sh', [join(root, 'hooks', script)], { env, input, encoding: 'utf8' });
  const install = async (version) => {
    await mkdir(join(home, '.local/bin'), { recursive: true });
    await writeFile(join(home, '.local/bin/modelplan'), cli(version));
    await chmod(join(home, '.local/bin/modelplan'), 0o755);
  };
  return { home, env, sh, install, state: join(home, '.cache/modelplan-claude-code') };
}

test('one hook, on UserPromptSubmit, pointing at a script that exists', async () => {
  const { hooks } = JSON.parse(await readFile(join(root, 'hooks/hooks.json'), 'utf8'));
  assert.deepEqual(Object.keys(hooks), ['UserPromptSubmit']);
  const [{ hooks: [h] }] = hooks.UserPromptSubmit;
  assert.equal(h.command, 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/modelplan-quota-hints.sh"');
  assert.ok((await stat(join(root, 'hooks/modelplan-quota-hints.sh'))).isFile());
  const manifest = JSON.parse(await readFile(join(root, '.claude-plugin/plugin.json'), 'utf8'));
  const lib = await readFile(join(root, 'hooks/setup-lib.sh'), 'utf8');
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/);
  assert.match(lib, /min_cli=\d+\.\d+\.\d+/);
});

test('commands reach the CLI through the plugin, never a bare modelplan on PATH', async () => {
  for (const f of await readdir(join(root, 'commands'))) {
    const md = await readFile(join(root, 'commands', f), 'utf8');
    for (const [, line] of md.matchAll(/!`([^`]*)`/g)) {
      assert.match(line, /^sh "\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/[a-z-]+\.sh"/, `${f}: ${line}`);
      const script = line.match(/hooks\/([a-z-]+\.sh)/)[1];
      assert.ok((await stat(join(root, 'hooks', script))).isFile(), script);
    }
  }
});

test('no CLI: a notice that asks once, then weekly without asking, quiet after "not now"', async () => {
  const { home, sh, state } = await setup();
  const first = JSON.parse(sh('modelplan-quota-hints.sh'));
  assert.match(first.systemMessage, /未检测到可选的 modelplan CLI[\s\S]*\/modelplan:setup/);
  assert.equal(first.hookSpecificOutput.hookEventName, 'UserPromptSubmit');
  assert.match(first.hookSpecificOutput.additionalContext, /ask whether to install[\s\S]*cli-declined/);
  const manifest = JSON.parse(await readFile(join(root, '.claude-plugin/plugin.json'), 'utf8'));
  assert.equal((await readFile(join(state, 'hook-ran'), 'utf8')).trim(), manifest.version, 'heartbeat names the plugin version');
  assert.equal(sh('modelplan-quota-hints.sh'), '', 'not again within a week');
  await rm(join(state, 'notice-missing'));
  assert.match(JSON.parse(sh('modelplan-quota-hints.sh')).hookSpecificOutput.additionalContext, /only if the user asks/);
  await rm(join(state, 'notice-missing'));
  await writeFile(join(state, 'cli-declined'), '');
  assert.equal(sh('modelplan-quota-hints.sh'), '', 'declined: quiet');
  await rm(home, { recursive: true });
});

test('an outdated CLI off PATH: the upgrade notice when due, its own hints otherwise', async () => {
  const { home, sh, install } = await setup();
  await install('0.5.5');
  assert.match(JSON.parse(sh('modelplan-quota-hints.sh')).systemMessage, /0\.5\.5 低于 0\.5\.6/);
  assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
  assert.equal(await readFile(join(home, 'args'), 'utf8'), 'advise\n--hook\nclaude-code\n');
  await rm(home, { recursive: true });
});

test('a current CLI: the status-line notice rides with its hints once, then plain hints', async () => {
  const { home, env, sh, install, state } = await setup();
  await install('0.5.6');
  assert.deepEqual(JSON.parse(sh('modelplan-quota-hints.sh')), { hints: 1 });
  const args = (await readFile(join(home, 'args'), 'utf8')).split('\n');
  assert.deepEqual(args.slice(0, 3), ['advise', '--hook', 'claude-code']);
  assert.equal(args[3], '--add-system');
  assert.match(args.slice(4).join('\n'), /\/modelplan:statusline[\s\S]*--add-context[\s\S]*statusline-declined/);
  sh('modelplan-quota-hints.sh');
  assert.equal(await readFile(join(home, 'args'), 'utf8'), 'advise\n--hook\nclaude-code\n', 'not again within a week');
  // Once the status line records, no notice even when one would be due.
  await rm(join(state, 'notice-statusline'));
  await mkdir(join(env.MODELPLAN_CACHE, 'observed'), { recursive: true });
  await writeFile(join(env.MODELPLAN_CACHE, 'observed/claude-code.json'), '{"windows": []}');
  sh('modelplan-quota-hints.sh');
  assert.equal(await readFile(join(home, 'args'), 'utf8'), 'advise\n--hook\nclaude-code\n');
  await rm(home, { recursive: true });
});

test('setup status reports each part on its own line', async () => {
  const { home, sh, install } = await setup();
  let s = sh('setup-status.sh', '');
  assert.match(s, /^cli: missing/m);
  assert.match(s, /^statusline: not set up/m);
  assert.match(s, /^hook: has not run yet/m);
  assert.match(s, /^hints: off/m);
  await install('0.5.5');
  assert.match(sh('setup-status.sh', ''), /^cli: outdated 0\.5\.5 .*needs 0\.5\.6/m);
  await install('0.5.6');
  sh('modelplan-quota-hints.sh');
  s = sh('setup-status.sh', '');
  assert.match(s, /^cli: ok 0\.5\.6 at .*\.local\/bin\/modelplan$/m);
  assert.match(s, /^cli-path: not on this shell's PATH/m);
  assert.match(s, /^hook: last ran 0 min ago/m);
  assert.match(s, /^hints: task-start brief on; quota hints wait for the status line$/m);
  assert.equal(sh('run-cli.sh', ''), '{"hints":1}\n');
  await rm(home, { recursive: true });
});
