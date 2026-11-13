import type { Lang, Session, Snapshot } from '../snapshot.ts';
import { dur, fill, limitName, sourceName, words } from '../i18n.ts';
import { ageMinutes, esc, gain, headroomTone, times } from './html.ts';

// Now: each harness's configuration against its ★ effort, then the advice, most urgent first.
export function renderNow(s: Snapshot, lang: Lang, now: number): string {
  const t = words(lang);
  const sessions = s.sessions.length ? s.sessions.map(x => session(x, lang, now)).join('') : `<p class="empty">${esc(t.noSessions)}</p>`;
  const advice = s.events.length
    ? `<ul class="events">${s.events.map(e => `<li class="ev ${e.severity === 'warn' ? 'warn' : 'info'}${e.stale ? ' stale' : ''}">${e.short?.[lang] ? `<b class="short">${esc(e.short[lang])}</b>` : ''}<span>${esc(e.text?.[lang] ?? e.text?.en ?? e.type)}</span></li>`).join('')}</ul>`
    : `<p class="empty">${esc(t.noAdvice)}</p>`;
  return `<section class="sessions">${sessions}</section><h2 class="mp-lcd-h">${esc(t.advice)}</h2>${advice}`;
}

function session(x: Session, lang: Lang, now: number): string {
  const t = words(lang);
  const age = ageMinutes(x.observedAt, now);
  const when = age == null ? '' : age < 1 ? t.justNow : fill(t.observed, dur(lang, age));
  const name = x.model.name ?? x.model.harnessId;
  const effort = x.effort ? `<span class="effort${x.effort.star ? ' star' : ''}">${x.effort.star ? '★' : ''}${esc(x.effort.label)}</span>` : '';
  const fast = x.speed ? `<span class="fast">⚡${esc(x.speed === 'fast' ? t.fast : x.speed)}</span>` : '';
  let vs = '';
  if (!x.model.id) vs = `<p class="vs dim">${esc(t.notListed)}</p>`;
  else if (x.vsRecommended && x.recommended) vs = `<p class="vs">${esc(fill(t.vsStar, x.recommended.label, gain(x.vsRecommended.abilityDelta), times(x.vsRecommended.costRatio)))}</p>`;
  else if (x.effort?.star) vs = `<p class="vs star">${esc(t.atStar)}</p>`;
  const pool = x.pool ? limitName(x.pool) + ' · ' : '';
  return `<article class="session" data-source="${esc(x.source)}">
<header><b>${esc(sourceName(lang, x.source))}</b>${x.stale ? `<span class="badge">${esc(t.stale)}</span>` : ''}<time>${esc(when)}</time></header>
<p class="model">${esc(name)} ${effort} ${fast}</p>${vs}
<p class="headroom ${headroomTone(x.headroom)}">${esc(pool + (t.headroom[x.headroom] ?? x.headroom))}</p>
${x.attribution === 'recent-thread' ? `<p class="dim small">${esc(t.recentThread)}</p>` : ''}</article>`;
}
