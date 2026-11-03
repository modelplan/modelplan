import {websiteWords,planUrl} from './public-helpers.js';
import {secondaryLink} from './public-helpers.js';
// 订阅 (spec 6.2, CodexBar-style reserve). Under 全部: one line per subscription (pressing one scopes to it, like
// its engine key). In a subscription scope, two halves on the 概况 | 记录 key:
//   概况: header; windows (bar, %, absolute reset time, countdown); 重置卡; 点数; 高峰时段.
//   记录: header; 重置记录 with sources (自然到期 / 官方 / 重置卡 / 修正); 周期历史 (10 cycles, stacked by model / effort / fast).
// Pure view (spec 2.6).
import {t} from '../i18n.js';
import {esc, tok, dhm, grouped, hm, when, stamp, until, md, bar10, level, chip, clockIcon, tip, fill, relativeMoment, resetMoment} from './fmt.js';
import {accountOf, modelOf} from './scope.js';
import {fillColour} from '../colour-mode.js';

const VIA = {native: 'mfd.viaNative', codexbar: 'mfd.viaCodexbar', manual: 'mfd.viaManual'};
const tightest = a => [...a.windows].filter(w => w.remaining != null).sort((x, y) => x.remaining - y.remaining)[0] || a.windows[0];
const lvOf = (r, ui) => r === 0 ? 'low' : level(r, ui.redAt); // used up is red; otherwise the one rule (spec 2.1)
// round D2: the 10-segment bar's lit segments take fillColour() (status colours, or the subscription's identity colour
// in brand mode); the percentage keeps its status colour, so the status still shows in brand mode.
const qbar = (r, lv, colour) => { const f = fillColour(lv, colour); return f ? bar10(r, lv).replace(/<i class="on">/g, `<i class="on" style="background:${f}">`) : bar10(r, lv); };

// Keep the canonical white Z intrinsic: the generic monochrome path masks with vendor ink.
export const glyph = a => (a.colourLogo || ['nozzle-p1/zai-white.svg', 'zhipu.svg'].includes(a.logo)) ? `<img class="mg orig" src="assets/brands/${esc(a.logo)}" alt="">`
  : `<i class="mg" style="--v:${a.colour};-webkit-mask-image:url('assets/brands/${esc(a.logo)}');mask-image:url('assets/brands/${esc(a.logo)}')"></i>`;

function header(a) {
  const age = a.ageMin == null ? t('mfd.ageNow') : a.ageMin >= 60 ? t('age.hours', {h: Math.round(a.ageMin / 60)}) : t('mfd.ageMin', {m: a.ageMin});
  return `<div class="sp-h">${glyph(a)}<b>${esc(a.name)}</b>${secondaryLink(planUrl(a.vendor),websiteWords().plans)}</div><div class="sp-sub"><em class="pl">${esc(a.plan)}</em><em title="${esc(a.source === 'native' || !VIA[a.source] ? 'modelplan CLI' : t(VIA[a.source]))}" class="src ${a.state === 'ok' ? '' : 'amber'}">${t(VIA[a.source] || 'mfd.viaNative')} · ${esc(age)}</em></div>`;
}

