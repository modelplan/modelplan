#!/usr/bin/env node
// Setup check for the ModelPlan Codex plugin. Read-only: asks Codex's app-server to start the
// installed plugin exactly as a task would, opens an ephemeral thread without a turn (no
// inference, nothing billed, no session log) and calls the read-only data tool once.
//   node doctor.cjs [--lang en|zh] [--json] [--codex <path>]
'use strict';
const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { discover, MIN_MAJOR, SETUP_NEEDED } = require('./launch.cjs');

const argv = process.argv.slice(2), flag = n => argv.includes(n), opt = n => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : null; };
const lang = opt('--lang') || (/^zh/i.test(process.env.LANG || process.env.LC_ALL || '') ? 'zh' : 'en');
const zh = lang === 'zh', win = process.platform === 'win32';
const CODEX = opt('--codex') || process.env.CODEX_BIN || 'codex';
const PLUGIN = 'modelplan-codex', SERVER = 'modelplan-codex', TOOLS = ['get_model_dashboard', 'open_model_dashboard'];
const UI_URI = 'ui://modelplans/model-dashboard.html';
const version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8')).version;
const T = (z, e) => zh ? z : e;
const REASONS = { cli_missing: ['需要 modelplan CLI，本机未安装', 'needs the modelplan CLI, not installed'], cli_without_advise: ['本机 CLI 不支持 advise（需 0.4+）', 'the installed CLI has no advise (needs 0.4+)'], advice_invalid: ['CLI 返回的提醒无法解析', 'the CLI returned unreadable hints'] };

const checks = [];
const add = (id, status, title, detail, fix) => { checks.push({ id, status, title, detail: detail || null, fix: fix || null }); };
const sh = (cmd, args, timeout) => spawnSync(cmd, args, { encoding: 'utf8', timeout: timeout || 15000, windowsHide: true, shell: win });

// Newline-delimited JSON-RPC over a child's stdio; server requests get a refusal.
function rpcChild(cmd, args, options) {
  const child = spawn(cmd, args, Object.assign({ stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true, shell: win }, options));
  const pending = new Map(); let next = 0, buffer = '', failed = null;
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', chunk => {
    buffer += chunk; let i;
    while ((i = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
      let m; try { m = JSON.parse(line); } catch (e) { continue; }
      if (m.id !== undefined && pending.has(m.id) && !m.method) { const p = pending.get(m.id); pending.delete(m.id); clearTimeout(p.timer); m.error ? p.reject(new Error(m.error.message || JSON.stringify(m.error))) : p.resolve(m.result); }
      else if (m.id !== undefined && m.method) child.stdin.write(JSON.stringify({ id: m.id, error: { code: -32601, message: 'read-only setup check' } }) + '\n');
    }
  });
  child.stderr.on('data', () => {});
  const fail = e => { failed = e; for (const p of pending.values()) { clearTimeout(p.timer); p.reject(e); } pending.clear(); };
  child.on('error', fail);
  child.on('exit', code => fail(new Error('exited with code ' + code)));
  return {
    request(method, params, timeout) {
      if (failed) return Promise.reject(failed);
      const id = ++next;
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => { pending.delete(id); reject(new Error('timed out: ' + method)); }, timeout || 45000);
        pending.set(id, { resolve, reject, timer });
        child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params: params || {} }) + '\n');
      });
    },
    notify(method, params) { if (!failed) child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params: params || {} }) + '\n'); },
    close() { child.removeAllListeners('exit'); try { child.stdin.end(); child.kill(); } catch (e) { /* gone */ } },
  };
}

function codexCommands() {
  const v = sh(CODEX, ['--version']);
  if (v.error || v.status !== 0) {
    add('codex', 'fail', T('Codex CLI', 'Codex CLI'), T('找不到 `' + CODEX + '`', '`' + CODEX + '` not found'), T('安装或更新 Codex，或用 --codex 指定路径', 'Install or update Codex, or pass --codex <path>'));
    return false;
  }
  const help = sh(CODEX, ['plugin', 'marketplace', '--help']).stdout || '';
  const ok = /\badd\b/.test(help) && /\bupgrade\b/.test(help);
  add('codex', ok ? 'ok' : 'fail', T('Codex 支持插件命令', 'Codex supports plugin commands'), v.stdout.trim(), ok ? null : T('升级 Codex 到支持 `codex plugin marketplace` 的版本', 'Upgrade Codex to a version with `codex plugin marketplace`'));
  return ok;
}

