// Setup state, each part on its own: the plugin answered (this server runs), the optional CLI
// (missing, outdated, failing or ready), the hook (has it ever run, i.e. is it trusted), and
// whether the user declined the CLI. Hooks write ~/.cache/modelplan-codex; this only reads it,
// except `decline`, which the dashboard's "not now" button calls.
import { execFile } from 'node:child_process';
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { findCli } from './quota.mjs';

export const MIN_CLI = '0.5.5'; // task-start brief and the Codex account reading
const DECLINE_DAYS = 90;
const stateDir = home => join(home, '.cache', 'modelplan-codex');
const run = (cmd, args) => new Promise((resolve, reject) =>
  execFile(cmd, args, { timeout: 5000, windowsHide: true }, (error, stdout) => error ? reject(error) : resolve(stdout)));

export function atLeast(version, min) {
  const a = String(version).split('.').map(Number), b = min.split('.').map(Number);
  for (let i = 0; i < 3; i++) { if ((a[i] || 0) !== (b[i] || 0)) return (a[i] || 0) > (b[i] || 0); }
  return true;
}

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

// hook.current: the hook that last ran came with this plugin version. After an update Codex skips
// a changed hook until it is trusted again, so an older version there means "re-trust may be due".
export async function setupStatus({ home = homedir(), now = new Date(), pluginVersion = null, ...opts } = {}) {
  const dir = stateDir(home);
  const [cli, ran, ranBy, declined] = await Promise.all([cliStatus(opts), mtime(join(dir, 'hook-ran')),
    readFile(join(dir, 'hook-ran'), 'utf8').then(s => s.trim() || null, () => null), mtime(join(dir, 'cli-declined'))]);
  return { cli, hook: { lastRun: ran ? ran.toISOString() : null, version: ranBy, current: !ran || !pluginVersion || ranBy === pluginVersion },
    declined: !!declined && now - declined < DECLINE_DAYS * 86400000 };
}

export async function decline({ home = homedir() } = {}) {
  await mkdir(stateDir(home), { recursive: true });
  await writeFile(join(stateDir(home), 'cli-declined'), '');
  return { declined: true };
}
