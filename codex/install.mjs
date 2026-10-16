// Installs the optional modelplan CLI when the user clicks "Install" on the dashboard. It runs
// the repository's install.sh (bundled as install-cli.sh): the latest release for this OS and CPU,
// checked against the release's checksums, into ~/.local/bin. Nothing else on the system changes:
// no PATH edits, no shell profile, no sudo. The tool is app-only, so the model cannot call it.
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findCli } from './quota.mjs';

const SCRIPT = fileURLToPath(new URL('./install-cli.sh', import.meta.url));
export const INSTALL_COMMAND = 'curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh';
export const supported = (platform = process.platform) => platform === 'darwin' || platform === 'linux';

export async function installCli({ run = runScript, find = findCli, platform = process.platform } = {}) {
  if (!supported(platform)) return { status: 'unsupported', command: null, url: 'https://github.com/modelplan/modelplan/releases' };
  const before = find();
  if (before) return { status: 'present', path: before };
  const r = await run(SCRIPT);
  const path = find();
  if (r.code === 0 && path) return { status: 'installed', path, output: r.output };
  return { status: 'failed', output: r.output, command: INSTALL_COMMAND };
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
