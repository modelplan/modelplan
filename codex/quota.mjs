// The user's own Codex quota, read on this machine only: `modelplan quota --json` when the CLI
// is installed, otherwise the Skill's standard-library reader. Both read the latest rate-limit
// snapshot Codex writes to its session logs; neither opens credentials or calls an account API.
import { execFile } from 'node:child_process';
import { statSync } from 'node:fs';
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
  return { status: account ? 'ok' : source.status, reason: source.reason ?? null, evaluatedAt: report.evaluatedAt, account, note: report.note };
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

// Codex starts plugins and hooks with a short PATH (the desktop app's often lacks ~/.local/bin),
// so also look where install.sh and Homebrew put the CLI. Null when there is none.
export function findCli({ env = process.env, home = homedir(), platform = process.platform } = {}) {
  const exe = platform === 'win32' ? 'modelplan.exe' : 'modelplan';
  const dirs = [...(env.PATH || env.Path || '').split(delimiter), env.MODELPLAN_BIN || join(home, '.local', 'bin'), '/opt/homebrew/bin', '/usr/local/bin'];
  for (const dir of dirs.filter(Boolean)) {
    try { if (statSync(join(dir, exe)).isFile()) return join(dir, exe); } catch { /* not here */ }
  }
  return null;
}

// Hints need the optional CLI 0.4+ (`advise`). The reason says which part is absent.
export async function readAdvice({ exec = run, cli = findCli() } = {}) {
  if (!cli) return { status: 'unavailable', reason: 'cli_missing', events: [] };
  let out;
  try { out = await exec(cli, ['advise', '--json', '--source', 'codex']); }
  catch (e) { return { status: 'unavailable', reason: missing(e) ? 'cli_missing' : /unknown command|usage/i.test(String(e.message) + String(e.stderr ?? '')) ? 'cli_without_advise' : 'cli_failed', events: [] }; }
  try { return pickAdvice(JSON.parse(out)); } catch { return { status: 'unavailable', reason: 'advice_invalid', events: [] }; }
}

// The CLI first, then the Skill's standard-library reader. `reader` names the one that answered.
export async function readQuota({ exec = run, cli = findCli() } = {}) {
  const tried = cli ? [] : ['modelplan missing'];
  for (const [reader, cmd, args] of [...(cli ? [['cli', cli, ['quota', '--json']]] : []), ['python', 'python3', [READER]], ['python', 'python', [READER]]]) {
    try { return { ...pickCodex(JSON.parse(await exec(cmd, args))), reader }; }
    catch (e) { tried.push(cmd + (missing(e) ? ' missing' : ' failed')); }
  }
  return { status: 'unavailable', reader: null, reason: 'no local reader: ' + tried.join(', ') + ' (install Python 3 or the modelplan CLI)', account: null };
}
