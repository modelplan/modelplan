// The user's own Codex quota, read on this machine only: `modelplan quota --json` when the CLI
// is installed, otherwise the Skill's standard-library reader. Both read the latest rate-limit
// snapshot Codex writes to its session logs; neither opens credentials or calls an account API.
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const READER = fileURLToPath(new URL('./skills/model-plan/scripts/quota.py', import.meta.url));
const run = (cmd, args) => new Promise((resolve, reject) =>
  execFile(cmd, args, { timeout: 8000, maxBuffer: 1 << 20, windowsHide: true }, (error, stdout) => error ? reject(error) : resolve(stdout)));

export function pickCodex(report) {
  if (report?.schemaVersion !== 1 || !Array.isArray(report.accounts)) throw Error('quota_report_invalid');
  const source = report.sources?.find(s => s.source === 'codex') ?? { status: 'missing' };
  const account = report.accounts.find(a => a.source === 'codex') ?? null;
  return { status: account ? 'ok' : source.status, reason: source.reason ?? null, evaluatedAt: report.evaluatedAt, account, note: report.note };
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

export async function readAdvice({ exec = run } = {}) {
  try { return pickAdvice(JSON.parse(await exec('modelplan', ['advise', '--json', '--source', 'codex']))); }
  catch { return { status: 'unavailable', events: [] }; }
}

export async function readQuota({ exec = run } = {}) {
  for (const [cmd, args] of [['modelplan', ['quota', '--json']], ['python3', [READER]], ['python', [READER]]]) {
    try { return pickCodex(JSON.parse(await exec(cmd, args))); } catch { /* next reader */ }
  }
  return { status: 'unavailable', reason: 'neither the modelplan CLI nor Python 3 could read local quota', account: null };
}
