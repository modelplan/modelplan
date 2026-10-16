// Optional integration check against an installed plugin in the actual Codex host.
// This deliberately creates no conversation, turn, inference or GUI surrogate.
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import assert from 'node:assert/strict';

const pluginRoot = fileURLToPath(new URL('../', import.meta.url));
const metadata = JSON.parse(await readFile(join(pluginRoot,'plugin.json'),'utf8'));
const serverName = Object.keys(JSON.parse(await readFile(join(pluginRoot,'mcp.json'),'utf8')).mcpServers)[0];
let root = pluginRoot, marketplace;
while (true) {
  try { marketplace = JSON.parse(await readFile(join(root,'.agents/plugins/marketplace.json'),'utf8')); break; } catch {}
  const parent = dirname(root); if (parent === root) throw Error('Plugin marketplace not found'); root = parent;
}
const pluginName = metadata.name, pluginId = pluginName+'@'+marketplace.name;
assert.ok(marketplace.plugins.some(p=>p.name===pluginName && resolve(root,p.source.path)===resolve(pluginRoot)));
const { version } = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
const child = spawn(process.env.CODEX_BIN || 'codex', ['app-server', '--stdio'], { cwd: root, stdio: ['pipe', 'pipe', 'pipe'] });
const pending = new Map(); let sequence = 0;
const report = { checkedAt: new Date().toISOString(), pluginVersion: version, runtime: 'Codex app-server stdio', createsThread: false, startsTurn: false, gui: 'NOT RUN: test covers registration and resource transport only' };
child.stderr.on('data', bytes => {
  // Limit diagnostics to this package's parsing failure. Never dump host logs.
  for (const line of bytes.toString().split('\n'))
    if (line.includes('failed to parse plugin MCP server') && line.includes(pluginName)) console.error(line);
});
child.on('error', error => { for (const p of pending.values()) { clearTimeout(p.timer); p.reject(error); } pending.clear(); });
createInterface({ input: child.stdout }).on('line', line => {
  let message; try { message = JSON.parse(line); } catch { return; }
  if (message.id !== undefined && pending.has(message.id)) {
    const p = pending.get(message.id); pending.delete(message.id); clearTimeout(p.timer);
    message.error ? p.reject(new Error(JSON.stringify(message.error))) : p.resolve(message.result);
  } else if (message.id !== undefined && message.method) {
    child.stdin.write(JSON.stringify({ id: message.id, error: { code: -32601, message: 'No interactive approval or inference in this read-only test' } }) + '\n');
  }
});
async function request(method, params = {}) {
  const id = ++sequence;
  const promise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 45000);
    pending.set(id, { resolve, reject, timer });
  });
  child.stdin.write(JSON.stringify({ id, method, params }) + '\n');
  return promise;
}
try {
  const host = await request('initialize', { clientInfo: { name: 'modelplan_host_acceptance', title: 'ModelPlan Host Acceptance', version }, capabilities: { experimentalApi: true, requestAttestation: false } });
  report.host = { userAgent: host.userAgent, platformOs: host.platformOs };
  child.stdin.write(JSON.stringify({ method: 'initialized', params: {} }) + '\n');
  const { plugin } = await request('plugin/read', { marketplacePath: join(root,'.agents/plugins/marketplace.json'), pluginName });
  assert.ok(plugin.mcpServers.includes(serverName), 'Codex failed to parse the bundled MCP server');
  report.plugin = { installed: plugin.summary.installed, enabled: plugin.summary.enabled, version: plugin.summary.localVersion, mcpServers: plugin.mcpServers, skills: plugin.skills.map(s => s.name) };
  assert.equal(report.plugin.version, version, 'Refresh the installed plugin before this test');
  const servers = [];
  let cursor;
  do {
    const page = await request('mcpServerStatus/list', { ...(cursor ? { cursor } : {}), limit: 100, detail: 'full' });
    servers.push(...page.data); cursor = page.nextCursor;
  } while (cursor);
  const server = servers.find(s => s.pluginId === pluginId && s.name === serverName);
  assert.ok(server, 'Installed plugin absent from Codex MCP inventory');
  assert.deepEqual(Object.keys(server.tools).sort(), ['get_model_dashboard', 'open_model_board', 'open_model_dashboard', 'open_model_panel']);
  assert.deepEqual(server.tools.open_model_panel._meta?.['openai/ui']?.entrypoints, [{ type: 'thread' }], 'Codex keeps the thread entrypoint');
  assert.equal(server.serverInfo.version, version);
  report.inventory = { name: server.name, pluginId: server.pluginId, serverInfo: server.serverInfo, tools: Object.keys(server.tools) };
  const resource = await request('mcpServer/resource/read', { server: server.name, uri: 'ui://modelplans/model-dashboard.html' });
  const item = resource.contents[0];
  assert.equal(item.mimeType, 'text/html;profile=mcp-app');
  assert.ok(item.text.includes('ui/initialize'));
  assert.deepEqual(item._meta?.['openai/ui']?.availableDisplayModes, ['inline', 'fullscreen']);
  assert.equal(item._meta?.['openai/ui']?.preferredDisplayMode, 'inline');
  const panel = (await request('mcpServer/resource/read', { server: server.name, uri: 'ui://modelplans/model-panel.html' })).contents[0];
  assert.equal(panel._meta?.['openai/ui']?.preferredDisplayMode, 'fullscreen');
  report.threadPanel = { uri: 'ui://modelplans/model-panel.html', displayModes: panel._meta['openai/ui'].availableDisplayModes };
  report.uiResource = { mimeType: item.mimeType, bytes: Buffer.byteLength(item.text), displayModes: item._meta['openai/ui'].availableDisplayModes, preferredDisplayMode: item._meta['openai/ui'].preferredDisplayMode };
  report.status = 'PASS';
} catch (error) { report.status = 'FAIL'; report.error = error.message; process.exitCode = 1; }
finally {
  for (const p of pending.values()) clearTimeout(p.timer);
  child.stdin.end(); child.kill('SIGTERM');
  const output = process.argv.indexOf('--output');
  if (output >= 0) await writeFile(process.argv[output + 1], JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}
