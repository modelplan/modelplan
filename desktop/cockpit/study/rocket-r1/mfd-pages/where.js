// 去向 (spec 6.5): 项目 | 时间. 项目 is the r5 project ranking (7 | 30 days). 时间 lists every session today or in the
// last 7 days: running first, then ended, filtered by the scope, scrollable. The record strip's "+N ▸" opens it
// as a view (mfd.js openSessionsFromMore). Tokens, never money. Pure view (spec 2.6).
import {t} from '../i18n.js';
import '../strings/review49.js';
import '../strings/where-usage.js';
import {scopedProject} from '../project-attribution.js';
import {esc, tok, dhm, stamp, chip, bolt, approxCost, when} from './fmt.js';
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
  return `<div class="wd-h">${esc(t('mfd.whProjTitle', {r: rangeWord({range: rangeOf(ui)}), n: rows.length}))}</div><div class="wd-list">${rows.map(p => {
    const c = p.configs[0], m = modelOf(d, c.model), share = p.tokenScope !== 'unknown' && Number.isFinite(p.share) ? Math.round(p.share * 100) : null;
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

// D470 (S13, CKP-MFD-67): with the producer's `history.usage`, every project and session in the header range, ranked by
// total tokens (input + output + cache). Tokens are the big figure, ≈$ small (D464); a 2 pt bar carries the share. The
// Codex Auto Review row and "other N" (past the 200-row cap) keep the shares adding up to the range total.
const usageRange = ui => ({today: 'today', '7d': 'recent7d', '30d': 'recent30d'}[rangeOf(ui)]);
export const usageWindow = (d, ui) => d.usage ? d.usage[usageRange(ui)] : null;
const pctOf = v => Math.round(v * 100);
const kindWord = kind => ({independent: 'mfd.wuIndependent', home: 'mfd.wuHome', none: 'mfd.wuNone'})[kind];
export function projectName(p) {
  if (kindWord(p.kind)) return t(kindWord(p.kind));
  return p.label || t(p.hidden ? 'mfd.wuHidden' : 'mfd.wuUnnamed');
}
export function sessionProject(x) {
  if (kindWord(x.projectKind) || x.projectState === 'none') return t(kindWord(x.projectKind) || 'mfd.wuNone');
  if (x.projectState === 'hidden') return t('mfd.wuHidden');
  return x.projectLabel || t('mfd.wuUnnamed');
}
const modelName = (d, id, approx) => { const m = id ? modelOf(d, id)?.short || id : '--'; return approx && id ? t('mfd.wuApprox', {m}) : m; };
function tokenTip(k) {
  const s = t('mfd.wuTokens', {t: tok(k.total), i: tok(k.input), o: tok(k.output), cr: tok(k.cacheRead), cw: tok(k.cacheWrite)});
  return k.complete ? s : `${s}\n${t('mfd.wuPartial')}`;
}
// §7.1: the full name, the token split, last active and first active.
function rowTip(name, x, ui, extra = []) {
  const cost = approxCost(x.cost);
  return [name, ...extra, tokenTip(x.tokens), t('mfd.wuShare', {s: pctOf(x.share)}), cost ? t('mfd.wuCost', {c: cost}) : '',
    x.lastAt != null ? t('mfd.wuLast', {at: when(x.lastAt, ui)}) : '', x.firstAt != null ? t('mfd.wuFirst', {at: when(x.firstAt, ui)}) : ''].filter(Boolean).join('\n');
}
const cells = x => `<span class="wu-t">${tok(x.tokens.total)}</span><span class="wd-m">${esc(approxCost(x.cost) || '')}</span><span class="wd-s">${pctOf(x.share)}%</span><i class="wu-bar" data-p="${pctOf(x.share)}"></i>`;
const runMark = on => on ? '<b class="wu-run" aria-hidden="true">▶</b>' : '';
function extras(w, ui) {
  const out = [];
  if (!ui.scope && w.review) out.push({review: true, tokens: w.review.tokens, share: w.review.share, cost: w.review.cost, lastAt: w.review.lastAt, firstAt: null, runs: w.review.runs, model: w.review.model});
  return out;
}
function reviewRow(d, r, ui) {
  const name = t('mfd.wuReview');
  return `<div class="wd wu wu-review" data-tip="${esc(rowTip(name, r, ui, [t('mfd.wuReviewTip'), modelName(d, r.model, true)]))}"><i class="chip" data-v="var(--lcd-muted)"></i><span class="wd-n">${esc(name)} <em class="wd-c">${esc(t('mfd.wuReviewRuns', {n: r.runs}))}</em></span>${cells(r)}</div>`;
}
function otherRow(o, ui) {
  if (ui.scope || !o.count) return '';
  const name = t('mfd.wuOther', {n: o.count});
  return `<div class="wd wu wu-other" data-tip="${esc(rowTip(name, o, ui))}"><i class="chip" data-v="var(--lcd-ghost)"></i><span class="wd-n">${esc(name)}</span>${cells(o)}</div>`;
}
const byTokens = (a, b) => b.tokens.total - a.tokens.total;
// The range header with its measured total (board ①): "7d · 12 projects · 1.2B · ≈$310"; scoped, the count only, since
// the window total is all subscriptions'.
function header(text, w, ui) {
  const cost = approxCost(w.cost), total = ui.scope ? '' : ` · ${tok(w.tokens.total)}${cost ? ` · ${cost}` : ''}`;
  return `<div class="wd-h">${esc(text + total)}</div>`;
}
// macrevb-1303-6: the lists are the producer's top rows of all subscriptions; a scope or a project filter can only
// show what is listed, so a cut is said, never shown as "no sessions".
const cutNote = (count, ui) => ui.scope && count > 0 ? `<p class="wu-cut">${esc(t('mfd.wuCutScope'))}</p>` : '';
// The share bar is the subscription's colour when one subscription holds the row; several (or none) stay neutral, as
// the wire has no per-subscription split yet. Buckets are grey (board ①).
const barColour = (d, subs, bucket) => !bucket && subs.length === 1 ? accountOf(d, subs[0])?.colour ?? null : null;
const withBar = (html, colour) => colour ? html.replace('<i class="wu-bar"', `<i class="wu-bar" data-v="${esc(colour)}"`) : html;
function usageProjects(d, ui, w) {
  const rows = w.projects.filter(p => !ui.scope || p.subs.includes(ui.scope));
  const list = [...rows, ...extras(w, ui)].sort(byTokens);
  if (!list.length) return `<p class="mp-empty">${t('mfd.noSessions')}</p>${cutNote(w.otherProjects.count, ui)}`;
  const n = ui.scope ? rows.length : w.projectCount;
  return `${header(t('mfd.whProjTitle', {r: rangeWord({range: rangeOf(ui)}), n}), w, ui)}<div class="wd-list wu-list" tabindex="0">${list.map(p => {
    if (p.review) return reviewRow(d, p, ui);
    const bucket = !!kindWord(p.kind), name = projectName(p), colour = bucket ? 'var(--lcd-muted)' : accountOf(d, p.subs[0])?.colour || 'var(--lcd-muted)';
    const meta = [t('mfd.wuSessions', {n: p.sessions}), modelName(d, p.model, p.modelApprox) + (p.effort ? ' ' + p.effort : ''), ui.scope ? t('mfd.wuCombined') : ''].filter(Boolean);
    return `<button class="wd wu${bucket ? ' wu-bucket' : ''}" type="button" data-mfd="proj:${esc(p.ref)}" data-tip="${esc(rowTip(name, p, ui, meta))}"><i class="chip" data-v="${esc(colour)}"></i><span class="wd-n">${runMark(p.running)}${esc(name)}</span>${withBar(cells(p), barColour(d, p.subs, bucket))}</button>`;
  }).join('')}${otherRow(w.otherProjects, ui)}</div>${cutNote(w.otherProjects.count, ui)}`;
}
function usageSessions(d, ui, w) {
  let rows = w.sessions.filter(x => !ui.scope || x.sub === ui.scope);
  const project = ui.project ? w.projects.find(p => p.ref === ui.project) : null;
  if (ui.project) rows = rows.filter(x => (x.projectRef ?? 'unattributed') === ui.project);
  const back = ui.project ? `<button class="wu-back" type="button" data-mfd="where:all">${esc(t('mfd.wuAllSessions'))}</button>` : '';
  // macrevb-1303-7: the Auto Review row joins before the empty test, so a range with only background runs shows them.
  // D470 (recommendation 4): sorted by tokens; a running session is marked ▶, not pinned.
  const list = [...rows, ...(ui.project ? [] : extras(w, ui))].sort(byTokens);
  // macrevb-1303-6: a project's sessions below the listed top are one continuation row with their exact remainder. In a
  // scoped view the wire has no per-subscription project total, so no remainder is computed (the project's count and
  // tokens are all subscriptions'): a note says only this subscription's top sessions are listed, with no numbers.
  let more = null;
  const scopedCut = !!(ui.scope && project && project.sessions > rows.length);
  if (project && !ui.scope && project.sessions > rows.length) {
    const tokens = Math.max(0, project.tokens.total - rows.reduce((s, x) => s + x.tokens.total, 0));
    more = {count: project.sessions - rows.length, tokens: {...project.tokens, total: tokens, complete: false}, share: Math.max(0, project.share - rows.reduce((s, x) => s + x.share, 0)), cost: null};
  }
  const scopedNote = scopedCut ? `<p class="wu-cut">${esc(t('mfd.wuScopedTop'))}</p>` : '';
  if (!list.length && !more && !scopedCut) return `${back}<p class="mp-empty">${t('mfd.noSessions')}</p>${cutNote(w.otherSessions.count, ui)}`;
  const title = project ? t('mfd.wuProjSess', {p: projectName(project), n: ui.scope ? rows.length : project.sessions}) : t('mfd.whSessTitle', {r: rangeWord({range: rangeOf(ui)}), n: ui.scope ? rows.length : w.sessionCount});
  const moreRow = more ? `<div class="wd wu wu-other" data-tip="${esc(t('mfd.wuMoreBelow', {n: more.count}))}"><i class="chip" data-v="var(--lcd-ghost)"></i><span class="wd-n">${esc(t('mfd.wuMoreBelow', {n: more.count}))}</span>${cells(more)}</div>` : '';
  return `${back}${project ? `<div class="wd-h">${esc(title)}</div>` : header(title, w, ui)}<div class="wd-list wu-list wu-sess" tabindex="0">${list.map(x => {
    if (x.review) return reviewRow(d, x, ui);
    const a = accountOf(d, x.sub), name = x.title || t('mfd.wuUntitled'), where = sessionProject(x);
    const meta = `${x.tool} · ${where} · ${modelName(d, x.model, x.modelApprox)}${x.effort ? ' ' + x.effort : ''} · ${x.running ? '▶' : stamp(x.lastAt, ui)}`;
    return `<div class="wd wu wu-s${x.running ? ' run' : ''}" data-session="${esc(x.ref)}" data-tip="${esc(rowTip(name, x, ui, [`${x.tool} · ${where}`, modelName(d, x.model, x.modelApprox)]))}"><i class="chip" data-v="${esc(a?.colour || 'var(--lcd-muted)')}"></i><span class="wd-n">${runMark(x.running)}${esc(name)}<small class="wu-meta">${esc(meta)}</small></span>${withBar(cells(x), a?.colour ?? null)}</div>`;
  }).join('')}${moreRow}${ui.project ? '' : otherRow(w.otherSessions, ui)}</div>${ui.project ? scopedNote : cutNote(w.otherSessions.count, ui)}`;
}

export const where = {
  id: 'where', title: 'mfd.pWhere',
  // 项目 | 会话 only: the page has no range key of its own; it follows the header range (V1-FINAL 8.4, CKP-MFD-67).
  optionKeys: ui => [
    {id: 'where', a: {value:'proj', text: t('mfd.oProj'), on: ui.where !== 'time'}, b: {value:'time', text: t('mfd.oSessions'), on: ui.where === 'time'}},
    null, null],
  render: (d, ui) => { const w = usageWindow(d, ui); if (w) return ui.where === 'time' ? usageSessions(d, ui, w) : usageProjects(d, ui, w); return ui.where === 'time' ? timeline(d, ui) : projects(d, ui); },
  onClick(act, val, ui) {
    if (act === 'opt' && val === 'where') return {patch: {mfdWhere: ui.optionChoice ?? (ui.where === 'time' ? 'proj' : 'time')}};
    if (act === 'opt' && val === 'range') return {range: ui.optionChoice};
    if (act === 'session') return {open: ['session', {from: 'mfd', key: val, ref: val}]};
    return null;
  },
};