/* ---------- 概况 ---------- */
// 专项: one line per extra quota under the subscription's windows (name with period, bar, %, reset, countdown or run-out).
function extraLine(w, ui, stale, colour) {
  const r = w.remaining, lv = lvOf(r, ui), abs = resetMoment(w,ui);
  const cd = w.trend != null && w.trend < 0 && w.runOutMin != null ? `<em class="amber">${t('mfd.runOut', {t: dhm(w.runOutMin)})}</em>` : `<em>${w.resetIn != null ? dhm(w.resetIn) : ''}</em>`;
  return `<div class="sp-w x ${stale ? 'stale' : ''}"><span class="lbl">${esc(w.label)}</span>${qbar(r, lv, colour)}<b class="v lv-${lv}">${r == null ? '--' : r + '%'}</b><span class="abs">${esc(abs)}</span>${cd}</div>`;
}
function windows(a, ui) {
  const runOutW = a.forecast ? a.windows.find(w => w.trend != null && w.trend < 0) : null;
  return a.windows.map(w => {
    const r = w.remaining, lv = lvOf(r, ui), abs = resetMoment(w,ui);
    const cd = w === runOutW ? `<em class="amber">${t('mfd.runOut', {t: dhm(a.forecast.runOutMin)})}</em>` : `<em>${w.resetIn != null ? dhm(w.resetIn) : ''}</em>`;
    return `<div class="sp-w ${a.state === 'ok' ? '' : 'stale'}"><span class="lbl">${esc(w.label)}</span>${qbar(r, lv, a.colour)}<b class="v lv-${lv}">${r == null ? '--' : r + '%'}</b><span class="abs">${esc(abs)}</span>${cd}</div>`;
  }).join('') + a.extras.map(w => extraLine(w, ui, a.state !== 'ok', a.colour)).join('');
}
// CodexBar's reset credits: "可用 N 张", a clock, up to four compact expiries and "+N"; hover lists every card.
export function cardsBlock(a, ui) {
  const cards = a.cards;
  if (!cards.length) return '';
  const near = c => (c.expiresAt - ui.now) / 3600e3 <= 48, anyNear = cards.some(near);
  const shown = cards.slice(0, 4), more = cards.length - shown.length;
  const lines = cards.map(c => `${t('mfd.cardExp', {d: relativeMoment(c.expiresAt,ui,true)})}${near(c) ? ' ●' : ''}`);
  return `<div class="rc ${anyNear ? 'near' : ''}" data-tip="${tip(lines)}" aria-label="${esc(t('mfd.cardsAria', {n: cards.length, d: relativeMoment(Math.min(...cards.map(c=>c.expiresAt)),ui,true)}))}">
    <span class="lbl">${t('mfd.cards')}</span><b class="${anyNear ? 'amber' : ''}">${t('mfd.cardsN', {n: cards.length})}</b>${clockIcon()}
    <span class="rc-exp">${shown.map(c => `<i class="${near(c) ? 'amber' : ''}">${until(c.expiresAt, ui)}</i>`).join('<s>·</s>')}${more ? `<i class="more">+${more}</i>` : ''}</span></div>`;
}
// Credits: balance + reading time; used / limit / remaining and its reset when reported; 30 daily bars + total;
// the used-up state.
export function creditsBlock(a, ui) {
  const c = a.credits;
  if (!c) return '';
  // polish A: the 30 daily bars take the screen's width (label 40, the total about 64)
  const W = Math.max(120, Math.min(240, fill(ui, 'page', {w: 330, h: 170}).w - 16 - 40 - 64 - 12));
  const max = Math.max(...c.daily30, 1), bw = W / 30, sum = c.daily30.reduce((s, v) => s + v, 0);
  const bars = c.daily30.map((v, i) => `<rect data-tip="${tip([t('mfd.credits'),grouped(v),relativeMoment(ui.now-(29-i)*864e5,ui)])}" x="${(i * bw + .5).toFixed(1)}" y="${(14 - v / max * 13).toFixed(1)}" width="${(bw - 1).toFixed(1)}" height="${(v / max * 13 + .6).toFixed(1)}"/>`).join('');
  const left = c.limit ? Math.round((c.limit - c.used) / c.limit * 100) : null;
  return `<div class="cr-l"><span class="lbl">${t('mfd.credits')}</span><b class="cr-bal">${grouped(c.balance)}</b><em>${t('mfd.creditsRead', {t: relativeMoment(c.readAt,ui)})}</em></div>
    ${c.limit ? `<div class="cr-l sub"><span class="lbl"></span><span class="lv-${level(left, ui.redAt)}">${t('mfd.creditsLimit', {u: grouped(c.used), l: grouped(c.limit), r: left})}</span>${c.resetsAt ? `<em>${t('mfd.creditsReset', {t: dhm((c.resetsAt - ui.now) / 6e4)})}</em>` : ''}</div>` : ''}
    <div class="cr-l sub"><span class="lbl"></span><svg class="cr-30" viewBox="0 0 ${W} 15" width="${W}" height="15" aria-hidden="true">${bars}</svg><em>${t('mfd.credits30', {n: tok(sum)})}</em></div>
    ${c.drawing ? `<div class="cr-l sub draw"><span class="lbl"></span><b class="lv-low">${t('mfd.drawing')}</b>${c.drawingSince ? `<em>${t('mfd.drawingFor', {t: dhm((ui.now - c.drawingSince) / 6e4)})}</em>` : ''}</div>` : ''}`;
}
function peak(a, ui) {
  if (!a.peak) return '';
  const day = new Date(ui.now); day.setHours(0, 0, 0, 0);
  const x = ms => ((ms - day.getTime()) / 864e5 * 80).toFixed(1), live = ui.now >= a.peak.from && ui.now < a.peak.until;
  return `<div class="pk-l"><span class="lbl">${t('mfd.peak')}</span><span>${hm(a.peak.from)}–${hm(a.peak.until)}</span>
    <svg class="pk-strip" viewBox="0 0 80 8" width="80" height="8" aria-hidden="true"><rect class="tr" x="0" y="3" width="80" height="2"/><rect class="band" x="${x(a.peak.from)}" y="2" width="${(x(a.peak.until) - x(a.peak.from)).toFixed(1)}" height="4"/><rect class="now" x="${x(ui.now)}" y="0" width="1" height="8"/></svg>
    <em>${live ? t('mfd.peakNow') : t('mfd.peakIn', {t: dhm((a.peak.from - ui.now) / 6e4)})}</em></div>`;
}

