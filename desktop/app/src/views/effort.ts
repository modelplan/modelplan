// Effort: the open effort curves and ladder of the Codex dashboard, for the model a session uses,
// with the user's own measured speed beside them.
import { effortCurveSvg, speedComparison } from '../../../../codex/ui/curves.js';
import { timeRatio } from '../../../../codex/ui/comparison.js';
import type { Lang, Measured, Session, Snapshot } from '../snapshot.ts';
import type { Model, Publication, SpeedTier } from '../published.ts';
import { modelFor } from '../published.ts';
import { fill, sourceName, words } from '../i18n.ts';
import { esc, finite, gain, times } from './html.ts';

export interface EffortChoice { source: string; effort?: string }

interface Row { effort: string; label: string; ability: number | null; cost: number | null; time: number | null; estimated: boolean; costEstimated?: boolean }
interface Curve { rows: Row[]; baselineIndex: number; generation?: { ratio: number; qualifier: string } | null; quotaRatio?: number | null }

// The speed tier a session runs in, with this model's entry.
export function tierFor(p: Publication | null, x: Session, m: Model): (SpeedTier & { model: SpeedTier['models'][number] }) | null {
  if (!p || !x.speed) return null;
  for (const t of p.speedTiers) {
    const e = t.harness === x.source && t.tier === x.speed ? t.models.find(v => v.modelId === m.id) : undefined;
    if (e) return { ...t, model: e };
  }
  return null;
}

export function renderEffort(s: Snapshot, p: Publication | null, lang: Lang, choice: EffortChoice | null): string {
  const t = words(lang);
  const listed = s.sessions.map(x => ({ x, m: modelFor(p, x.source, x.model.harnessId) })).filter((v): v is { x: Session; m: Model } => !!v.m);
  if (!listed.length) return `<p class="empty">${esc(p ? t.noModel : t.noPublication)}</p>`;
  const pick = listed.find(v => v.x.source === choice?.source) ?? listed[0];
  const { x, m } = pick;
  const switcher = listed.length > 1
    ? `<div class="switch" role="tablist">${listed.map(v => `<button type="button" role="tab" data-effort-source="${esc(v.x.source)}" aria-selected="${v === pick}">${esc(sourceName(lang, v.x.source))}</button>`).join('')}</div>`
    : '';
  const tier = tierFor(p, x, m);
  const data = speedComparison(m, timeRatio, tier as never) as Curve;
  const inUse = data.rows.findIndex(r => r.effort === (x.effort?.key ?? m.recommended));
  const sel = Math.max(0, data.rows.findIndex(r => r.effort === choice?.effort) >= 0 ? data.rows.findIndex(r => r.effort === choice?.effort) : inUse >= 0 ? inUse : data.baselineIndex);
  const svg = effortCurveSvg(data, { selected: sel, language: lang, names: { ability: t.ability, cost: t.cost, time: t.time, points: t.points } });
  const rows = data.rows.map((r, i) => `<tr class="${i === data.baselineIndex ? 'rec' : ''}${i === inUse ? ' cur' : ''}${i === sel ? ' sel' : ''}" data-effort="${esc(r.effort)}">
<th>${i === data.baselineIndex ? '★' : ''}${esc(r.label)}${i === inUse ? ` <em>${esc(t.current)}</em>` : ''}</th>
<td class="a">${gain(r.ability)}</td><td class="c">${r.costEstimated && finite(r.cost) ? '≈' : ''}${times(r.cost)}</td><td class="t">${r.estimated && finite(r.time) ? '≈' : ''}${times(r.time)}</td></tr>`).join('');
  const fast = tier && data.generation ? `<p class="note">⚡ ${esc(fill(t.fastNote, String(data.generation.ratio), finite(data.quotaRatio) ? String(data.quotaRatio) : '—'))}</p>` : '';
  return `${switcher}<h2 class="mp-lcd-h">${esc(fill(t.effortFor, sourceName(lang, x.source), m.name))}${tier ? ` <em>⚡${esc(tier.label)}</em>` : ''}</h2>
<div class="mp-lcd chart">${svg}</div>
<table class="ladder"><thead><tr><th></th><th>${esc(t.ability)}</th><th>${esc(t.cost)}</th><th>${esc(t.time)}</th></tr></thead><tbody>${rows}</tbody></table>
<p class="note">${esc(t.effortNote)}</p>${fast}${measured(s, x, m, lang)}`;
}

function measured(s: Snapshot, x: Session, m: Model, lang: Lang): string {
  const t = words(lang);
  const ids = new Set([x.model.harnessId, ...(m.harnessIds?.[x.source] ?? [])]);
  const rows = s.measured.filter(r => r.source === x.source && ids.has(r.model));
  if (!rows.length) return `<h3>${esc(t.measured)}</h3><p class="dim small">${esc(t.noMeasured)}</p>`;
  const rank = (r: Measured) => m.configurations.findIndex(c => c.effort === r.effort);
  rows.sort((a, b) => rank(b) - rank(a) || (a.speed ?? '').localeCompare(b.speed ?? ''));
  const label = (r: Measured) => {
    const c = m.configurations.find(c => c.effort === r.effort);
    return (c?.effort === m.recommended ? '★' : '') + (c?.label ?? r.effort ?? '—') + (r.speed ? ' ⚡' : '');
  };
  const secs = (v: number) => {
    if (v < 60) return (v < 10 ? v.toFixed(1) : v.toFixed(0)) + t.sec;
    const n = Math.round(v);
    return Math.floor(n / 60) + t.min + String(n % 60).padStart(2, '0') + t.sec;
  };
  const line = (r: Measured) => {
    if (r.turnSeconds == null && r.outputTokensPerSecond == null) return `<span class="dim">${esc(fill(t.few, r.turns))}</span>`;
    const parts: string[] = [];
    if (r.turnSeconds != null) parts.push(fill(t.turn, secs(r.turnSeconds)));
    if (r.outputTokensPerSecond != null) parts.push(fill(t.rate, Math.round(r.outputTokensPerSecond)));
    if (r.ttftSeconds != null) parts.push(fill(t.ttft, secs(r.ttftSeconds)));
    parts.push(fill(t.turns, r.turns));
    return esc(parts.join(' · '));
  };
  return `<h3>${esc(t.measured)}</h3><ul class="measured">${rows.map(r => `<li><b>${esc(label(r))}</b> ${line(r)}</li>`).join('')}</ul>`;
}
