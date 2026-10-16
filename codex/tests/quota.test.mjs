import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { readAdvice, readQuota, pickCodex } from '../quota.mjs';
import { renderQuota } from '../render.mjs';

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
  assert.match(text, /week 30% used · resets in 5d · tight/);
  assert.match(text, /Tight: stay at ★ or step down/);
  assert.match(renderQuota({ status: 'missing', account: null }, 'zh'), /本机没有可读的 Codex 额度/);
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
  assert.match(text, /主动提醒未启用：需要可选的 modelplan CLI 0\.4\+/);
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
