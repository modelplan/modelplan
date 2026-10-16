// Starts the MCP server on a compatible Node.js. Codex runs this file with whatever `node` its
// PATH resolves; that Node only needs to parse this file (14+). Nothing is cached: every start
// re-checks, so a removed or upgraded runtime is found again. User PATH and global Node are never
// changed. When nothing fits, a minimal stdio server explains why instead of failing silently.
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, spawnSync } = require('child_process');
const { pathToFileURL } = require('url');

const MIN_MAJOR = 22;
const SETUP_NEEDED = 'ModelPlan (setup needed)'; // serverInfo.title of the diagnosis-only server
const SERVER = path.join(__dirname, 'server.bundle.mjs');
// The bundle needs ES2024 built-ins (Set.prototype.union), fetch and Web Crypto.
const PROBE = 'const v=Number(process.versions.node.split(".")[0]);' +
  'process.stdout.write(JSON.stringify({version:process.versions.node,ok:v>=' + MIN_MAJOR +
  '&&typeof Set.prototype.union==="function"&&typeof fetch==="function"&&!!(globalThis.crypto&&globalThis.crypto.subtle)}))';

function configDir(env, home) { return path.join(env.XDG_CONFIG_HOME || path.join(home, '.config'), 'modelplan'); }

// ~/.config/modelplan/runtime.json {"node": "/path/to/node"}. Codex does not pass the user's
// shell variables to plugin servers, so a pinned runtime lives in a file.
function pinned(env, home) {
  if (env.MODELPLAN_NODE) return { path: env.MODELPLAN_NODE, source: 'MODELPLAN_NODE' };
  const file = path.join(configDir(env, home), 'runtime.json');
  try {
    const value = JSON.parse(fs.readFileSync(file, 'utf8')).node;
    if (typeof value === 'string' && value) return { path: value, source: file };
  } catch (e) { /* no pin */ }
  return null;
}

function list(dir) { try { return fs.readdirSync(dir); } catch (e) { return []; } }
function semverDesc(names) {
  const key = n => (n.match(/\d+/g) || []).slice(0, 3).map(Number);
  return names.slice().sort((a, b) => { const x = key(a), y = key(b); for (let i = 0; i < 3; i++) if ((y[i] || 0) !== (x[i] || 0)) return (y[i] || 0) - (x[i] || 0); return 0; });
}

// Ordered by preference. Every location is optional; none is assumed to exist.
function candidates({ env = process.env, platform = process.platform, home = os.homedir(), execPath = process.execPath } = {}) {
  const win = platform === 'win32', exe = win ? 'node.exe' : 'node', out = [];
  const add = (p, source, explicit) => { if (p) out.push({ path: p, source, explicit: !!explicit }); };
  const pin = pinned(env, home);
  if (pin) add(pin.path, pin.source, true);
  add(execPath, 'host', true);
  // Codex desktop's own runtime when this client installed one. Layout is Codex's, not ours.
  const runtimes = path.join(home, '.cache', 'codex-runtimes');
  for (const name of list(runtimes).sort((a, b) => (b === 'codex-primary-runtime') - (a === 'codex-primary-runtime'))) {
    const deps = path.join(runtimes, name, 'dependencies');
    add(path.join(deps, 'node', 'bin', exe), 'codex-runtime');
    add(path.join(deps, 'bin', exe), 'codex-runtime');
    if (win) add(path.join(deps, 'node', exe), 'codex-runtime');
  }
  for (const dir of (env.PATH || env.Path || '').split(path.delimiter)) if (dir) add(path.join(dir, exe), 'PATH');
  if (win) {
    for (const base of [env.ProgramFiles, env['ProgramFiles(x86)'], env.LOCALAPPDATA && path.join(env.LOCALAPPDATA, 'Programs')])
      if (base) add(path.join(base, 'nodejs', exe), 'system');
    if (env.NVM_SYMLINK) add(path.join(env.NVM_SYMLINK, exe), 'nvm-windows');
    if (env.APPDATA) for (const v of semverDesc(list(path.join(env.APPDATA, 'nvm')).filter(n => /^v?\d/.test(n)))) add(path.join(env.APPDATA, 'nvm', v, exe), 'nvm-windows');
  } else {
    for (const p of ['/opt/homebrew/bin/node', '/usr/local/bin/node', '/usr/bin/node']) add(p, 'system');
    add(path.join(home, '.volta', 'bin', 'node'), 'volta');
    const managers = [
      [path.join(env.NVM_DIR || path.join(home, '.nvm'), 'versions', 'node'), v => path.join(v, 'bin', 'node'), 'nvm'],
      [path.join(env.FNM_DIR || path.join(home, '.local', 'share', 'fnm'), 'node-versions'), v => path.join(v, 'installation', 'bin', 'node'), 'fnm'],
      [path.join(home, '.local', 'share', 'mise', 'installs', 'node'), v => path.join(v, 'bin', 'node'), 'mise'],
      [path.join(home, '.asdf', 'installs', 'nodejs'), v => path.join(v, 'bin', 'node'), 'asdf'],
    ];
    for (const [dir, bin, source] of managers) for (const v of semverDesc(list(dir).filter(n => /^v?\d/.test(n)))) add(bin(path.join(dir, v)), source);
  }
  return out;
}

