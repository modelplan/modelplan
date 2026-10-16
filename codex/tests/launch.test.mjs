import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtemp, mkdir, writeFile, rm, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const require = createRequire(import.meta.url);
const { discover, candidates, guidance, MIN_MAJOR } = require('../launch.cjs');

async function home(files = []) {
  const dir = await mkdtemp(join(tmpdir(), 'modelplan-launch-'));
  for (const f of files) { await mkdir(join(dir, f, '..'), { recursive: true }); await writeFile(join(dir, f), ''); }
  return dir;
}
const runtimeNode = '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node';
const fixed = versions => p => versions[p] ? { version: versions[p], ok: Number(versions[p].split('.')[0]) >= MIN_MAJOR } : { ok: false, error: 'missing' };
const base = h => ({ home: h, platform: 'linux', env: { PATH: '' }, execPath: '/no/such/host-node' });

test('a compatible host Node runs the server in-process without probing anything else', async () => {
  const h = await home([runtimeNode]);
  let probed = 0;
  const r = discover({ ...base(h), probeSelf: () => ({ version: '24.1.0', ok: true }), probe: () => { probed++; return { ok: true }; } });
  assert.equal(r.chosen.source, 'host');
  assert.equal(r.chosen.inProcess, true);
  assert.equal(probed, 0);
  await rm(h, { recursive: true });
});

test('a host Node that is too old hands over to the Codex runtime when one exists', async () => {
  const h = await home([runtimeNode]);
  const r = discover({ ...base(h), probeSelf: () => ({ version: '22.0.0', ok: false }), probe: fixed({ [join(h, runtimeNode)]: '24.19.0' }) });
  assert.equal(r.chosen.source, 'codex-runtime');
  assert.equal(r.chosen.path, join(h, runtimeNode));
  assert.equal(r.chosen.inProcess, false);
  assert.deepEqual(r.checked.map(c => [c.source, c.ok]), [['host', false], ['codex-runtime', true]], 'the runtime is preferred over PATH and system locations');
  await rm(h, { recursive: true });
});

test('a removed runtime is not remembered: the next start rediscovers and explains', async () => {
  const h = await home([runtimeNode]);
  const opts = { ...base(h), probeSelf: () => ({ version: '18.19.1', ok: false }), probe: fixed({ [join(h, runtimeNode)]: '24.19.0' }) };
  assert.equal(discover(opts).chosen.source, 'codex-runtime');
  await rm(join(h, '.cache'), { recursive: true });
  const r = discover(opts);
  assert.equal(r.chosen, null);
  // Fixed system locations may exist on the test machine; none of them is the removed runtime.
  assert.ok(!r.checked.some(c => c.source === 'codex-runtime'));
  assert.equal(r.checked[0].source, 'host');
  assert.match(guidance(r.checked, 'en'), /needs Node 22\+[\s\S]*runtime\.json[\s\S]*not changed/);
  assert.match(guidance(r.checked, 'zh'), /不会修改你的全局 Node 或 PATH/);
  await rm(h, { recursive: true });
});

test('a pinned runtime comes first; a stale pin is reported and discovery continues', async () => {
  const h = await home(['bin/node']);
  await mkdir(join(h, '.config/modelplan'), { recursive: true });
  await writeFile(join(h, '.config/modelplan/runtime.json'), JSON.stringify({ node: join(h, 'gone/node') }));
  const r = discover({ ...base(h), env: { PATH: join(h, 'bin') }, probeSelf: () => ({ version: '20.0.0', ok: false }), probe: fixed({ [join(h, 'bin/node')]: '22.12.0' }) });
  assert.equal(r.checked[0].path, join(h, 'gone/node'));
  assert.equal(r.checked[0].ok, false);
  assert.equal(r.chosen.source, 'PATH');
  const env = discover({ ...base(h), env: { PATH: '', MODELPLAN_NODE: join(h, 'bin/node') }, probeSelf: () => ({ version: '20.0.0', ok: false }), probe: fixed({ [join(h, 'bin/node')]: '24.0.0' }) });
  assert.equal(env.chosen.source, 'MODELPLAN_NODE');
  await rm(h, { recursive: true });
});

test('candidate order covers macOS, Linux and Windows locations without assuming any exists', async () => {
  const h = await home();
  const mac = candidates({ home: h, platform: 'darwin', env: { PATH: '/usr/bin' }, execPath: '/x/node' }).map(c => c.path);
  assert.ok(mac.indexOf('/opt/homebrew/bin/node') > mac.indexOf('/usr/bin/node'), 'PATH entries come before fixed locations');
  const win = candidates({ home: h, platform: 'win32', env: { Path: 'C:\\tools', ProgramFiles: 'C:\\Program Files' }, execPath: 'C:\\x\\node.exe' }).map(c => c.path);
  assert.ok(win.some(p => p.endsWith('nodejs/node.exe') || p.endsWith('nodejs\\node.exe')));
  assert.ok(win.every(p => p.endsWith('node.exe')));
  await rm(h, { recursive: true });
});

test('without any usable Node the launcher still answers MCP with the diagnosis', async () => {
  const checked = [{ path: '/usr/bin/node', source: 'host', version: '18.19.1', ok: false, error: 'needs Node 22+' }];
  const child = spawn(process.execPath, ['-e', `require(${JSON.stringify(require.resolve('../launch.cjs'))}).fallbackServer({ checked: ${JSON.stringify(checked)} }, '9.9.9')`]);
  const lines = [];
  let buf = '';
  child.stdout.on('data', d => { buf += d; let i; while ((i = buf.indexOf('\n')) >= 0) { lines.push(JSON.parse(buf.slice(0, i))); buf = buf.slice(i + 1); } });
  for (const m of [{ id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18' } }, { method: 'notifications/initialized' }, { id: 2, method: 'tools/list' }, { id: 3, method: 'tools/call', params: { name: 'open_model_dashboard', arguments: {} } }])
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', ...m }) + '\n');
  child.stdin.end();
  await new Promise(r => child.on('exit', r));
  assert.equal(lines[0].result.serverInfo.version, '9.9.9');
  assert.deepEqual(lines[1].result.tools.map(t => t.name), ['get_model_dashboard', 'open_model_dashboard']);
  assert.equal(lines[2].result.isError, true);
  assert.match(lines[2].result.content[0].text, /\/usr\/bin\/node \(host\) v18\.19\.1 — needs Node 22\+/);
});

test('symlinked duplicates are probed once', async () => {
  const h = await home(['real/node']);
  await mkdir(join(h, 'link'), { recursive: true });
  await symlink(join(h, 'real/node'), join(h, 'link/node'));
  let probes = 0;
  discover({ ...base(h), env: { PATH: [join(h, 'real'), join(h, 'link')].join(':') }, probeSelf: () => ({ ok: false }), probe: p => { if (p.startsWith(h)) probes++; return { ok: false, error: 'x' }; } });
  assert.equal(probes, 1);
  await rm(h, { recursive: true });
});
