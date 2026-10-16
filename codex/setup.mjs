// Setup state, each part on its own: the plugin answered (this server runs), the optional CLI
// (missing, outdated, failing or ready), the hook (when it last ran on this machine and how that
// ended; plugins cannot see whether it is trusted), and
// whether the user declined the CLI. Hooks write ~/.cache/modelplan-codex; this only reads it,
// except `decline`, which the dashboard's "not now" button calls.
import { execFile } from 'node:child_process';
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { atLeast, findCli, MIN_CLI } from './quota.mjs';

export { atLeast, MIN_CLI };
const DECLINE_DAYS = 90;
const stateDir = home => join(home, '.cache', 'modelplan-codex');
const run = (cmd, args) => new Promise((resolve, reject) =>
  execFile(cmd, args, { timeout: 5000, windowsHide: true }, (error, stdout) => error ? reject(error) : resolve(stdout)));

async function mtime(p) { try { return (await stat(p)).mtime; } catch { return null; } }

export async function cliStatus({ exec = run, find = findCli } = {}) {
  const path = find();
  if (!path) return { status: 'missing', path: null, version: null, min: MIN_CLI };
  try {
    const version = (String(await exec(path, ['version'])).match(/\d+\.\d+\.\d+/) || [])[0] ?? null;
    if (!version) return { status: 'failed', path, version: null, min: MIN_CLI, error: 'no version reported' };
    return { status: atLeast(version, MIN_CLI) ? 'ok' : 'outdated', path, version, min: MIN_CLI };
  } catch (e) { return { status: 'failed', path, version: null, min: MIN_CLI, error: String(e.message).split('\n')[0].slice(0, 160) }; }
}

// The hook as the hook files record it, on this machine and from whichever chat ran last:
//   lastRun / version / definition: its last start (hook-ran: "<plugin version> def=<cksum>");
//   current: that start used the hook definition installed now. Codex skips a changed
//     definition until it is reviewed again, so false means "review due"; a new plugin version
//     with the same definition stays current. Unknown (null) before anything ran;
//   result / lastSuccess: how that run ended (ok, failed with the exit code and error, or why
//     the CLI was not asked) and the last run where the hints were computed.
// Codex does not tell plugins whether a hook is trusted, so trust is reported as unknown.
const hookDefinition = () => new Promise(resolve =>
  execFile('sh', ['-c', 'cksum < "$0" | awk \'{print $1}\'', fileURLToPath(new URL('./hooks/hooks.json', import.meta.url))], { timeout: 3000 }, (e, out) => resolve(e ? null : String(out).trim() || null)));

export async function hookStatus({ home = homedir(), definition = hookDefinition } = {}) {
  const dir = stateDir(home), text = f => readFile(join(dir, f), 'utf8').then(s => s.trim() || null, () => null);
  const [ran, ranBy, result, ok, def] = await Promise.all([mtime(join(dir, 'hook-ran')), text('hook-ran'), text('hook-result'), mtime(join(dir, 'hook-ok')), definition()]);
  const [version, ranDef] = [ranBy?.split(' ')[0] ?? null, ranBy?.match(/def=(\S+)/)?.[1] ?? null];
  return { lastRun: ran ? ran.toISOString() : null, version, definition: ranDef, scope: 'machine', trust: 'unknown',
    current: !ran ? null : ranDef && def ? ranDef === def : null,
    result: result?.split('\n')[0].slice(0, 200) ?? null, lastSuccess: ok ? ok.toISOString() : null };
}

export async function setupStatus({ home = homedir(), now = new Date(), definition, ...opts } = {}) {
  const dir = stateDir(home);
  const [cli, hook, declined] = await Promise.all([cliStatus(opts), hookStatus({ home, definition }), mtime(join(dir, 'cli-declined'))]);
  return { cli, hook, declined: !!declined && now - declined < DECLINE_DAYS * 86400000 };
}

export async function decline({ home = homedir() } = {}) {
  await mkdir(stateDir(home), { recursive: true });
  await writeFile(join(stateDir(home), 'cli-declined'), '');
  return { declined: true };
}