/* ---------- 记录 ---------- */
const SRC = {natural: 'mfd.srcNatural', official: 'mfd.srcOfficial', card: 'mfd.srcCard', correction: 'mfd.srcFix'};
function resets(a, ui, kind) {
  const rows = a.resets.filter(r => r.kind === kind).slice(0, 4);
  if (!rows.length) return `<p class="mp-empty sm">${t('mfd.noResets')}</p>`;
    return `<div class="rs-list">${rows.map(r => `<div class="rs src-${r.source} ${r.pending ? 'pending' : ''}"><span class="rs-at">${relativeMoment(r.at,ui)}</span>
    <b class="rs-src">${r.source === 'card' ? '↺ ' : ''}${t(SRC[r.source])}</b><em>${r.pending ? t('mfd.srcPending') : r.waiting ? t('mfd.srcWaiting') : ''}</em></div>`).join('')}</div>`;
}
// The last 10 cycles of a window: bars of the points used, stacked by model / effort / fast (vendor colour in
// steps; fast is hatched); a cycle with a meter drop (a reset card) carries ↺. Hover lists the breakdown.
export function cycles(d, a, ui, kind) {
  const list = d.paceHistory[a.id]?.[kind] || [];
  if (!list.length) return '';
  const {w: W, h: H} = fill(ui, 'cyc', {w: 250, h: 60}), n = list.length, bw = W / n, top = 9, base = H - 1;
  const keyOf = s => `${s.model}|${s.effort}|${s.fast}`, keys = [...new Set(list.flatMap(c => c.spent.map(keyOf)))];
  const op = k => [1, .66, .44, .3, .2][keys.indexOf(k)] ?? .2;
  const Yp = p => (base - top) * p / 100;
  const bars = list.map((c, i) => {
    const x = i * bw + bw * .18, w = bw * .64, name = s => `${modelOf(d, s.model)?.short || s.model} ${s.effort || '--'}${s.fast ? ' ⚡' : ''}`;
    const lines = [t('mfd.cycleTip', {when: `${relativeMoment(Date.parse(c.start), ui)}–${relativeMoment(Date.parse(c.end), ui)}`, p: c.points}), ...c.spent.map(s => `${name(s)} · ${s.points}`), c.hadDrop ? t('mfd.cycleDrop') : ''];
    let y = base, segs;
    if (c.spent.length) segs = c.spent.map(s => { const h = Yp(s.points); y -= h; return `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w.toFixed(1)}" height="${Math.max(0, h).toFixed(1)}" fill="${s.fast ? 'url(#mfd-hatch)' : 'var(--cv)'}" fill-opacity="${s.fast ? 1 : op(keyOf(s))}"/>`; }).join('');
    else { const h = Yp(c.points); segs = `<rect x="${x.toFixed(1)}" y="${(base - h).toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" fill="var(--cv)" fill-opacity=".7"/>`; }
    return `<g class="cy" data-tip="${tip(lines)}"><rect class="hit" x="${(i * bw).toFixed(1)}" y="0" width="${bw.toFixed(1)}" height="${H}"/>${segs}${c.hadDrop ? `<text class="drop" x="${(x + w / 2).toFixed(1)}" y="${(base - Yp(c.points) - 2).toFixed(1)}" text-anchor="middle">↺</text>` : ''}</g>`;
  }).join('');
  return `<svg class="cy-chart" style="--cv:${a.colour}" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${t('mfd.cycles')}">
    <defs><pattern id="mfd-hatch" width="3" height="3" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="3" height="3" fill="var(--cv)" fill-opacity=".25"/><rect width="1.4" height="3" fill="var(--cv)"/></pattern></defs>
    <path class="cy-100" d="M0 ${top}H${W}"/><path class="cy-base" d="M0 ${base}H${W}"/>${bars}</svg>`;
}

