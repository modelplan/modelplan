// Faders (r7 P3, spec 5): the pure model and views. faderModel(d, ui) turns the adapter's data (fader-adapter.js) and
// the UI state into one model per channel; the view functions turn a channel into markup. No state, no fixtures and
// no DOM here: faders.js is the controller and the one DOM writer (spec 2.6). Every visible string goes through t().
// Colours carry one meaning each (spec 2.1): vendor colour = who (strip), white = real (current effort, real
// cap, a real fast session), blue = a trial, gold = ★. Round D1 (owner 2026-10-23): gold ★ is the one recommended
// marker (◉ is gone), and fast mode uses the single status indicator above the LCD. Synthetic study; nothing is applied to a session.
import {shortLabel} from './short-label.js';
import {t} from './i18n.js';
import './strings/faders.js';

export const LADDER = ['Low', 'Med', 'High', 'XHigh', 'Max'];
// Where a level sits on the travel: 0 = Max at the top … 1 = Low at the bottom (faders.css places it).
export const levelK = label => (4 - LADDER.indexOf(label)) / 4;
export const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]));
const dhm = m => m == null ? '--' : m < 60 ? `${Math.round(m)}m` : m < 1440 ? `${Math.floor(m / 60)}h${String(Math.round(m % 60)).padStart(2, '0')}` : `${Math.floor(m / 1440)}d${Math.floor(m % 1440 / 60)}h`;
// Multiples on a 56 px LCD: ×2.8, ×1.5, ×2, ×0.7, ×13 (one decimal below 10, whole numbers bare).
export function times(v) {
  if (v == null || !isFinite(v)) return '×--';
  return '×' + (v >= 9.95 ? v.toFixed(0) : v >= .095 ? v.toFixed(1) : v.toFixed(2)).replace(/\.0+$/, '');
}
// LCD cost ratios: at most two significant digits; missing costs stay missing.
const costFormat = new Intl.NumberFormat('en-US', {maximumSignificantDigits: 2, useGrouping: false});
export const costMultiple = v => typeof v === 'number' && Number.isFinite(v) && v >= 0 ? '×' + costFormat.format(v) : null;
const costRatio = (a, b) => a != null && b != null && b > 0 ? a / b : null;
// Ability against the current effort: +4.7, −2.9, ±0.
export const delta = v => v > .05 ? '+' + v.toFixed(1) : v < -.05 ? '−' + Math.abs(v).toFixed(1) : '±0';
// A session's age for tooltips (the record strip uses it too): "running 12m" or −6m.
export const agoText = x => x.running ? t('fad.running', {t: dhm(x.startedMin)}) : `−${dhm(x.endedMin)}`;

// Glyphs drawn as SVG, so their width is the same on every platform and ⚡ never turns into a colour emoji.
const STAR = '<svg class="g-star" viewBox="0 0 10 10" aria-hidden="true"><path d="M5 .5L6.18 3.68 9.57 3.82 6.9 5.92 7.82 9.18 5 7.3 2.18 9.18 3.1 5.92 .43 3.82 3.82 3.68Z"/></svg>';
const BOLT = '<svg class="g-bolt" viewBox="0 0 6 9" aria-hidden="true"><path d="M3.9 0 .3 5.1h2.4L2 9l3.7-5.4H3.3z"/></svg>';

/* ---------- model ---------- */
// d = faderData(), ui = faderUi() + {bankSize}. Returns {bank, banks, size, channels (this bank, null = empty slot),
// all (every fader), target (the fader the level labels act on: the selected one on this bank, else the first)}.
export function faderModel(d, ui) {
  const size = ui.bankSize, banks = Math.max(1, Math.ceil(d.faders.length / size)), bank = Math.max(0, Math.min(banks - 1, ui.bank | 0));
  const colour = new Map(d.accounts.map(a => [a.id, a.colour]));
  const all = d.faders.map(f => channel(f, ui, colour));
  const shown = all.slice(bank * size, bank * size + size), channels = Array.from({length: size}, (_, i) => shown[i] || null);
  const target = shown.find(c => c.id === ui.selModel) || shown[0] || null;
  return {bank, banks, size, channels, all, target: target?.id ?? null};
}

