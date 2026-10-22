import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { readAdvice, readQuota, pickCodex, readMeasured } from '../quota.mjs';
import { renderQuota, renderMeasured } from '../render.mjs';

const expected = JSON.parse(await readFile(new URL('../../cli/internal/quota/testdata/expected.json', import.meta.url), 'utf8'));

test('prefers the CLI, falls back to the Skill reader, and keeps only the Codex account', async () => {
  const calls = [];
  const q = await readQuota({ cli: 'modelplan', exec: async (cmd, args) => { calls.push(cmd); if (cmd === 'modelplan') throw Error('ENOENT'); return JSON.stringify(expected); } });
  assert.deepEqual(calls, ['modelplan', 'python3']);
  assert.equal(q.status, 'ok');
  assert.equal(q.reader, 'python');
  assert.equal(q.account.source, 'codex');
  assert.equal(q.account.headroom, 'conserve');
});

test('no reader means unavailable, never an invented quota', async () => {
  const q = await readQuota({ cli: null, exec: async () => { throw Object.assign(Error('ENOENT'), { code: 'ENOENT' }); } });
  assert.equal(q.status, 'unavailable');
  assert.match(q.reason, /modelplan missing, python3 missing, python missing/);
  assert.equal(q.account, null);
  assert.equal(pickCodex({ schemaVersion: 1, accounts: [], sources: [{ source: 'codex', status: 'empty', reason: 'api key' }] }).status, 'empty');
});

test('text summary shows windows, countdown and the headroom advice', () => {
  const text = renderQuota(pickCodex(expected), 'en');
  assert.match(text, /5h 72% used · resets in 3h20m · tight/);
  assert.match(text, /week 30% used · resets in 5d · tight · at the recent rate, used up in 3h25m/);
  assert.match(renderQuota(pickCodex(expected), 'zh'), /按最近的用量约 3时25分后用完/);
  assert.match(text, /Tight: stay at ★ or step down/);
  assert.match(renderQuota({ status: 'missing', account: null }, 'zh'), /本机没有可读的 Codex 额度/);
});

test('GPT Reserve shows as its own allowance and names the pool the headroom is about', () => {
  const q = pickCodex(structuredClone(expected));
  q.account.windows.push({ kind: 'weekly', limit: 'reserve', usedPercent: 100, pace: 'exhausted', resetsInMinutes: 60 });
  q.account.pool = 'reserve'; q.account.headroom = 'exhausted';
  const text = renderQuota(q, 'en');
  assert.match(text, /week Reserve 100% used · resets in 1h · exhausted/);
  assert.match(text, /→ Reserve · Exhausted/);
  assert.match(renderQuota(q, 'zh'), /→ Reserve · 额度已用完/);
});

test('usage credits show their balance and turn the used-up verdict into drawing on them', () => {
  const q = pickCodex(structuredClone(expected));
  assert.match(renderQuota(q, 'en'), /◇ credits 1,250\n/);
  q.account.headroom = 'exhausted'; q.account.credits = { balance: 73172.5, ageMinutes: 40 };
  const text = renderQuota(q, 'zh');
  assert.match(text, /◇ 点数 73,172 · 40分前读取/);
  assert.match(text, /→ 额度已用完：继续用会扣点数/);
  delete q.account.credits;
  assert.match(renderQuota(q, 'en'), /→ Exhausted: wait for the reset or use another plan/);
});

