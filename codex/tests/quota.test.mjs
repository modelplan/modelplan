import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { readQuota, pickCodex } from '../quota.mjs';
import { renderQuota } from '../render.mjs';

const expected = JSON.parse(await readFile(new URL('../../cli/internal/quota/testdata/expected.json', import.meta.url), 'utf8'));

test('prefers the CLI, falls back to the Skill reader, and keeps only the Codex account', async () => {
  const calls = [];
  const q = await readQuota({ exec: async (cmd, args) => { calls.push(cmd); if (cmd === 'modelplan') throw Error('ENOENT'); return JSON.stringify(expected); } });
  assert.deepEqual(calls, ['modelplan', 'python3']);
  assert.equal(q.status, 'ok');
  assert.equal(q.account.source, 'codex');
  assert.equal(q.account.headroom, 'conserve');
});

test('no reader means unavailable, never an invented quota', async () => {
  const q = await readQuota({ exec: async () => { throw Error('ENOENT'); } });
  assert.equal(q.status, 'unavailable');
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