/* ---------- 全部: one row per subscription ---------- */
// polish A: rows spread over the screen's height (a spacer of up to 14 px between rows); when every row fits on two
// lines, the second line gives the plan, the tightest window and its absolute reset time. More rows than fit still
// scroll, as before.
const VG = '<i class="vg" aria-hidden="true"></i>';
// 专项 under its subscription in the list: the name with its period, the bar, the percentage and the time to the reset.
const extraRow = (x, ui, colour) => { const lv = lvOf(x.remaining, ui); return `<div class="sa-x" data-tip="${tip([x.label, resetMoment(x,ui)])}"><b>${esc(x.label)}</b>${qbar(x.remaining, lv, colour)}<span class="v lv-${lv}">${x.remaining == null ? '--' : x.remaining + '%'}</span><em>${x.resetIn != null ? dhm(x.resetIn) : '--'}</em></div>`; };
function list(d, ui) {
  const n = d.accounts.length, nx = d.accounts.reduce((k, a) => k + a.extras.length, 0), h = fill(ui, 'page', {w: 330, h: 170}).h - 12, two = n * 30 + (n - 1) * 2 + nx * 15 <= h;
  return `<div class="sa-list ${two ? 'two' : ''}">${d.accounts.map(a => {
    const w = tightest(a), r = w?.remaining, lv = lvOf(r, ui), near = a.cards.some(c => (c.expiresAt - ui.now) / 3600e3 <= 48);
    const reserve = [a.cards.length ? `<i class="${near ? 'amber' : ''}">↺${a.cards.length}</i>` : '', a.credits ? `<i class="${a.credits.drawing ? 'lv-low' : ''}">${tok(a.credits.balance)}</i>` : ''].join('');
    const abs = w ? resetMoment(w,ui) : '';
    const sub = two ? `<span class="sa-d">${esc([a.plan, w?.label, abs].filter(Boolean).join(' · '))}</span>` : '';
    return `<button class="sa" data-mfd="scope:${a.id}" data-col="${a.id}" data-tip="${tip([a.name, `${w?.label || ''} · ${abs}`])}">${chip(a.colour)}<b>${esc(a.short)}</b>${qbar(r, lv, a.colour)}<span class="v lv-${lv}">${r == null ? '--' : r + '%'}</span><em>${w?.resetIn != null ? dhm(w.resetIn) : '--'}</em><span class="sa-r">${reserve}</span>${sub}</button>${a.extras.map(x => extraRow(x, ui, a.colour)).join('')}`;
  }).join(VG)}</div>`;
}

const cycleKind = (a, ui) => a.windows.some(w => w.kind === ui.cycle) ? ui.cycle : a.windows[0]?.kind;

