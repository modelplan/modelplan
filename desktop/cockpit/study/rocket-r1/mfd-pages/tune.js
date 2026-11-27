import {websiteWords,modelUrl,methodologyUrl} from './public-helpers.js';
import {secondaryLink} from './public-helpers.js';
// 模型: the shared scope selection, including eligible older versions actually used in the last week.
// The HUD opens this page as a view
// (return rule). Pure view (spec 2.6).
import {t} from '../i18n.js';
import {fill, esc, approxCost} from './fmt.js';
import {chartModels, currentOf, accountsIn} from './scope.js';
import {pageRange, rangeWord, pct} from './page-range.js';
import {frontierSvg} from './frontier.js';
import {withOlderLabel} from './public-helpers.js';

// CKP-MFD-65 (V1-FINAL 8.3): the usage list. One row per known model: colour chip, model, current effort and the
// recommended one, a share bar, ≈cost (from WP-06's price data; empty for a model without a public price), share. Models in use come
// first by their share of the range's tokens; unused ones follow in the published order, dimmed. With no usage record
// at all the list is in the published (recommendation) order and the share and ≈cost columns stay empty.
export function usageRows(d, ui) {
  const range = pageRange(ui), scoped = !!ui.scope;
  // A subscription scope has no scoped attribution for the ranking or the price data, so shares and ≈cost stay unknown there.
  const ranking = scoped ? null : range === '30d' ? d.modelRanking?.recent30d : range === '7d' ? d.modelRanking?.recent7d : null;
  const used = new Map((ranking?.top ?? []).map(r => [r.name, r]));
  const candidates = d.listModels ?? chartModels(d, ui);
  const active = candidates.filter(m => m.latestEffort !== undefined);
  // Recent models remain selectable beyond the chart's ten-model cap; keep unused choices available as well.
  const field = [...active, ...candidates.filter(m => m.latestEffort === undefined).slice(0, Math.max(1, 10 - active.length))];
  // A model the history ranks as used stays listed even when it falls outside the ten-model field (macrevc-1058-4).
  const extra = (d.listModels ?? []).filter(m => used.has(m.id) && !field.some(f => f.id === m.id));
  const ms = [...field, ...extra].map(m => withOlderLabel(m, t('mfd.olderBadge')));
  const rows = ms.map((m, order) => ({m, order, tokens: used.get(m.id)?.tokens ?? null}));
  rows.sort((a, b) => (b.tokens ?? -1) - (a.tokens ?? -1) || a.order - b.order);
  // The share's whole is every known model's tokens, so the shares of the rows shown add up.
  const total = rows.reduce((sum, r) => sum + (r.tokens ?? 0), 0);
  return {rows, total, hasUsage: rows.some(r => r.tokens != null)};
}
// The price data has 7- and 30-day model rows; Today has none on this page yet, so it shows no ≈$ rather than another range's.
const costKey = ui => ui.scope ? undefined : ({'7d': 'recent7d', '30d': 'recent30d'})[pageRange(ui)];
// A known estimate of exactly zero reads "≈$0"; a model without a price has no entry at all, so its cell stays empty.
const costText = v => v === 0 ? '≈$0' : approxCost(v);
const totalCost = (d, ui) => { const v = approxCost(d.modelCost?.total?.[costKey(ui)]); return v ? ` · ${esc(v)}` : ''; };
function list(d, ui) {
  if (pageRange(ui) === 'today') return `<p class="mp-empty period">${t('mfd.rangeNoToday')}</p>`; // no per-model ranking for Today yet (macrevc-1058-7)
  const {rows, total, hasUsage} = usageRows(d, ui);
  if (!rows.length) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const inUse = rows.filter(r => r.tokens != null).length, accounts = accountsIn(d, ui);
  const body = rows.map(({m, tokens}) => {
    const cur = currentOf(d, ui, m.id)?.effort, share = pct(tokens, total), colour = accounts.find(a => a.pool && a.pool === m.pool)?.colour || 'var(--lcd-muted)';
    const idle = hasUsage && tokens == null, cost = d.modelCost?.[costKey(ui)]?.[m.id];
    return `<button type="button" data-p="${share ?? 0}" class="md-row ${idle ? 'idle' : ''} ${ui.selModel === m.id ? 'sel' : ''}" data-mfd="model:${esc(m.id)}" data-model="${esc(m.id)}" aria-label="${esc(t('mfd.mdRowAria', {m: m.name}))}"${idle ? ` title="${esc(t('mfd.mdUnused'))}"` : ''}><i class="chip" data-v="${esc(colour)}"></i><b class="md-n">${esc(m.short || m.name)}</b><span class="md-e"><span class="md-cur">${cur ? esc(cur) : ''}</span>${m.rec ? `<i class="md-star">★${esc(m.rec)}</i>` : ''}</span><i class="md-bar" aria-hidden="true"></i><span class="md-c" data-cost>${esc(cost == null ? '' : costText(cost) ?? '')}</span><span class="md-s">${share == null ? '' : share + '%'}</span></button>`;
  }).join('');
  return `<div class="md-h">${esc(t('mfd.mdTitle', {r: rangeWord(ui), n: hasUsage ? inUse : rows.length}))}${totalCost(d, ui)}</div><div class="md-list" data-usage="${hasUsage}">${body}</div>`;
}

// 图 (CKP-MFD-66, amended by G3-168): the ability-cost frontier of the user's models. Every model carries its name on the
// chart (offset or on a leader line where they would collide); hover still adds the point's full detail.
function chart(d, ui) {
  const first = usageRows(d, ui).rows[0]?.m.id, field = chartModels(d, ui);
  // A model selected or ranked first from the list stays on the chart even outside the ten-model field (macrevc-1058-11).
  const extra = (d.listModels ?? []).filter(m => (m.id === ui.selModel || m.id === first) && !field.some(f => f.id === m.id));
  const ms = [...field, ...extra].map(m => withOlderLabel(m, t('mfd.olderBadge')));
  if (!ms.length) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
  const {w, h} = fill(ui, 'fc', {w: 260, h: 180}), current = {};
  for (const m of ms) { const c = currentOf(d, ui, m.id); if (c?.effort) current[m.id] = c.effort; }
  return `<div class="mfd-fill" data-fill="fc" data-models="${ms.map(m => m.id).join(' ')}">${frontierSvg(ms, {w, h, current, trial: ui.trials, selected: ui.selModel,
    axis: {ability: t('mfd.ability'), cost: t('mfd.cost')}, aria: t('mfd.frontierAria')})}<span class="tune-links">${secondaryLink(modelUrl(ms.find(m => m.id === ui.selModel)?.id || ms[0].id), websiteWords(ui.lang).compare)} ${secondaryLink(methodologyUrl('effort-ladder'), websiteWords(ui.lang).how)}</span></div>`;
}

export const tune = {
  id: 'tune', title: 'mfd.pTune',
  // 列表 | 图 (the list is the default); the other slots stay in place.
  optionKeys: ui => [{id: 'models', a: {value: 'list', text: t('mfd.oList'), on: ui.models !== 'chart'}, b: {value: 'chart', text: t('mfd.oChart'), on: ui.models === 'chart'}}, null, null, null],
  render: (d, ui) => ui.models === 'chart' ? chart(d, ui) : list(d, ui),
  // A row selects the model, the same as pressing its card (the deck takes {select}).
  onClick(act, val) { return act === 'model' ? {select: val} : null; },
};
