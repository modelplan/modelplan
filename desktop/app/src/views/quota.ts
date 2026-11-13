import { inPool, type Account, type Lang, type QuotaWindow, type Snapshot } from '../snapshot.ts';
import { dur, fill, limitName, sourceName, words } from '../i18n.ts';
import { ageMinutes, esc, headroomTone, toneOf } from './html.ts';

// Quota: each account's windows as bars of what is left, with the reset and the run-out at the
// recent rate. Windows outside the pool in use (Codex's main allowance while on Reserve, or the
// other way round) are dimmed. Readers that found nothing say why.
export function renderQuota(s: Snapshot, lang: Lang, now: number): string {
  const t = words(lang);
  const accounts = s.accounts.filter(a => a.windows.length).map(a => account(a, lang, now)).join('');
  const missing = s.sources.filter(x => x.status !== 'ok' && x.source !== 'user')
    .map(x => `<li><b>${esc(sourceName(lang, x.source))}</b> ${esc(t.sourceStatus[x.status] ?? x.status)}${x.reason ? ` <span class="dim">${esc(x.reason)}</span>` : ''}</li>`).join('');
  return (accounts || `<p class="empty">${esc(t.noQuota)}</p>`) + (missing ? `<ul class="sources">${missing}</ul>` : '');
}

function account(a: Account, lang: Lang, now: number): string {
  const t = words(lang);
  const age = ageMinutes(a.observedAt, now);
  // A CodexBar account is named by its provider already.
  const head = [sourceName(lang, a.source), a.source.startsWith('codexbar:') ? '' : a.plan].filter(Boolean).join(' · ');
  const pool = a.pool ? limitName(a.pool) + ' · ' : '';
  return `<article class="account" data-source="${esc(a.source)}">
<header><b>${esc(head)}</b>${a.stale ? `<span class="badge">${esc(t.stale)}</span>` : ''}<time>${age == null ? '' : esc(age < 1 ? t.justNow : fill(t.observed, dur(lang, age)))}</time></header>
<p class="headroom ${headroomTone(a.headroom)}">${esc(pool + (t.headroom[a.headroom] ?? a.headroom))}</p>
${a.windows.map(w => meter(a, w, lang)).join('')}</article>`;
}

function meter(a: Account, w: QuotaWindow, lang: Lang): string {
  const t = words(lang);
  const label = [t.kinds[w.kind] ?? w.kind, limitName(w.limit)].filter(Boolean).join(' ');
  if (w.usedPercent == null || w.pace === 'reset_passed') return `<div class="meter dim"><span class="k">${esc(label)}</span><span class="v">—</span><span class="n">${esc(w.unknownReason === 'reset_passed' || w.pace === 'reset_passed' ? (t.pace.reset_passed ?? w.unknownReason ?? '') : '')}</span></div>`;
  const left = Math.max(0, Math.min(100, 100 - w.usedPercent));
  const tone = toneOf(left, w.pace);
  const notes: string[] = [];
  if (w.resetsInMinutes != null) notes.push(fill(t.resetsIn, dur(lang, w.resetsInMinutes)));
  if (w.pace && w.pace !== 'unknown') notes.push(t.pace[w.pace] ?? w.pace);
  const runsOut = w.runsOutInMinutes != null && (w.resetsInMinutes == null || w.runsOutInMinutes < w.resetsInMinutes)
    ? `<p class="runs-out warn">${esc(fill(t.runsOut, dur(lang, w.runsOutInMinutes)))}</p>` : '';
  return `<div class="meter ${tone}${inPool(a, w) ? '' : ' off-pool'}" data-kind="${esc(w.kind)}">
<span class="k">${esc(label)}</span><span class="bar" role="meter" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(left)}"><i style="width:${left.toFixed(1)}%"></i></span>
<span class="v">${esc(fill(t.left, Math.round(left) + '%'))}</span><span class="n">${esc(notes.join(' · '))}</span>${runsOut}</div>`;
}