function pluginState() {
  const r = sh(CODEX, ['plugin', 'list', '--json']);
  let row = null;
  try { row = (JSON.parse(r.stdout).installed || []).find(p => p.name === PLUGIN) || null; } catch (e) { /* older Codex */ }
  if (!row) {
    add('plugin', 'fail', T('插件已安装并启用', 'Plugin installed and enabled'), T('未安装', 'not installed'),
      'codex plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex\ncodex plugin add modelplan-codex@modelplan');
    return null;
  }
  const status = row.installed && row.enabled ? (row.version === version ? 'ok' : 'warn') : 'fail';
  add('plugin', status, T('插件已安装并启用', 'Plugin installed and enabled'),
    row.pluginId + ' v' + row.version + (row.enabled ? '' : T('（已停用）', ' (disabled)')) + (row.version !== version ? T('；本检查脚本来自 v', '; this check is from v') + version : ''),
    !row.enabled ? T('在 Codex 插件设置中启用', 'Enable it in Codex plugin settings') : row.version !== version ? 'codex plugin marketplace upgrade modelplan && codex plugin add modelplan-codex@modelplan' : null);
  return row;
}

function localRuntime() {
  const r = discover();
  if (r.chosen) add('runtime', 'ok', T('Node 运行时（本终端视角）', 'Node runtime (as seen from this shell)'), r.chosen.path + ' v' + r.chosen.version + ' · ' + r.chosen.source);
  else add('runtime', 'fail', T('Node 运行时', 'Node runtime'), r.checked.map(c => c.path + (c.version ? ' v' + c.version : '') + ' — ' + c.error).join('; '),
    T('安装 Node.js ' + MIN_MAJOR + '+，或在 ~/.config/modelplan/runtime.json 写入 {"node": "<路径>"}', 'Install Node.js ' + MIN_MAJOR + '+, or write {"node": "<path>"} to ~/.config/modelplan/runtime.json'));
  return r;
}

function optional() {
  // Same lookup as the hooks and the server: PATH, then ~/.local/bin and Homebrew.
  const found = process.platform === 'win32' ? null : sh('sh', [path.join(__dirname, 'hooks', 'find-cli.sh')], 5000);
  const bin = found && found.status === 0 ? (found.stdout || '').trim() : 'modelplan';
  const cli = sh(bin, ['version'], 5000), py = sh('python3', ['--version'], 5000);
  const pyOk = !py.error && py.status === 0, cliOk = !cli.error && cli.status === 0;
  add('cli', cliOk ? 'ok' : 'info', T('可选：modelplan CLI（主动提醒 / advise）', 'Optional: modelplan CLI (proactive hints / advise)'),
    cliOk ? bin + ' · ' + (cli.stdout || '').trim().split('\n')[0] : T('未安装：额度仍可由 Python 读取，主动提醒不可用', 'not installed: quota still reads via Python; proactive hints are off'),
    cliOk ? null : 'curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh');
  add('python', pyOk ? 'ok' : cliOk ? 'info' : 'warn', T('额度读取回退：Python 3', 'Quota fallback: Python 3'),
    pyOk ? (py.stdout || py.stderr).trim() : T('未找到', 'not found'), pyOk || cliOk ? null : T('安装 Python 3 或 modelplan CLI 才能读本机额度', 'Install Python 3 or the modelplan CLI to read local quota'));
}