test('advice comes only from the CLI, keeps Codex events and drops anything malformed', async () => {
  const out = { schemaVersion: 1, events: [
    { type: 'reset_soon_with_surplus', severity: 'info', source: 'codex', text: { zh: 'Codex 5小时还剩 80%', en: 'Codex 5h window has 80% left' } },
    { type: 'window_tight', severity: 'warn', source: 'claude-code', text: { zh: 'x', en: 'x' } },
    { type: 'public_reset_announced', severity: 'info', source: 'codex', text: { zh: 42 } },
  ] };
  const calls = [];
  const a = await readAdvice({ cli: 'modelplan', exec: async (cmd, args) => { calls.push([cmd, ...args].join(' ')); return JSON.stringify(out); } });
  assert.deepEqual(calls, ['modelplan advise --json --source codex']);
  assert.deepEqual(a.events.map(e => e.type), ['reset_soon_with_surplus']);
  const enoent = () => { throw Object.assign(Error('spawn modelplan ENOENT'), { code: 'ENOENT' }); };
  assert.deepEqual(await readAdvice({ cli: 'modelplan', exec: async () => enoent() }), { status: 'unavailable', reason: 'cli_missing', events: [] });
  assert.deepEqual(await readAdvice({ cli: null, exec: async () => assert.fail('no CLI, no call') }), { status: 'unavailable', reason: 'cli_missing', events: [] });
  assert.equal((await readAdvice({ cli: 'modelplan', exec: async () => { throw Error('unknown command advise'); } })).reason, 'cli_without_advise');
  const text = renderQuota(pickCodex(expected), 'en', a);
  assert.match(text, /↑ Codex 5h window has 80% left/);
});

test('text names the reader and why hints are off', () => {
  const off = { status: 'unavailable', reason: 'cli_missing', events: [] };
  const text = renderQuota({ ...pickCodex(expected), reader: 'python' }, 'zh', off);
  assert.match(text, /主动提醒未启用：插件配套的 modelplan CLI 尚未就绪/);
  assert.match(text, /Python 回退读取/);
  assert.match(renderQuota({ status: 'missing', account: null }, 'en', off), /Proactive hints off/);
});

test('model and effort are labelled by thread; a background review never becomes the chat', () => {
  const report = h => ({ schemaVersion: 1, evaluatedAt: '2026-10-14T10:00:00Z', sources: [{ source: 'codex', status: 'ok' }],
    accounts: [{ source: 'codex', plan: 'pro', observedAt: '2026-10-14T09:51:00Z', harness: h, headroom: 'normal',
      windows: [{ kind: 'five_hour', usedPercent: 45, resetsInMinutes: 300, ageMinutes: 9, pace: 'on_track' }] }] });
  // Older CLIs: no attribution, and possibly the newest log's review model.
  assert.equal(pickCodex(report({ model: 'codex-auto-review', effort: 'low' })).account.harness, undefined);
  assert.equal(pickCodex(report({ model: 'gpt-6-sol' })).account.harness.attribution, 'recent-thread');
  const recent = renderQuota(pickCodex(report({ model: 'gpt-6-sol', observedAt: '2026-10-14T09:30:00Z', attribution: 'recent-thread' })), 'zh');
  assert.match(recent, /最近本机会话：gpt-6-sol · 默认档（30分前观测，不一定是这次对话）/);
  assert.match(recent, /每周 本机未观测到/, 'a window absent from the readings is unseen, not nonexistent');
  const own = renderQuota(pickCodex(report({ model: 'gpt-6-astra', effort: 'high', serviceTier: 'fast', observedAt: '2026-10-14T09:00:00Z', attribution: 'current-thread' })), 'en');
  assert.match(own, /this thread: gpt-6-astra · high · ⚡ Fast \(seen 1h ago\)/);
  assert.doesNotMatch(own, /may not be/);
});

test('an old window reading shows its age instead of a countdown', () => {
  const r = { schemaVersion: 1, evaluatedAt: '2026-10-14T10:00:00Z', sources: [], accounts: [{ source: 'codex', observedAt: '2026-10-14T09:51:00Z', headroom: 'normal',
    windows: [{ kind: 'five_hour', usedPercent: 45, resetsInMinutes: 300, ageMinutes: 9, pace: 'on_track' }, { kind: 'weekly', usedPercent: 20, resetsInMinutes: 7000, ageMinutes: 180, pace: 'on_track' }] }] };
  assert.match(renderQuota(pickCodex(r), 'en'), /week 20% used · resets in 4d20h · on track · seen 3h ago/);
});

