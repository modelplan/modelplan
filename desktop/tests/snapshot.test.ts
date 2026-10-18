import { test } from 'node:test';
import assert from 'node:assert/strict';
import { inPool, parseSnapshot } from '../app/src/snapshot.ts';
import { golden } from './fixture.ts';

test('the golden snapshot parses as schema v1', () => {
  const s = golden();
  assert.equal(s.schemaVersion, 1);
  assert.equal(s.sessions.length, 2);
  assert.deepEqual(s.events.map(e => e.type), ['window_tight', 'reset_passed_switch_back', 'better_model_available', 'reset_soon_with_surplus']);
  assert.ok(s.events.every(e => e.key && e.text.zh && e.text.en));
});

test('another kind or no version is refused; later versions and missing lists are fine', () => {
  assert.throws(() => parseSnapshot({ kind: 'other', schemaVersion: 1 }), /snapshot_kind/);
  assert.throws(() => parseSnapshot({ kind: 'modelplan.personal-snapshot' }), /snapshot_version/);
  const s = parseSnapshot('{"kind":"modelplan.personal-snapshot","schemaVersion":2,"accounts":[{"source":"codex"}],"future":true}');
  assert.deepEqual([s.sessions, s.events, s.measured, s.accounts[0].windows], [[], [], [], []]);
});

test('a pool keeps its own windows; an account without one keeps all', () => {
  const codex = golden().accounts.find(a => a.source === 'codex')!;
  assert.deepEqual(codex.windows.map(w => inPool(codex, w)), [true, true, false]);
  const reserve = { ...codex, pool: 'reserve' };
  assert.deepEqual(codex.windows.map(w => inPool(reserve, w)), [false, false, true]);
  const none = { ...codex, pool: 'reserve', windows: codex.windows.slice(0, 2) };
  assert.deepEqual(none.windows.map(w => inPool(none, w)), [true, true]);
});