function probeFile(p) {
  try { if (!fs.statSync(p).isFile()) return { ok: false, error: 'not a file' }; } catch (e) { return { ok: false, error: 'missing' }; }
  const r = spawnSync(p, ['-e', PROBE], { encoding: 'utf8', timeout: 5000, windowsHide: true });
  if (r.error) return { ok: false, error: r.error.code || r.error.message };
  try { return JSON.parse(r.stdout); } catch (e) { return { ok: false, error: 'exit ' + r.status }; }
}
function probeSelf() {
  return { version: process.versions.node, ok: Number(process.versions.node.split('.')[0]) >= MIN_MAJOR &&
    typeof Set.prototype.union === 'function' && typeof fetch === 'function' && !!(globalThis.crypto && globalThis.crypto.subtle) };
}

// Returns the first compatible runtime and every candidate checked before it.
function discover(options = {}) {
  const probe = options.probe || probeFile, self = options.probeSelf || probeSelf, seen = new Set(), checked = [];
  const real = p => { try { return fs.realpathSync(p); } catch (e) { return null; } };
  const execReal = real(options.execPath || process.execPath);
  for (const c of candidates(options)) {
    const key = real(c.path);
    if (!key && !c.explicit) continue; // absent optional location: not worth reporting
    if (key && seen.has(key)) continue;
    if (key) seen.add(key);
    const inProcess = c.source === 'host' || (key !== null && key === execReal);
    const r = inProcess ? self() : probe(c.path);
    const row = { path: c.path, source: c.source, version: r.version || null, ok: !!r.ok, error: r.ok ? null : r.error || (r.version ? 'needs Node ' + MIN_MAJOR + '+' : 'unusable') };
    checked.push(row);
    if (row.ok) return { chosen: Object.assign({}, row, { inProcess }), checked };
  }
  return { chosen: null, checked };
}

function guidance(checked, lang) {
  const rows = checked.map(c => '  ' + c.path + ' (' + c.source + ')' + (c.version ? ' v' + c.version : '') + ' — ' + c.error).join('\n');
  const pin = path.join('~', '.config', 'modelplan', 'runtime.json');
  return lang === 'zh'
    ? 'ModelPlan 插件需要 Node.js ' + MIN_MAJOR + ' 或更新版本，但本机没有找到可用的运行时。已检查：\n' + (rows || '  （无）') +
      '\n处理：安装 Node.js ' + MIN_MAJOR + '+（https://nodejs.org），或在 ' + pin + ' 写入 {"node": "<Node 可执行文件路径>"}，然后新开一个 Codex 任务。插件不会修改你的全局 Node 或 PATH。'
    : 'The ModelPlan plugin needs Node.js ' + MIN_MAJOR + ' or newer and found no usable runtime. Checked:\n' + (rows || '  (none)') +
      '\nFix: install Node.js ' + MIN_MAJOR + '+ (https://nodejs.org), or write {"node": "<path to node>"} to ' + pin + ', then start a new Codex task. Your global Node and PATH were not changed.';
}

// Enough MCP to register the tools and return the diagnosis when they are called.
function fallbackServer(result, version) {
  const text = guidance(result.checked, 'zh') + '\n\n' + guidance(result.checked, 'en');
  process.stderr.write(guidance(result.checked, 'en') + '\n');
  const tool = (name, title) => ({ name, title, description: 'Unavailable: ' + title + ' needs Node.js ' + MIN_MAJOR + '+. Call it to see the setup diagnosis.', inputSchema: { type: 'object' }, annotations: { readOnlyHint: true } });
  const reply = (id, body) => process.stdout.write(JSON.stringify(Object.assign({ jsonrpc: '2.0', id }, body)) + '\n');
  let buffer = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    buffer += chunk;
    let i;
    while ((i = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, i).trim(); buffer = buffer.slice(i + 1);
      let m; try { m = JSON.parse(line); } catch (e) { continue; }
      if (!m || m.id === undefined || m.id === null) continue;
      if (m.method === 'initialize') reply(m.id, { result: { protocolVersion: (m.params && m.params.protocolVersion) || '2025-06-18', capabilities: { tools: {}, resources: {} }, serverInfo: { name: 'modelplans-dashboard', title: SETUP_NEEDED, version }, instructions: text } });
      else if (m.method === 'tools/list') reply(m.id, { result: { tools: [tool('get_model_dashboard', 'Model Plan data'), tool('open_model_dashboard', 'Model Plan dashboard')] } });
      else if (m.method === 'tools/call') reply(m.id, { result: { isError: true, content: [{ type: 'text', text }], structuredContent: { setup: { runtime: null, checked: result.checked } } } });
      else if (m.method === 'resources/list') reply(m.id, { result: { resources: [] } });
      else if (m.method === 'ping') reply(m.id, { result: {} });
      else reply(m.id, { error: { code: -32601, message: text } });
    }
  });
  process.stdin.on('end', () => process.exit(0));
}

function main() {
  let version = '0.0.0';
  try { version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8')).version; } catch (e) { /* keep placeholder */ }
  const result = discover();
  if (!result.chosen) return fallbackServer(result, version);
  const c = result.chosen;
  process.env.MODELPLAN_RUNTIME = JSON.stringify({ path: c.inProcess ? process.execPath : c.path, version: c.version, source: c.source, checked: result.checked.length });
  if (c.inProcess) return import(pathToFileURL(SERVER).href);
  const child = spawn(c.path, [SERVER].concat(process.argv.slice(2)), { stdio: 'inherit', env: process.env, windowsHide: true });
  for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => child.kill(sig));
  child.on('error', e => { result.checked.push({ path: c.path, source: c.source, version: c.version, ok: false, error: e.code || e.message }); fallbackServer({ checked: result.checked }, version); });
  child.on('exit', (code, signal) => process.exit(code === null ? (signal ? 1 : 0) : code));
}

module.exports = { MIN_MAJOR, SETUP_NEEDED, candidates, discover, guidance, pinned, fallbackServer };
if (require.main === module) main();
