// 去向 (spec 6.5): 项目 | 时间. 项目 is the r5 project ranking (7 | 30 days). 时间 lists every session today or in the
// last 7 days: running first, then ended, filtered by the scope, scrollable. The record strip's "+N ▸" opens it
// as a view (mfd.js openSessionsFromMore). Tokens, never money. Pure view (spec 2.6).
import {t} from '../i18n.js';
import '../strings/review49.js';
import {scopedProject} from '../project-attribution.js';
import {esc, tok, dhm, stamp, chip, bolt} from './fmt.js';
import {accountOf, modelOf, poolsIn, sessionsIn, accountsIn} from './scope.js';
import {PAGE_RANGES, rangeWord} from './page-range.js';

// The range this page shows: the app's (ui.range, WP-09) when it exists; until then the page's own keys, as before
// (sessions: today | 7d; projects: 7 | 30 days).
const rangeOf = ui => PAGE_RANGES.includes(ui.range) ? ui.range : ui.where === 'time' ? (ui.time === '7d' ? '7d' : 'today') : ui.days === 7 ? '7d' : '30d';

// 项目 (CKP-MFD-67): one row per project: colour chip, name, model and effort, ≈cost (empty until WP-06's prices reach
// this page), share; the row's background is as long as its share. The range is the header's (page-range.js).
function projects(d, ui) {
  const pools = poolsIn(d, ui), range = rangeOf(ui);
  // The ranking has 7- and 30-day figures; Today has none yet, so it reads as an empty period, not another range's rows.
  let rows = range === 'today' ? [] : d.projectRanking[range === '7d' ? 'recent7d' : 'recent30d'];
  rows = rows.map(p => scopedProject(p, d.accounts.map(a => a.id), ui.scope)).filter(p => p.available !== false);
  if (pools) rows = rows.map(p => ({...p, configs: p.configs.filter(c => !modelOf(d,c.model)?.pool || pools.includes(modelOf(d,c.model).pool))})).filter(p => p.configs.length);
  if (!rows.length) return `<p class="mp-empty">${t('mfd.noSessions')}</p>`;
  const accounts = accountsIn(d, ui);
  return `<div class="wd-h">${esc(t('mfd.whProjTitle', {r: rangeWord({range: rangeOf(ui)}), n: rows.length}))}</div><div class="wd-list">${rows.slice(0, 8).map(p => {
    const c = p.configs[0], m = modelOf(d, c.model), share = Number.isFinite(p.share) ? Math.round(p.share * 100) : null;
    const colour = accounts.find(a => a.pool && m?.pool === a.pool)?.colour || 'var(--lcd-muted)';
    return `<div class="wd" data-p="${share ?? 0}"><i class="chip" data-v="${esc(colour)}"></i><span class="wd-n">${esc(p.project)}</span><span class="wd-c">${esc(m?.short || c.model)} ${esc(c.effort || '--')}</span><span class="wd-m" data-cost></span><span class="wd-s">${share == null ? '' : share + '%'}</span></div>`;
  }).join('')}</div>`;
}

export function sessionRows(d, ui) {
  // sessionsIn knows Today and 7 days; 30 days reads as 7 until WP-09 (#1047) widens it.
  const list = sessionsIn(d, ui, rangeOf(ui) === 'today' ? 'today' : '7d');
  const run = list.filter(x => x.running).sort((a, b) => (b.startedAt ?? b.lastAt) - (a.startedAt ?? a.lastAt)), done = list.filter(x => !x.running).sort((a, b) => (b.lastAt ?? b.endedAt) - (a.lastAt ?? a.endedAt));
  return {run, done};
}
function timeline(d, ui) {
  const {run, done} = sessionRows(d, ui);
  if (!run.length && !done.length) return `<p class="mp-empty">${t('mfd.noSessions')}</p>`;
  const row = x => {
    const a = accountOf(d, x.sub), m = modelOf(d, x.model);
    const time = x.running ? (x.startedAt == null ? '▶' : `▶${dhm((d.now - x.startedAt) / 6e4)}`) : stamp(x.lastAt ?? x.endedAt, ui);
    return `<button class="ws ${x.running ? 'run' : ''}" type="button" aria-disabled="true" tabindex="-1" data-mfd="session:${x.ref}" data-tip="${esc(`${x.tool} · ${x.project}`)}">${chip(a?.colour || 'var(--lcd-muted)')}<span class="ws-m">${esc(m?.short || x.model)} ${esc(x.effort || '--')}${x.fast ? ` ${bolt(t('mfd.fastRow'))}` : ''}</span><span class="ws-p">${esc(x.project)}</span><span class="ws-at">${time}</span><span class="ws-tk">${tok(x.tokens)}</span></button>`;
  };
  return `<div class="wd-h">${esc(t('mfd.whSessTitle', {r: rangeWord({range: rangeOf(ui)}), n: run.length + done.length}))}</div><div class="ws-list" tabindex="0">${run.length ? `<div class="ws-h">${t('mfd.running')} ${run.length}</div>${run.map(row).join('')}` : ''}${done.length ? `<div class="ws-h">${t(done.every(x => x.lastAt != null) ? 'mfd.lastSeen' : 'mfd.ended')} ${done.length}</div>${done.map(row).join('')}` : ''}</div>`;
}

export const where = {
  id: 'where', title: 'mfd.pWhere',
  // 项目 | 会话, and, until the app's own range (WP-09) reaches the page, the range key it always had (CKP-MFD-67: the
  // page has no range key of its own once the header's range exists).
  optionKeys: ui => [
    {id: 'where', a: {value:'proj', text: t('mfd.oProj'), on: ui.where !== 'time'}, b: {value:'time', text: t('mfd.oSessions'), on: ui.where === 'time'}},
    PAGE_RANGES.includes(ui.range) ? null
      : ui.where === 'time' ? {id: 'time', a: {value:'today', text: t('mfd.oToday'), on: ui.time !== '7d'}, b: {value:'7d', text: t('mfd.o7d'), on: ui.time === '7d'}}
      : {id: 'days', a: {value:7, text: '7', on: ui.days === 7}, b: {value:30, text: '30', on: ui.days !== 7}},
    null, null],
  render: (d, ui) => ui.where === 'time' ? timeline(d, ui) : projects(d, ui),
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'where') return {patch: {mfdWhere: ui.optionChoice ?? (ui.where === 'time' ? 'proj' : 'time')}};
    if (act === 'session') return {open: ['session', {from: 'mfd', key: val, ref: val}]};
    return null;
  },
};
