// The user's own Codex quota, read on this machine only: `modelplan quota --json` when the CLI
// is installed, otherwise the Skill's standard-library reader. Both read the latest rate-limit
// snapshot Codex writes to its session logs; neither opens credentials or calls an account API.
import { execFile, execFileSync } from 'node:child_process';
import { accessSync, constants, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { delimiter, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const READER = fileURLToPath(new URL('./skills/model-plan/scripts/quota.py', import.meta.url));
const run = (cmd, args) => new Promise((resolve, reject) =>
  execFile(cmd, args, { timeout: 8000, maxBuffer: 1 << 20, windowsHide: true }, (error, stdout) => error ? reject(error) : resolve(stdout)));

export function pickCodex(report) {
  if (report?.schemaVersion !== 1 || !Array.isArray(report.accounts)) throw Error('quota_report_invalid');
  const source = report.sources?.find(s => s.source === 'codex') ?? { status: 'missing' };
  const account = thread(report.accounts.find(a => a.source === 'codex') ?? null);
  return { status: account ? 'ok' : source.status, reason: source.reason ?? null, evaluatedAt: report.evaluatedAt, account, others: others(report), note: report.note };
}

// Other plans the user enabled through CodexBar (`modelplan codexbar enable …`), as the CLI cached
// them. Shown under Codex's own quota; hints and advice stay Codex's.
export const OTHER_PLANS = { copilot: 'GitHub Copilot', cursor: 'Cursor', zai: 'Z.ai / GLM Coding Plan', kiro: 'Kiro', opencodego: 'OpenCode Go' };
function others(report) {
  return report.accounts.filter(a => typeof a?.source === 'string' && a.source.startsWith('codexbar:') && Array.isArray(a.windows)).slice(0, 8).map(a => {
    const id = a.source.slice('codexbar:'.length);
    return { id, name: OTHER_PLANS[id] ?? id, plan: a.plan ?? null, stale: a.stale === true, observedAt: a.observedAt ?? null, windows: a.windows.slice(0, 6) };
  });
}

// The MCP server is never told which thread called it, so its reading is at best the most
// recent interactive thread. Readers older than CLI 0.5 did not say so and could return a
// background review's model; drop that and mark unattributed readings as recent.
const BACKGROUND_MODELS = new Set(['codex-auto-review']);
function thread(account) {
  if (!account?.harness) return account;
  const h = account.harness;
  if (BACKGROUND_MODELS.has(h.model) && h.attribution !== 'current-thread') { const { harness, ...rest } = account; return rest; }
  return { ...account, harness: { ...h, attribution: h.attribution ?? 'recent-thread' } };
}

// Proactive hints (reset soon with allowance left, tight, switch back after a reset, public
// resets) come only from the CLI, which remembers what it advised. Without it: no hints.
export function pickAdvice(out) {
  if (out?.schemaVersion !== 1 || !Array.isArray(out.events)) throw Error('advice_invalid');
  const text = v => typeof v === 'string' ? v.slice(0, 300) : null;
  const events = out.events.filter(e => e?.source === 'codex' && text(e.text?.zh) && text(e.text?.en)).slice(0, 5)
    .map(e => ({ type: String(e.type), severity: e.severity === 'warn' ? 'warn' : 'info', text: { zh: text(e.text.zh), en: text(e.text.en) } }));
  return { status: 'ok', events };
}

const missing = e => e?.code === 'ENOENT';

// The CLI release this plugin is pinned to (cli-pin.json: version and per-platform SHA-256), which
// hooks/fetch-cli.sh downloads into ~/.cache/modelplan-cli/<version>. Hook, dashboard and docs read it.
export const CLI_PIN = JSON.parse(readFileSync(fileURLToPath(new URL('./cli-pin.json', import.meta.url)), 'utf8'));
export const MIN_CLI = CLI_PIN.version;
export const pinnedCli = (home = homedir()) => join(home, '.cache', 'modelplan-cli', MIN_CLI, 'modelplan');

export function atLeast(version, min) {
  const a = String(version).split('.').map(Number), b = min.split('.').map(Number);
  for (let i = 0; i < 3; i++) { if ((a[i] || 0) !== (b[i] || 0)) return (a[i] || 0) > (b[i] || 0); }
  return true;
}

const versionOfCli = path => (String(execFileSync(path, ['version'], { timeout: 3000, windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] })).match(/\d+\.\d+\.\d+/) || [])[0] ?? null;

// Same order and rules as hooks/find-cli.sh: the plugin's own pinned copy first; else one the user
// installed: PATH, then where install.sh and Homebrew put it (Codex starts plugins and hooks with
// a short PATH). Only executable files count; the first one at least `min` wins, else the first
// one found, so an older copy earlier on PATH does not hide a current one. Null when there is none.
export function findCli({ env = process.env, home = homedir(), platform = process.platform, min = MIN_CLI, versionOf = versionOfCli } = {}) {
  if (platform !== 'win32' && min === MIN_CLI) { try { accessSync(pinnedCli(home), constants.X_OK); return pinnedCli(home); } catch { /* not fetched */ } }
  const exe = platform === 'win32' ? 'modelplan.exe' : 'modelplan';
  const dirs = [...(env.PATH || env.Path || '').split(delimiter), env.MODELPLAN_BIN || join(home, '.local', 'bin'), join(home, '.cache', 'modelplan-cli'), '/opt/homebrew/bin', '/usr/local/bin'];
  let first = null;
  for (const dir of dirs.filter(Boolean)) {
    const p = join(dir, exe);
    try { if (!statSync(p).isFile()) continue; if (platform !== 'win32') accessSync(p, constants.X_OK); } catch { continue; }
    first ??= p;
    if (!min) break;
    try { const v = versionOf(p); if (v && atLeast(v, min)) return p; } catch { /* does not answer: keep looking */ }
  }
  return first;
}

// Hints need the optional CLI (`advise`; the plugin asks for MIN_CLI). The reason says which part is
// absent; a failure keeps its first error line so the dashboard can say why.
export async function readAdvice({ exec = run, cli = findCli() } = {}) {
  if (!cli) return { status: 'unavailable', reason: 'cli_missing', events: [] };
  let out;
  try { out = await exec(cli, ['advise', '--json', '--source', 'codex']); }
  catch (e) {
    const reason = missing(e) ? 'cli_missing' : /unknown command|usage/i.test(String(e.message) + String(e.stderr ?? '')) ? 'cli_without_advise' : 'cli_failed';
    if (reason !== 'cli_failed') return { status: 'unavailable', reason, events: [] };
    return { status: 'unavailable', reason, error: String(e.stderr || e.message).trim().split('\n')[0].slice(0, 160) + (Number.isInteger(e.code) ? ` (exit ${e.code})` : ''), events: [] };
  }
  try { return pickAdvice(JSON.parse(out)); } catch { return { status: 'unavailable', reason: 'advice_invalid', events: [] }; }
}

// The CLI first, then the Skill's standard-library reader. `reader` names the one that answered.
export async function readQuota({ exec = run, cli = findCli() } = {}) {
  const tried = cli ? [] : ['modelplan missing'];
  for (const [reader, cmd, args] of [...(cli ? [['cli', cli, ['quota', '--json']]] : []), ['python', 'python3', [READER]], ['python', 'python', [READER]]]) {
    try { return { ...pickCodex(JSON.parse(await exec(cmd, args))), reader }; }
    catch (e) { tried.push(cmd + (missing(e) ? ' missing' : ' failed')); }
  }
  return { status: 'unavailable', reader: null, others: [], reason: 'no local reader: ' + tried.join(', ') + ' (install Python 3 or the modelplan CLI)', account: null };
}
