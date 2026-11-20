// 去向 (spec 6.5): 项目 | 时间. 项目 is the r5 project ranking (7 | 30 days). 时间 lists every session today or in the
// last 7 days: running first, then ended, filtered by the scope, scrollable. The record strip's "+N ▸" opens it
// as a view (mfd.js openSessionsFromMore). Tokens, never money. Pure view (spec 2.6).
import {t} from '../i18n.js';
import '../strings/review49.js';
import {scopedProject} from '../project-attribution.js';
import {esc, tok, dhm, stamp, chip, bolt} from './fmt.js';
import {accountOf, modelOf, poolsIn, sessionsIn, accountsIn, rangeOf} from './scope.js';
import {rangeWord} from './page-range.js';

// TODO(#1050, WP-06): the ≈cost cell stays empty until the client-v1.6 price data (~11-21) reaches this page.
// 项目 (CKP-MFD-67): one row per project: colour chip, name, model and effort, ≈cost (empty until WP-06's prices reach
// this page), share; the row's background is as long as its share. The range is the header's (page-range.js).
function projects(d, ui) {
  const pools = poolsIn(d, ui), range = rangeOf(ui);
  // The ranking has 7- and 30-day figures; until today's arrives (WP-02) Today says so (CKP-SHELL-50) instead of another range's rows.
  if (range === 'today') return `<p class="mp-empty">${t('mfd.rangeNoToday')}</p>`;
  let rows = d.projectRanking[range === '7d' ? 'recent7d' : 'recent30d'];
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
  const list = sessionsIn(d, ui, rangeOf(ui));
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
  // 项目 | 会话 only: the page has no range key of its own; it follows the header range (V1-FINAL 8.4, CKP-MFD-67).
  optionKeys: ui => [
    {id: 'where', a: {value:'proj', text: t('mfd.oProj'), on: ui.where !== 'time'}, b: {value:'time', text: t('mfd.oSessions'), on: ui.where === 'time'}},
    null, null],
  render: (d, ui) => ui.where === 'time' ? timeline(d, ui) : projects(d, ui),
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'where') return {patch: {mfdWhere: ui.optionChoice ?? (ui.where === 'time' ? 'proj' : 'time')}};
    if (act === 'opt' && val === 'range') return {range: ui.optionChoice};
    if (act === 'session') return {open: ['session', {from: 'mfd', key: val, ref: val}]};
    return null;
  },
};