test('a Codex account reading shows its reset credits and names its source', () => {
  const quota = { status: 'ok', reader: 'cli', evaluatedAt: '2026-10-16T08:00:00Z', account: { source: 'codex', plan: 'pro', via: 'codex-account', headroom: 'normal',
    windows: [{ kind: 'weekly', usedPercent: 48, resetsInMinutes: 9000, pace: 'on_track' }],
    cards: [{ kind: 'full', count: 1, expiresAt: '2026-10-29T19:12:57Z' }, { kind: 'full', count: 1, expiresAt: '2026-11-06T23:57:42Z' }] } };
  const zh = renderQuota(quota, 'zh'), en = renderQuota(quota, 'en');
  assert.match(zh, /◆ 2 次完整重置可用，最早 2026-10-29 19:12Z 到期 · 需在 Codex 中自己兑换/);
  assert.match(zh, /· Codex 账号读数/);
  assert.match(en, /2 full reset credit\(s\) available, first expires 2026-10-29 19:12Z/);
});

test('plans read through CodexBar come along, after Codex, with what each still needs', async () => {
  const report = { ...expected, accounts: [...expected.accounts,
    { source: 'codexbar:zai', plan: 'Pro', observedAt: expected.evaluatedAt, stale: false, via: 'codexbar', headroom: 'unknown',
      windows: [{ kind: 'five_hour', usedPercent: 1, resetsInMinutes: 200, pace: 'surplus' }, { kind: 'weekly', usedPercent: 52.4, resetsInMinutes: null, pace: 'unknown' }] }] };
  const q = pickCodex(report);
  assert.equal(q.account.source, 'codex', 'Codex stays the account the advice is about');
  assert.deepEqual(q.others.map(o => [o.id, o.name, o.plan, o.windows.length]), [['zai', 'Z.ai / GLM Coding Plan', 'Pro', 2]]);
  const setup = { cli: { status: 'ok', version: '9.9.9' }, hook: { lastRun: new Date().toISOString(), current: true, result: 'ok' }, advice: { status: 'ok' }, adviceEvents: 0,
    codexbar: { enabled: ['cursor', 'zai'], binary: '/c/CodexBarCLI', providers: [{ id: 'zai', name: 'Z.ai / GLM Coding Plan', status: 'ok' }, { id: 'cursor', name: 'Cursor', status: 'unavailable', reason: 'no session', needs: 'signed in to cursor.com' }] } };
  const text = renderQuota(q, 'en', { status: 'ok', events: [] }, setup);
  assert.match(text, /Other plans \(read on this machine\)\n  Z\.ai \/ GLM Coding Plan Pro · CodexBar: 5h 1% used ↻ 3h20m · week 52% used\n/);
  assert.match(text, /Setup: Cursor was not read through CodexBar \(unavailable: no session\); needs signed in to cursor\.com/);
  assert.doesNotMatch(text, /Setup: Z\.ai/);
  assert.doesNotMatch(text, /Setup complete/, 'a provider that needs something is not a complete setup');
  const off = renderQuota(q, 'zh', { status: 'ok', events: [] }, { ...setup, codexbar: { enabled: ['zai'], binary: null, fetch: '0.76.0 failed: download failed', providers: [] } });
  assert.match(off, /设置：已开启 CodexBar（zai），CodexBar CLI 还不可用：0\.76\.0 failed: download failed/);
  assert.equal(pickCodex(expected).others.length, 0);
});

test('a plan read natively shows without the CodexBar mark', () => {
  const report = { ...expected, accounts: [...expected.accounts,
    { source: 'native:zai', plan: 'GLM Coding Pro', observedAt: expected.evaluatedAt, stale: false, via: 'native', headroom: 'unknown',
      windows: [{ kind: 'five_hour', usedPercent: 61, resetsInMinutes: 60, pace: 'unknown' }] }] };
  const q = pickCodex(report);
  assert.deepEqual(q.others.map(o => [o.id, o.via]), [['zai', 'native']]);
  assert.match(renderQuota(q, 'zh'), /其他套餐（本机读取）\n  Z\.ai \/ GLM Coding Plan GLM Coding Pro: 5小时 61% 已用 ↻ 1时\n/);
});