function channel(f, ui, colour) {
  const row = l => f.e.find(r => r[0] === l) || null, levels = f.e.map(r => r[0]);
  const cur = f.current && row(f.current) ? f.current : null, base = cur || f.rec;
  const tier = f.tier, costOf = (l, fast) => { const n = row(l)?.[2], factor = fast && tier ? tier.cost : 1; return typeof n === 'number' && Number.isFinite(n) && n >= 0 && typeof factor === 'number' && Number.isFinite(factor) ? n * factor : null; }, speedOf = fast => fast && tier ? tier.speed : 1;
  // The trial: the effort being tried (S.previews, the ghost cap) and/or ⚡ being tried (the comparison view's args).
  const v = ui.view && ui.view.modelId === f.id ? ui.view : null, pv = ui.previews[f.id];
  const tEff = pv && row(pv) && pv !== cur ? pv : null;
  const tFast = tier && v && v.fast != null && !!v.fast !== f.currentFast ? !!v.fast : null;
  let trial = null;
  const trialEff = v ? (row(v.trial) ? v.trial : base) : tEff;
  if (v || tEff || tFast != null) {
    const e = trialEff || base, fast = tFast ?? f.currentFast;
    trial = {effort: e, fast: tFast, matchesCurrent: e === cur && fast === f.currentFast, matchesRec: e === f.rec && !fast, cost: costRatio(costOf(e, fast), costOf(base, f.currentFast)), abl: row(e)[1] - row(base)[1], speed: speedOf(fast) / speedOf(f.currentFast)};
  }
  // Effort bars: the published ability, normalised within the model (lowest → 3 px, highest → 11 px).
  const ab = f.e.map(r => r[1]).filter(x => x != null), a0 = Math.min(...ab), a1 = Math.max(...ab);
  const bars = LADDER.map(l => {
    const r = row(l);
    if (!r || r[1] == null) return {l, none: true};
    return {l, h: a1 > a0 ? (r[1] - a0) / (a1 - a0) : 1, cur: l === cur, rec: l === f.rec, trial: l === trialEff};
  });
  const others = Object.entries(f.others).filter(([e]) => row(e)).sort((a, b) => b[1] - a[1] || LADDER.indexOf(b[0]) - LADDER.indexOf(a[0]));
  const from = v ? v.from : null; // the source of this model's comparison view, lit (spec 2.5)
  return {id: f.id, name: f.name || f.short, label: shortLabel(f.name || f.short), levels, current: f.current, cur, rec: f.rec, base, live: f.live, pinned: f.pinned, used: f.sessions.length > 0,
    currentFast: f.currentFast, tier, follows: !!cur && cur === f.rec && !f.currentFast,
    recX: cur ? costRatio(costOf(cur, f.currentFast), costOf(f.rec, false)) : null, // the current cost against ★ (fast included)
    others, segments: f.accounts.map(id => colour.get(id)).filter(Boolean), bars,
    lamp: !tier ? null : tFast != null ? 'try' : f.currentFast ? 'on' : 'off',
    trial, tEff, tFast, src: from,
    capK: levelK(base), parked: !cur, recK: levelK(f.rec), ticks: levels.map(levelK), dots: others.map(([e, n]) => ({k: levelK(e), n})),
    ghostK: tEff ? levelK(tEff) : null,
    leds: f.sessions.slice(0, 6).map(x => ({...x, colour: colour.get(x.sub) || null})),
    fast: tier ? {state: from === 'fast' ? 'try' : f.currentFast ? 'on' : 'off', std: f.currentFast} : null,
    sel: ui.selModel === f.id};
}

/* ---------- views ---------- */
// Task 44: keep the task-32 hierarchy; add only a known cost multiple below the state.
export function lcdView(c) {
  if (!c) return '';
  const strip = `<i class="st-vend" aria-hidden="true">${c.segments.map(v => `<b style="--v:${esc(v)}"></b>`).join('')}</i>`;
  const name = `<b class="st-name ${c.label.length > 8 ? 'long' : ''}">${esc(c.label)}</b>${c.pinned ? `<i class="st-pin" role="img" aria-label="${esc(t('fad.pinnedAria'))}"></i>` : ''}`;
  const bars = `<span class="st-bars">${c.bars.map(b => b.none ? `<i class="eb none" data-l="${b.l}"></i>`
    : `<i class="eb${b.cur ? ' cur' : ''}${b.rec ? ' rec' : ''}${b.trial ? ' try' : ''}${Number((3 + b.h * 8).toFixed(1)) * 1.4 < 6 ? ' short' : ''}" data-l="${b.l}" style="--h:${(3 + b.h * 8).toFixed(1)}px"></i>`).join('')}</span>`;
  let state;
  if (c.trial) {
    const tr = c.trial;
    const text = tr.matchesCurrent ? t('fad.tryCurrent') : tr.matchesRec ? t('fad.tryRec') : t('fad.tryEffort', {e: tr.effort});
    const multiple = !tr.matchesCurrent && !tr.matchesRec && c.cur ? costMultiple(tr.cost) : null;
    state = `<span class="st-eff st-try"><em class="st-trial-value">${esc(text)}</em>${multiple ? `<small class="st-multiple st-trial-cost"><span>${multiple}</span><span class="st-cost-basis">${t('fad.costCurrent')}</span></small>` : ''}</span>`;
  } else {
    const multiple = !c.follows ? costMultiple(c.recX) : null;
    const wrap = multiple && c.rec.length > 3;
    state = `<span class="st-eff${wrap ? ' st-cost-wrap' : ''}"><em class="${c.follows ? 'rec' : ''}">${c.follows ? STAR : ''}${esc(c.cur || '--')}</em>${c.follows ? '' : `<span class="st-rec">${STAR}<span class="st-rec-label">${esc(c.rec)}</span>${multiple ? `<small class="st-multiple st-rec-cost">·${multiple}</small>` : ''}</span>`}</span>`;
  }
  return strip + name + bars + state;
}

