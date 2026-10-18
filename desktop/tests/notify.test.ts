import { test } from 'node:test';
import assert from 'node:assert/strict';
import { categoryOf, defaults, due, keepFor } from '../app/src/notify.ts';
import { at, golden } from './fixture.ts';

test('the confirmed defaults: tight, switch back and a better model on; surplus off', () => {
  assert.deepEqual(defaults, { tight: true, switchBack: true, better: true, surplus: false, other: false });
  assert.equal(categoryOf('window_exhausted'), 'tight');
  assert.equal(categoryOf('announced_reset_with_surplus'), 'surplus');
});

test('each event is notified once, most urgent first, two at a time', () => {
  const s = golden();
  const first = due(s.events, {}, {}, at, 'zh');
  assert.deepEqual(first.send.map(n => n.title), ['Claude Code · 额度偏紧 ↓★Med ×0.73', 'Claude Code · 已重置，可以换回 ↺★Med']);
  assert.match(first.send[0].body, /剩 12%/);
  const second = due(s.events, {}, first.notified, at + 60000, 'en');
  assert.deepEqual(second.send.map(n => n.title), ['Codex · A better model →GPT-6.1 Sol ★Med ×0.55']);
  assert.deepEqual(due(s.events, {}, second.notified, at + 120000, 'en').send, []);
  const surplus = due(s.events, { surplus: true }, second.notified, at + 180000, 'en');
  assert.deepEqual(surplus.send.map(n => n.key), [s.events[3].key]);
});

test('stale readings are not notified and old keys are dropped', () => {
  const s = golden();
  s.events.forEach(e => (e.stale = true));
  assert.deepEqual(due(s.events, {}, {}, at, 'zh').send, []);
  const old = { gone: new Date(at - keepFor - 1).toISOString(), kept: new Date(at - 1000).toISOString() };
  assert.deepEqual(Object.keys(due([], {}, old, at, 'zh').notified), ['kept']);
});