// Exact v0.5.33 token kinds; unknown stays --, explicit zero stays 0. No cache-write double count.
export function usageBlock(a,ui){
 const days=ui.subDays===30?30:7,w=a.usageStats?.[`recent${days}d`],s=w?.sums,rate=w?.metrics?.generationTps;
 const hit=s?.inputTokens!=null&&s?.cacheReadTokens!=null&&s.inputTokens+s.cacheReadTokens>0?s.cacheReadTokens/(s.inputTokens+s.cacheReadTokens):null;
 const rows=s?[[t('mfd.statInput'),tok(s.inputTokens)],[t('mfd.statOutput'),tok(s.observedOutputTokens)],
  [t('mfd.statCache'),tok(s.cacheReadTokens)],[t('mfd.statWrite'),tok(s.cacheWriteTokens)],
  [t('mfd.statHit'),hit==null?'--':`${Math.round(hit*100)}%`],[t('mfd.statSpeed'),rate?.status==='ok'?`${Math.round(rate.value)} t/s`:'--']]:[];
 return `<div class="sp-stats" data-days="${days}"><span class="stat-h" title="${esc(t('mfd.statsBasis'))}">${t('mfd.statsTitle',{d:days})} · ${t('mfd.statsScope')}</span>${rows.length?rows.map(([k,v])=>`<span class="stat"><span>${esc(k)}</span><b>${esc(v)}</b></span>`).join(''):`<span class="missing">${t('mfd.statsMissing')}</span>`}</div>`;
}

export const plans = {
  id: 'sub', title: 'mfd.pSub',
  optionKeys(ui, d) {
    const a = ui.scope && accountOf(d, ui.scope);
    if (!a) return [null, null, null, null];
    const hist = ui.subTab === 'hist', ws = a.windows, k = cycleKind(a, ui);
    return [{id: 'tab', a: {value:'now', text: t('mfd.oNow'), on: !hist}, b: {value:'hist', text: t('mfd.oHist'), on: hist}},
      hist && ws.length > 1 ? {id: 'cycle', a: {value:ws[0].kind, text: ws[0].label, on: k === ws[0].kind}, b: {value:ws[1].kind, text: ws[1].label, on: k === ws[1].kind}} : !hist ? {id:'usage',a:{value:7,text:'7',on:ui.subDays!==30},b:{value:30,text:'30',on:ui.subDays===30}} : null, null, null];
  },
  render(d, ui) {
    const a = ui.scope && accountOf(d, ui.scope);
    if (!a) return list(d, ui);
    if (ui.subTab === 'hist') {
      const k = cycleKind(a, ui), w = a.windows.find(x => x.kind === k), cy = cycles(d, a, ui, k);
      return `${header(a)}<div class="sec"><span class="lbl">${t('mfd.resets')}</span><em>${esc(w?.label || '')}</em></div>${resets(a, ui, k)}
        ${cy ? `<div class="sec"><span class="lbl">${t('mfd.cycles')}</span><em>${esc(w?.label || '')}</em></div><div class="mfd-fill" data-fill="cyc">${cy}</div>` : ''}`;
    }
    // polish A: the blocks spread over the screen's height (spacers of 4–24 px between them)
    const blocks = [`<div class="sp-ws"${a.extras.length ? ' style="--lbw:54px"' : ''}>${windows(a, ui)}</div>`, cardsBlock(a, ui), creditsBlock(a, ui), peak(a, ui), usageBlock(a,ui)].filter(Boolean);
    return `<div class="sp-now">${header(a)}${VG}${blocks.join(VG)}</div>`;
  },
  onClick(act, val, ui, d) {
    if (act === 'scope') return {scope: val};
    if (act === 'opt' && val === 'usage') return {patch:{mfdSubDays:ui.optionChoice!=null?Number(ui.optionChoice):ui.subDays===30?7:30}};
    if (act === 'opt' && val === 'tab') return {patch: {mfdSubTab: ui.optionChoice ?? (ui.subTab === 'hist' ? 'now' : 'hist')}};
    if (act === 'opt' && val === 'cycle') { const a = accountOf(d, ui.scope), k = cycleKind(a, ui), ws = a.windows; return {patch: {mfdCycle: ui.optionChoice ?? (k === ws[0].kind ? ws[1].kind : ws[0].kind)}}; }
    return null;
  },
};
