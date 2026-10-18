import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderNow } from '../app/src/views/now.ts';
import { renderQuota } from '../app/src/views/quota.ts';
import { renderEffort } from '../app/src/views/effort.ts';
import { renderSettings } from '../app/src/views/settings.ts';
import { defaults } from '../app/src/notify.ts';
import { dur } from '../app/src/i18n.ts';
import { at, golden, publication } from './fixture.ts';

test('durations read as the CLI writes them', () => {
  assert.deepEqual([35, 60, 95, 2880, 4380].map(m => dur('zh', m)), ['35分', '1时', '1时35分', '2天', '3天1时']);
  assert.deepEqual([35, 95, 4380].map(m => dur('en', m)), ['35m', '1h35m', '3d1h']);
});

test('Now: each session against ★, then the advice', () => {
  const html = renderNow(golden(), 'zh', at);
  assert.match(html, /Claude Opus 5\.5 <span class="effort">High<\/span>/);
  assert.match(html, /比 ★Med \+4\.8分 ×1\.37/);
  assert.match(html, /<span class="effort star">★Med<\/span> <span class="fast">⚡Fast<\/span>/);
  assert.match(html, /最近本机会话/);
  assert.match(html, /class="ev warn"><b class="short">↓★Med ×0\.73<\/b>/);
  assert.match(renderNow({ ...golden(), sessions: [], events: [] }, 'en', at), /No session readings yet/);
});

test('Quota: what is left per window, the run-out, the other pool dimmed, readers that found nothing', () => {
  const s = golden();
  s.sources.push({ source: 'codexbar:cursor', status: 'unavailable', reason: 'not signed in <x>' });
  const html = renderQuota(s, 'en', at);
  assert.match(html, /12% left/);
  assert.match(html, /at the recent rate, used up in 35m/);
  assert.match(html, /class="meter ok off-pool" data-kind="weekly">\s*<span class="k">week Reserve<\/span>/);
  assert.match(html, /<b>Z\.ai \/ GLM Coding Plan · CodexBar<\/b>/);
  assert.match(html, /Cursor · CodexBar<\/b> unavailable <span class="dim">not signed in &lt;x&gt;<\/span>/);
});

test('Effort: the ladder and curves for the session model, Fast and the measured speed', () => {
  const s = golden();
  const cc = renderEffort(s, publication, 'zh', null);
  assert.match(cc, /<svg class="curve/);
  assert.match(cc, /<tr class=" cur sel" data-effort="high">/);
  assert.match(cc, /<tr class="rec" data-effort="medium">/);
  assert.match(cc, /<b>High<\/b> 每轮 2分22秒 · 输出 116 tok\/s · 首字 1\.9秒 · 38 轮/);
  const cx = renderEffort(s, publication, 'en', { source: 'codex' });
  assert.match(cx, /Codex · GPT-6 Astra <em>⚡Fast<\/em>/);
  assert.match(cx, /about ×1\.5 the speed for ×2 the plan quota/);
  assert.match(cx, /<b>★Med ⚡<\/b> <span class="dim">too few samples \(2 turns\)<\/span>/);
  assert.match(renderEffort(s, null, 'en', null), /Published data not loaded yet/);
});

test('Settings: the notification switches as stored', () => {
  const html = renderSettings(golden(), { lang: 'auto', menuBar: 'codex', notify: { ...defaults, surplus: true } }, 'en');
  assert.match(html, /data-notify="surplus" checked/);
  assert.match(html, /data-notify="other"><span>/);
  assert.match(html, /<option value="codex" selected>Codex<\/option>/);
});