test('the CodexBar state is the CLI\'s own report; an older or missing CLI gives none', async () => {
  const { codexbarStatus } = await import('../setup.mjs');
  const calls = [];
  const s = await codexbarStatus({ cli: '/x/modelplan', exec: async (cmd, args) => { calls.push([cmd, ...args]); return JSON.stringify({ schemaVersion: 1, enabled: ['zai'], binary: '/c/CodexBarCLI', pinnedVersion: '0.76.0', pinned: true, fetch: '',
    providers: [{ id: 'zai', name: 'Z.ai / GLM Coding Plan', status: 'ok' }] }); } });
  assert.deepEqual(calls, [['/x/modelplan', 'codexbar', '--json']]);
  assert.deepEqual(s, { enabled: ['zai'], binary: '/c/CodexBarCLI', pinnedVersion: '0.76.0', pinned: true, fetch: null, providers: [{ id: 'zai', name: 'Z.ai / GLM Coding Plan', status: 'ok', reason: null, needs: null }] });
  assert.equal(await codexbarStatus({ cli: null }), null);
  assert.equal(await codexbarStatus({ cli: '/x/modelplan', exec: async () => { throw Error('usage: modelplan …'); } }), null);
});

test('measured speed comes from the CLI history, Codex rows only, and the effort text shows it against ★', async () => {
  const report = { schemaVersion: 1, measured: [
    { source: 'codex', model: 'gpt-6-astra', effort: 'medium', turns: 20, requests: 80, outputTokensPerSecond: 60, ttftSeconds: 1.8, turnSeconds: 40, turnOutputTokens: 1200 },
    { source: 'codex', model: 'gpt-6-astra', effort: 'high', turns: 12, requests: 50, outputTokensPerSecond: 58, ttftSeconds: null, turnSeconds: 64, turnOutputTokens: 2040 },
    { source: 'codex', model: 'gpt-6-astra', effort: 'high', speed: 'fast', turns: 6, requests: 30, outputTokensPerSecond: 81.2, turnSeconds: 50, turnOutputTokens: null },
    { source: 'claude-code', model: 'claude-opus-5-5', effort: 'high', turns: 7, requests: 49, outputTokensPerSecond: 120 },
    { source: 'codex', model: 'x'.repeat(200), turns: 1 }] };
  const m = await readMeasured({ cli: '/bin/modelplan', exec: async (cmd, args) => { assert.deepEqual(args, ['history', '--json']); return JSON.stringify(report); } });
  assert.equal(m.status, 'ok');
  assert.deepEqual(m.rows.map(r => [r.effort, r.speed]), [['medium', ''], ['high', ''], ['high', 'fast']]);
  assert.equal((await readMeasured({ cli: null })).reason, 'cli_missing');
  assert.equal((await readMeasured({ cli: '/bin/old', exec: async () => '{"schemaVersion":1,"cycles":[]}' })).reason, 'cli_without_measured');
  const astra = { id: 'astra', name: 'GPT-6 Astra', recommended: 'medium', harnessIds: { codex: ['gpt-6-astra'] },
    configurations: [{ effort: 'medium', label: 'Med', ability: 50, cost: 1, time: 1 }, { effort: 'high', label: 'High', ability: 55, cost: 2, time: 1.4 }] };
  const tiers = [{ tier: 'fast', models: [{ modelId: 'astra', speed: { ratio: 1.5, qualifier: 'approximate' } }] }];
  const zh = renderMeasured(astra, m.rows, 'zh', tiers);
  assert.match(zh, /▲ Codex · GPT-6 Astra\n  High +每轮 1分04秒 ×1\.60（公布 ×1\.40） · 2\.0k token ×1\.70 · 输出 58 tok\/s · 12 轮\n/);
  assert.match(zh, /  High ⚡ +每轮 50秒 · 输出 81 tok\/s ×1\.40（公布约 ×1\.5） · 6 轮\n/);
  assert.match(zh, /  ★Med +每轮 40秒 · 1\.2k token · 输出 60 tok\/s · 首字 1\.8秒 · 20 轮\n/);
  assert.equal(renderMeasured({ ...astra, id: 'luna', harnessIds: {} }, m.rows, 'zh'), '');
});
