// The plugin's own modelplan CLI: the release pinned in cli-pin.json, fetched by hooks/fetch-cli.sh
// (shared with the Claude Code plugin) into ~/.cache/modelplan-cli/<version>, used only if its
// SHA-256 equals the pinned one. The server starts it in the background when it starts; the
// dashboard's Retry button runs it in the foreground. Nothing else on the system changes.
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { cliStatus } from './setup.mjs';

const SCRIPT = fileURLToPath(new URL('./hooks/fetch-cli.sh', import.meta.url));
export const supported = (platform = process.platform) => platform === 'darwin' || platform === 'linux';
const off = (env = process.env) => env.MODELPLAN_PLUGIN_CLI === 'off';

// Background fetch at server start: returns at once; a recent failure is not retried for 10 minutes.
export function fetchInBackground({ platform = process.platform, env = process.env, run = spawn } = {}) {
  if (!supported(platform) || off(env)) return false;
  try { run('sh', [SCRIPT, '--background'], { stdio: 'ignore', detached: true, windowsHide: true }).unref(); return true; } catch { return false; }
}

// The Retry button: fetch now and report what the plugin will actually use afterwards.
export async function fetchCli({ run = runScript, status = cliStatus, platform = process.platform, env = process.env } = {}) {
  if (!supported(platform)) return { status: 'unsupported', url: 'https://github.com/modelplan/modelplan/releases' };
  if (off(env)) return { status: 'off' };
  const r = await run(SCRIPT);
  const after = await status();
  if (after.status === 'ok') return { status: 'ready', path: after.path, version: after.version, source: after.source };
  return { status: 'failed', reason: r.output.split('\n').filter(Boolean).pop()?.replace(/^modelplan CLI [\d.]+: /, '') || after.error || 'the fetched CLI did not answer' };
}

function runScript(script) {
  return new Promise(resolve => {
    const child = spawn('sh', [script], { env: process.env, windowsHide: true, timeout: 150000 });
    let output = '';
    const keep = d => { output = (output + d).slice(-2000); };
    child.stdout.on('data', keep); child.stderr.on('data', keep);
    child.on('error', e => resolve({ code: -1, output: output + e.message }));
    child.on('close', code => resolve({ code, output: output.trim() }));
  });
}