export function stripAria(c) {
  const current = t('fad.stripAria', {m: c.name, cur: c.cur || t('fad.unreportedAria'), rec: c.rec, x: c.recX != null ? t('fad.stripAriaX', {x: times(c.recX)}) : '',
    more: c.others.length ? t('fad.stripAriaMore', {more: c.others.map(([e, n]) => `${e}×${n}`).join(' ')}) : ''});
  if (!c.trial) return current;
  const tr = c.trial, fastOnly = tr.fast != null && tr.effort === c.base;
  return current + ' · ' + t('fad.stripTrialAria', {m: c.name, e: fastOnly ? t(tr.fast ? 'fad.tryFast' : 'fad.tryStd') : tr.effort + (tr.fast ? ' ⚡' : ''),
    cost: t('fad.cost', {x: times(tr.cost)}), d: fastOnly ? t('fad.speed', {x: times(tr.speed)}) : t('fad.abl', {d: delta(tr.abl)})});
}
// One indicator, centred on its fader: trial blue; selected/real-fast white; inactive dim.
// A bolt replaces the dot in the same slot when the displayed configuration uses fast mode.
export function indicatorView(c) {
  if (!c) return '';
  const trying = !!c.trial, fast = !!c.tier && !!(c.tFast ?? c.currentFast);
  const tone = trying ? 'try' : c.sel || fast ? 'on' : 'off';
  const label = t('fad.indicatorAria', {m: c.name, s: t(trying ? 'fad.indicatorTrying' : c.sel ? 'fad.indicatorSelected' : 'fad.indicatorIdle'),
    fast: c.tier ? t('fad.fastLampAria', {s: trying ? t(fast ? 'fad.tryFast' : 'fad.tryStd') : t(fast ? 'fad.lampOn' : 'fad.lampOff')}) : ''});
  const sessions = c.leds.map(x => `${x.account ? x.account + ' · ' : ''}${x.tool} · ${x.project} · ${agoText(x)}`).join('\n');
  return `<span class="fd-indicator ${tone}${fast ? ' fast' : ''}" data-state="${tone}" data-fast="${fast}"${c.lamp ? ` data-fast-mode="${c.lamp}"` : ''} role="img" aria-label="${esc(label + (sessions ? '\n' + sessions : ''))}">${fast ? BOLT : ''}</span>`;
}
// The travel's fixed marks: a tick per level the model has, the ★ detent (round D1: this fader's own ★ level, a short
// gold notch beside the cap's lane and a tiny gold ★, because the shared scale cannot show each model's ★), and white
// dots for other sessions.
export const marksView = c => !c ? '' : `${c.ticks.map(k => `<i class="fd-tick" style="--k:${k}"></i>`).join('')}<i class="fd-rec" data-l="${esc(c.rec)}" style="--k:${c.recK}">${STAR}</i>${c.dots.map(d => `<i class="fd-dot" style="--k:${d.k}"><b>${d.n}</b></i>`).join('')}`;
// Round D1: the ⚡ lit push button above the travel is gone (the owner could not tell what it was); fast mode is tried
// with the comparison view's own ⚡ key; its state shares the indicator above the LCD.
// The scale beside the travels: 状态 over the indicators, and the level labels (Max … Low), which set the trial.
export const scaleView = () => `<span class="silk sc-led">${t('fad.status')}</span><span class="sc-lcd"></span><span class="sc-travel">${LADDER.map(l => `<button class="silk sc-l" data-level="${l}" tabindex="-1" style="--k:${levelK(l)}">${l}</button>`).join('')}</span>`;
export const bankView = M => M.banks > 1 ? `<button class="key sm" data-bank="-1" data-mat="part" aria-label="${esc(t('fad.bankPrevAria'))}">◀</button><span class="bank-lcd" data-mat="well">${esc(t('fad.bank', {i: M.bank + 1, n: M.banks}))}</span><button class="key sm" data-bank="1" data-mat="part" aria-label="${esc(t('fad.bankNextAria'))}">▶</button>` : '';
