// Puts the pinned modelplan CLI (codex/cli-pin.json, the release the plugins pin) where Tauri
// bundles a sidecar: src-tauri/binaries/modelplan-<target triple>. The archive must match the
// pinned checksum.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const triples = {
  'aarch64-apple-darwin': 'darwin_arm64', 'x86_64-apple-darwin': 'darwin_amd64',
  'aarch64-unknown-linux-gnu': 'linux_arm64', 'x86_64-unknown-linux-gnu': 'linux_amd64',
};
const triple = process.argv[2];
const key = triples[triple];
if (!key) throw Error('usage: node scripts/fetch-cli.mjs <' + Object.keys(triples).join('|') + '>');
const pin = JSON.parse(readFileSync(new URL('../../codex/cli-pin.json', import.meta.url), 'utf8'));
const name = `modelplan_${key}`;
const r = await fetch(`${pin.release}/${name}.tar.gz`);
if (!r.ok) throw Error(`download ${name}: HTTP ${r.status}`);
const bytes = Buffer.from(await r.arrayBuffer());
const sum = createHash('sha256').update(bytes).digest('hex');
if (sum !== pin.sha256[key]) throw Error(`${name}.tar.gz checksum ${sum} does not match the pin ${pin.sha256[key]}`);
const tmp = mkdtempSync(join(tmpdir(), 'modelplan-cli-'));
try {
  writeFileSync(join(tmp, 'cli.tar.gz'), bytes);
  execFileSync('tar', ['-xzf', join(tmp, 'cli.tar.gz'), '-C', tmp, `${name}/modelplan`]);
  const out = new URL(`../src-tauri/binaries/modelplan-${triple}`, import.meta.url).pathname;
  mkdirSync(new URL('../src-tauri/binaries/', import.meta.url).pathname, { recursive: true });
  copyFileSync(join(tmp, name, 'modelplan'), out);
  chmodSync(out, 0o755);
  console.log(`modelplan ${pin.version} → ${out}`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