async function host(row) {
  const as = rpcChild(CODEX, ['app-server'], { cwd: __dirname });
  try {
    await as.request('initialize', { clientInfo: { name: 'modelplan_doctor', title: 'ModelPlan setup check', version }, capabilities: { experimentalApi: true } });
    as.notify('initialized');
    const servers = []; let cursor;
    do { const page = await as.request('mcpServerStatus/list', Object.assign({ limit: 100, detail: 'full' }, cursor ? { cursor } : {})); servers.push.apply(servers, page.data || []); cursor = page.nextCursor; } while (cursor);
    const s = servers.find(x => (row && x.pluginId === row.pluginId) || x.name === SERVER);
    const names = s ? Object.keys(s.tools || {}).sort() : [];
    const stub = !!(s && s.serverInfo && s.serverInfo.title === SETUP_NEEDED);
    const registered = !!s && !stub && TOOLS.every(t => names.includes(t));
    add('mcp', registered ? 'ok' : 'fail', T('MCP 已启动、工具已注册', 'MCP started with its tools'),
      stub ? T('只启动了诊断占位服务：Codex 启动插件时没有可用的 Node ' + MIN_MAJOR + '+', 'only the diagnosis stand-in started: Codex found no Node ' + MIN_MAJOR + '+ for the plugin')
        : s ? (s.serverInfo ? s.serverInfo.name + ' v' + s.serverInfo.version + ' · ' : '') + (names.join(', ') || s.toolsError || T('没有工具', 'no tools')) : T('Codex 没有列出该服务器', 'Codex lists no such server'),
      registered ? null : stub ? T('Codex 启动插件用的 PATH 与本终端可能不同：在 ~/.config/modelplan/runtime.json 写入 {"node": "<Node ' + MIN_MAJOR + '+ 路径>"} 后新开任务', 'Codex may start plugins with a different PATH than this shell: write {"node": "<Node ' + MIN_MAJOR + '+ path>"} to ~/.config/modelplan/runtime.json, then open a new task')
        : T('在 Codex 的 MCP 日志中查看启动错误；新开任务后重试', 'Check the MCP startup error in Codex logs; retry in a new task'));
    if (!s || stub) return;
    try {
      const hl = await as.request('hooks/list', { cwds: [process.cwd()] });
      const mine = [].concat.apply([], (hl.data || []).map(d => d.hooks || [])).filter(h => row && h.pluginId === row.pluginId);
      const untrusted = mine.filter(h => h.trustStatus !== 'trusted');
      let ran = null; try { ran = fs.statSync(path.join(os.homedir(), '.cache', 'modelplan-codex', 'hook-ran')).mtime; } catch (e) { /* never ran */ }
      add('hooks', !mine.length ? 'warn' : untrusted.length ? 'info' : 'ok', T('提醒钩子（额度提醒与任务开始简报）', 'Hint hook (quota hints and task-start brief)'),
        mine.length ? mine.map(h => h.eventName + ' · ' + h.trustStatus).join(', ') + ' · ' + (ran ? T('最近运行 ', 'last ran ') + ran.toISOString() : T('从未运行', 'never ran')) : T('Codex 没有加载插件钩子', 'Codex loaded no plugin hooks'),
        !mine.length ? T('更新插件到 0.11+ 后新开任务', 'Update the plugin to 0.11+, then open a new task')
          : untrusted.length ? T('Codex 只运行已信任的钩子：CLI 中输入 /hooks 审核并信任，桌面端在钩子审核中信任', 'Codex runs only trusted hooks: review and trust them with /hooks in the CLI, or in the desktop app\'s hook review') : null);
    } catch (e) { add('hooks', 'info', T('插件钩子', 'Plugin hooks'), T('此版本 Codex 无法列出钩子', 'this Codex cannot list hooks')); }
    try {
      const res = await as.request('mcpServer/resource/read', { server: s.name, uri: UI_URI });
      const item = res.contents && res.contents[0];
      const ok = !!item && item.mimeType === 'text/html;profile=mcp-app' && /ui\/initialize/.test(item.text || '');
      const mode = item && item._meta && item._meta['openai/ui'] && item._meta['openai/ui'].preferredDisplayMode;
      add('resource', ok ? 'ok' : 'fail', T('面板资源可读取', 'Dashboard resource readable'), item ? Math.round(Buffer.byteLength(item.text || '') / 1024) + ' KB · ' + T('默认显示', 'preferred display') + ' ' + (mode || 'inline') : T('无内容', 'empty'));
      const entry = s.tools && s.tools.open_model_panel, types = (((entry && entry._meta && entry._meta['openai/ui']) || {}).entrypoints || []).map(e => e.type);
      add('threadEntry', types.includes('thread') ? 'ok' : 'warn', T('右侧面板入口（Effort & quota）', 'Side panel entry (Effort & quota)'),
        types.includes('thread') ? T('已注册；在对话的侧边面板中打开，模型调用只能显示对话内卡片', 'registered; open it from the conversation side panel, a model call only shows the in-chat card') : T('未注册（旧版插件）', 'not registered (older plugin)'),
        types.includes('thread') ? null : T('更新插件后新开任务', 'Update the plugin, then open a new task'));
    } catch (e) { add('resource', 'fail', T('面板资源可读取', 'Dashboard resource readable'), e.message.split('\n')[0]); }
    const thread = await as.request('thread/start', { cwd: __dirname, ephemeral: true });
    const r = await as.request('mcpServer/tool/call', { threadId: thread.thread.id, server: s.name, tool: 'get_model_dashboard', arguments: { lang } }, 60000);
    const data = r.structuredContent;
    if (r.isError || !data) {
      add('data', 'fail', T('工具可调用、公开数据可用', 'Tool callable, public data available'), ((r.content && r.content[0] && r.content[0].text) || 'error').split('\n')[0].slice(0, 300));
      return;
    }
    const rt = data.setup && data.setup.runtime;
    add('hostRuntime', 'ok', T('Codex 实际选用的 Node', 'Node that Codex actually runs'), rt ? rt.path + ' v' + rt.version + ' · ' + rt.source : T('未报告（旧版服务器）', 'not reported (older server)'));
    add('data', data.stale ? 'warn' : 'ok', T('工具可调用、公开数据可用', 'Tool callable, public data available'),
      T('发布 ', 'publication ') + String(data.publicationId).slice(0, 12) + ' · ' + data.models.length + T(' 个模型', ' models') + (data.stale ? T(' · 使用上一份快照：', ' · last-good snapshot: ') + data.error : ''));
    const q = data.quota || {}, a = q.account;
    add('quota', a ? 'ok' : q.status === 'unavailable' ? 'warn' : 'info', T('本机额度读取', 'Local quota reading'),
      a ? (q.reader === 'cli' ? 'modelplan CLI' : 'Python') + ' · ' + a.windows.length + T(' 个窗口 · 观测于 ', ' windows · observed ') + a.observedAt + (a.stale ? T('（较旧）', ' (old)') : '')
        : (q.status + (q.reason ? ' · ' + q.reason : '')),
      a ? null : q.status === 'unavailable' ? T('安装 Python 3 或 modelplan CLI', 'Install Python 3 or the modelplan CLI') : T('用 ChatGPT 登录的 Codex 跑过一轮后才会有额度快照', 'A snapshot appears after one turn of a ChatGPT-login Codex session'));
    const adv = data.advice || {};
    add('advice', adv.status === 'ok' ? 'ok' : 'info', T('可选：主动提醒', 'Optional: proactive hints'),
      adv.status === 'ok' ? T('已启用', 'on') : T('未启用', 'off') + (adv.reason ? ' · ' + (REASONS[adv.reason] ? T(REASONS[adv.reason][0], REASONS[adv.reason][1]) : adv.reason) : ''),
      adv.status === 'ok' ? null : T('可选增强：安装或升级 modelplan CLI 0.4+；不影响面板和额度读取', 'Optional: install or upgrade the modelplan CLI 0.4+; the dashboard and quota work without it'));
  } catch (e) {
    add('mcp', 'fail', T('通过 Codex 启动插件', 'Start the plugin through Codex'), e.message, T('确认 Codex 可运行 `codex app-server`，或升级 Codex', 'Make sure `codex app-server` runs, or upgrade Codex'));
  } finally { as.close(); }
}

