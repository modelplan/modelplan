// Installs the optional modelplan CLI when the user clicks "Install" on the dashboard. It runs
// the repository's install.sh (bundled as install-cli.sh): the latest release for this OS and CPU,
// checked against the release's checksums, into ~/.local/bin. Nothing else on the system changes:
// no PATH edits, no shell profile, no sudo. The tool is app-only, so the model cannot call it.
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { cliStatus } from './setup.mjs';

const SCRIPT = fileURLToPath(new URL('./install-cli.sh', import.meta.url));
export const INSTALL_COMMAND = 'curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh';
export const supported = (platform = process.platform) => platform === 'darwin' || platform === 'linux';

// Installs when missing, upgrades when older than MIN_CLI, and reports success only after the
// CLI that the plugin will actually use answers with a new enough version.
export async function installCli({ run = runScript, status = cliStatus, platform = process.platform } = {}) {
  if (!supported(platform)) return { status: 'unsupported', command: null, url: 'https://github.com/modelplan/modelplan/releases' };
  const before = await status();
  if (before.status === 'ok') return { status: 'present', path: before.path, version: before.version };
  const r = await run(SCRIPT);
  const after = await status();
  if (r.code === 0 && after.status === 'ok') return { status: before.status === 'outdated' ? 'upgraded' : 'installed', path: after.path, version: after.version, output: r.output };
  const why = r.code !== 0 ? r.output
    : after.status === 'outdated' ? `an older modelplan ${after.version} at ${after.path} is found first; remove it or upgrade it there`
    : after.error ?? 'the installed CLI did not answer';
  return { status: 'failed', output: why, command: INSTALL_COMMAND };
}

function runScript(script) {
  return new Promise(resolve => {
    const child = spawn('sh', [script], { env: process.env, windowsHide: true, timeout: 120000 });
    let output = '';
    const keep = d => { output = (output + d).slice(-2000); };
    child.stdout.on('data', keep); child.stderr.on('data', keep);
    child.on('error', e => resolve({ code: -1, output: output + e.message }));
    child.on('close', code => resolve({ code, output: output.trim() }));
  });
}
