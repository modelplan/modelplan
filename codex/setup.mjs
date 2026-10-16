// Setup state, each part on its own: the plugin answered (this server runs), its CLI (the pinned
// copy the plugin fetches, or one the user installed: ready, fetching, failed and why, off), and
// the hook (when it last ran on this machine and how that ended; plugins cannot see whether it
// is trusted). Hooks write ~/.cache/modelplan-codex and fetch-cli.sh ~/.cache/modelplan-cli; this
// only reads them.
import { execFile } from 'node:child_process';
import { readdir, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { atLeast, findCli, MIN_CLI, pinnedCli } from './quota.mjs';

export { atLeast, MIN_CLI };
const stateDir = home => join(home, '.cache', 'modelplan-codex');
const run = (cmd, args) => new Promise((resolve, reject) =>
  execFile(cmd, args, { timeout: 5000, windowsHide: true }, (error, stdout) => error ? reject(error) : resolve(stdout)));

async function mtime(p) { try { return (await stat(p)).mtime; } catch { return null; } }

// status: ok (source "plugin" for the pinned copy, "user" for one the user installed at least as
// new), outdated (a user's older copy; the pinned one is not there yet), fetching (nothing usable
// yet, no failure recorded), failed (with why: a failed fetch, or a CLI that does not answer),
// missing (fetching off and nothing installed), unsupported (no fetch on this system).
export async function cliStatus({ exec = run, find = findCli, home = homedir(), env = process.env, platform = process.platform, fetchError } = {}) {
  const path = find();
  const why = await (fetchError ?? (async () => {
    const r = await readFile(join(home, '.cache', 'modelplan-cli', 'fetch-result'), 'utf8').catch(() => '');
    return r.match(new RegExp(`^${MIN_CLI.replace(/\./g, '\\.')} failed: (.*)$`, 'm'))?.[1]?.slice(0, 200) ?? null;
  }))();
  const base = { min: MIN_CLI, fetchError: why, fetchOff: env.MODELPLAN_PLUGIN_CLI === 'off' };
  if (!path) {
    const status = platform !== 'darwin' && platform !== 'linux' ? 'unsupported' : base.fetchOff ? 'missing' : why ? 'failed' : 'fetching';
    return { status, path: null, version: null, ...base, error: status === 'failed' ? why : null };
  }
  try {
    const version = (String(await exec(path, ['version'])).match(/\d+\.\d+\.\d+/) || [])[0] ?? null;
    if (!version) return { status: 'failed', path, version: null, ...base, error: 'no version reported' };
    const source = path === pinnedCli(home) ? 'plugin' : 'user';
    return { status: atLeast(version, MIN_CLI) ? 'ok' : 'outdated', source, path, version, ...base };
  } catch (e) { return { status: 'failed', path, version: null, ...base, error: String(e.message).split('\n')[0].slice(0, 160) }; }
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

// CodexBar, optional and off until the user enables providers (`modelplan codexbar enable cursor
// zai`): what the CLI reports from its own config and cache (it runs nothing for this). Null when
// the CLI is missing, predates it or does not answer.
export async function codexbarStatus({ exec = run, cli } = {}) {
  if (!cli) return null;
  try {
    const s = JSON.parse(await exec(cli, ['codexbar', '--json']));
    if (s?.schemaVersion !== 1 || !Array.isArray(s.enabled)) return null;
    const str = v => typeof v === 'string' && v ? v.slice(0, 400) : null;
    return { enabled: s.enabled.map(String).slice(0, 8), binary: str(s.binary), pinnedVersion: str(s.pinnedVersion), pinned: s.pinned === true, fetch: str(s.fetch),
      providers: (Array.isArray(s.providers) ? s.providers : []).slice(0, 8).map(p => ({ id: String(p.id), name: str(p.name) ?? String(p.id), status: String(p.status), reason: str(p.reason), needs: str(p.needs) })) };
  } catch { return null; }
}

export async function setupStatus({ home = homedir(), definition, ...opts } = {}) {
  const [cli, hook] = await Promise.all([cliStatus({ home, ...opts }), hookStatus({ home, definition })]);
  const codexbar = cli.status === 'ok' || cli.status === 'outdated' ? await codexbarStatus({ exec: opts.exec, cli: cli.path }) : null;
  return { cli, hook, codexbar };
}

// Codex keeps each plugin version in its own directory (…/modelplan-codex/<version>) and an open
// task keeps the server it started with, so after an update a panel can show an old version's
// state. When a newer version sits next to this one, say which is installed and which is running.
export async function pluginUpdate({ version, root = fileURLToPath(new URL('.', import.meta.url)) } = {}) {
  const here = root.replace(/\/+$/, '');
  if (!version || basename(here) !== version) return null;
  const names = await readdir(dirname(here)).catch(() => []);
  const newest = names.filter(n => /^\d+\.\d+\.\d+$/.test(n)).reduce((a, b) => (atLeast(b, a) ? b : a), version);
  return newest !== version ? { running: version, installed: newest } : null;
}
