import { test } from 'node:test';
import assert from 'node:assert/strict';
import { focus, menuBar } from '../app/src/menubar.ts';
import { golden } from './fixture.ts';

test('the menu bar speaks for the latest session, like the narrow status line', () => {
  const s = golden();
  assert.equal(focus(s)?.source, 'claude-code');
  const zh = menuBar(s, 'zh'), en = menuBar(s, 'en');
  assert.equal(zh.title, '12% · 周70% ↓★Med ×0.73');
  assert.equal(en.title, '12% · wk70% ↓★Med ×0.73');
  assert.equal(en.tooltip, 'Claude Code · Claude Opus 5.5 High · 12% left, resets in 1h35m\nCodex · GPT-6 Astra Med Fast · 80% left, resets in 40m');
});

test('a chosen harness, its pool and the better-model hint', () => {
  const s = golden();
  assert.equal(menuBar(s, 'en', 'codex').title, '80% · wk55% →GPT-6.1 Sol ★Med ×0.55');
  s.accounts[1].pool = 'reserve';
  s.events = [];
  assert.equal(menuBar(s, 'en', 'codex').title, 'Reserve wk90% ↑');
});

test('no session: icon only', () => {
  const s = golden();
  s.sessions = [];
  assert.deepEqual(menuBar(s, 'zh'), { title: '', tooltip: 'Model Plan' });
});

test('a stale reading yields to a fresh one', () => {
  const s = golden();
  s.sessions[0].stale = true;
  assert.equal(focus(s)?.source, 'codex');
});