(async () => {
  const hasCodex = codexCommands();
  const row = hasCodex ? pluginState() : null;
  localRuntime();
  optional();
  if (hasCodex && row) await host(row);
  const st = id => (checks.find(c => c.id === id) || {}).status;
  const installed = st('plugin') === 'ok' || st('plugin') === 'warn';
  const callable = installed && st('mcp') === 'ok' && (st('data') === 'ok' || st('data') === 'warn');
  const summary = {
    installed, toolsCallable: callable, panelShown: 'unverified',
    panelNote: T('面板是否实际显示只能在 Codex 桌面端确认：新任务中输入“打开 Model Plan 看板”看对话内卡片；在对话侧边面板打开“Effort & quota”看右侧面板。面板底部“数据与依据”里的“显示：”一行是宿主报告的模式和宽度。', 'Whether the panel actually renders can only be confirmed in the Codex desktop app: ask "Open the ModelPlan model dashboard" for the in-chat card, and open "Effort & quota" from the conversation side panel for the panel beside the chat. The "Display:" line under Data & basis shows the mode and widths the host reported.'),
  };
  if (flag('--json')) { process.stdout.write(JSON.stringify({ pluginVersion: version, summary, checks }, null, 2) + '\n'); }
  else {
    const mark = { ok: '✓', warn: '!', fail: '✗', info: '·' };
    const lines = ['ModelPlan Codex ' + T('插件检查', 'setup check') + ' · v' + version, ''];
    for (const c of checks) {
      lines.push(mark[c.status] + ' ' + c.title + (c.detail ? T('：', ': ') + c.detail : ''));
      if (c.fix) for (const f of c.fix.split('\n')) lines.push('    → ' + f);
    }
    lines.push('', T('安装成功：', 'Installed: ') + (installed ? T('是', 'yes') : T('否', 'no')),
      T('工具可调用：', 'Tools callable: ') + (callable ? T('是', 'yes') : T('否', 'no')),
      T('面板实际展示：未验证 — ', 'Panel shown: unverified — ') + summary.panelNote);
    process.stdout.write(lines.join('\n') + '\n');
  }
  process.exitCode = callable ? 0 : 1;
})();
