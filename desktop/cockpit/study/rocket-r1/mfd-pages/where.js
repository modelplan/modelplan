// 去向 (spec 6.5): 项目 | 时间. 项目 is the r5 project ranking (7 | 30 days). 时间 lists every session today or in the
// last 7 days: running first, then ended, filtered by the scope, scrollable. The record strip's "+N ▸" opens it
// as a view (mfd.js openSessionsFromMore). Tokens, never money. Pure view (spec 2.6).
import {t} from '../i18n.js';
import '../strings/review49.js';
import {scopedProject} from '../project-attribution.js';
import {esc, tok, dhm, stamp, chip, bolt} from './fmt.js';
import {accountOf, modelOf, poolsIn, sessionsIn} from './scope.js';

function projects(d, ui) {
  const pools = poolsIn(d, ui);
  let rows = d.projectRanking[ui.days === 7 ? 'recent7d' : 'recent30d'];
  rows = rows.map(p => scopedProject(p, d.accounts.map(a => a.id), ui.scope)).filter(p => p.available !== false);
  if (pools) rows = rows.map(p => ({...p, configs: p.configs.filter(c => !modelOf(d,c.model)?.pool || pools.includes(modelOf(d,c.model).pool))})).filter(p => p.configs.length);
  if (!rows.length) return `<p class="mp-empty">${t('mfd.noSessions')}</p>`;
  const max = Math.max(...rows.map(p => p.tokens), 1);
  // polish A: the rows spread over the screen's height (spacers of 4–14 px between them)
  return `<div class="wh-list">${rows.slice(0, 5).map(p => {
    const c = p.configs[0], m = modelOf(d, c.model), on = c.effort && c.effort === c.recommendedEffort;
    return `<div class="wh"><span class="wh-n">${esc(p.project)}</span><span class="wh-t" title="${esc(t(p.tokenScope === 'unknown' ? 'mfd.projectUnknown' : p.tokenScope === 'combined' ? 'mfd.projectCombined' : 'mfd.projectScoped', {n:tok(p.combinedTokens)}))}">${tok(p.tokens)}</span><i class="wh-bar" ${p.tokens == null ? 'hidden' : ''} style="--p:${p.tokens == null ? 0 : (p.tokens / max * 100).toFixed(0)}%"></i>
      <span class="wh-c">${esc(m?.short || c.model)} ${esc(c.effort || '--')}</span><span class="wh-m ${on ? 'on' : ''}">★${esc(c.recommendedEffort || '')}</span></div>`;  // round D1: ◉★ became a glowing ★
  }).join('<i class="vg" aria-hidden="true"></i>')}</div>`;
}

export function sessionRows(d, ui) {
  const list = sessionsIn(d, ui, ui.time === '7d' ? '7d' : 'today');
  const run = list.filter(x => x.running).sort((a, b) => (b.startedAt ?? b.lastAt) - (a.startedAt ?? a.lastAt)), done = list.filter(x => !x.running).sort((a, b) => (b.lastAt ?? b.endedAt) - (a.lastAt ?? a.endedAt));
  return {run, done};
}
function timeline(d, ui) {
  const {run, done} = sessionRows(d, ui);
  if (!run.length && !done.length) return `<p class="mp-empty">${t('mfd.noSessions')}</p>`;
  const row = x => {
    const a = accountOf(d, x.sub), m = modelOf(d, x.model);
    const time = x.running ? (x.startedAt == null ? '▶' : `▶${dhm((d.now - x.startedAt) / 6e4)}`) : stamp(x.lastAt ?? x.endedAt, ui);
    return `<button class="ws ${x.running ? 'run' : ''}" data-mfd="session:${x.ref}" data-tip="${esc(`${x.tool} · ${x.project}`)}">${chip(a?.colour || 'var(--lcd-muted)')}<span class="ws-m">${esc(m?.short || x.model)} ${esc(x.effort || '--')}${x.fast ? ` ${bolt(t('mfd.fastRow'))}` : ''}</span><span class="ws-p">${esc(x.project)}</span><span class="ws-at">${time}</span><span class="ws-tk">${tok(x.tokens)}</span></button>`;
  };
  return `<div class="ws-list" tabindex="0">${run.length ? `<div class="ws-h">${t('mfd.running')} ${run.length}</div>${run.map(row).join('')}` : ''}${done.length ? `<div class="ws-h">${t(done.every(x => x.lastAt != null) ? 'mfd.lastSeen' : 'mfd.ended')} ${done.length}</div>${done.map(row).join('')}` : ''}</div>`;
}

export const where = {
  id: 'where', title: 'mfd.pWhere',
  optionKeys: ui => [
    {id: 'where', a: {value:'proj', text: t('mfd.oProj'), on: ui.where !== 'time'}, b: {value:'time', text: t('mfd.oTime'), on: ui.where === 'time'}},
    ui.where === 'time' ? {id: 'time', a: {value:'today', text: t('mfd.oToday'), on: ui.time !== '7d'}, b: {value:'7d', text: t('mfd.o7d'), on: ui.time === '7d'}}
      : {id: 'days', a: {value:7, text: '7', on: ui.days === 7}, b: {value:30, text: '30', on: ui.days !== 7}},
    null, null],
  render: (d, ui) => ui.where === 'time' ? timeline(d, ui) : projects(d, ui),
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'where') return {patch: {mfdWhere: ui.optionChoice ?? (ui.where === 'time' ? 'proj' : 'time')}};
    if (act === 'opt' && val === 'time') return {patch: {mfdTime: ui.optionChoice ?? (ui.time === '7d' ? 'today' : '7d')}};
    if (act === 'opt' && val === 'days') return {patch: {mfdDays: ui.optionChoice != null ? Number(ui.optionChoice) : ui.days === 30 ? 7 : 30}};
    if (act === 'session') return {open: ['session', {from: 'mfd', key: val, ref: val}]};
    return null;
  },
};
