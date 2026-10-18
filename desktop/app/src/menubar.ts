import { accountOf, inPool, type Account, type Lang, type Session, type Snapshot } from './snapshot.ts';
import { dur, limitName, sourceName, words } from './i18n.ts';

export interface MenuBar {
  title: string; // next to the icon, like the narrow status line: "12% · wk70% ↓★Med ×0.73"
  tooltip: string; // every session, one line each
}

// focus: the session the menu bar speaks for. "auto" is the one observed most recently, fresh
// readings first.
export function focus(s: Snapshot, prefer = 'auto'): Session | undefined {
  if (prefer !== 'auto') {
    const x = s.sessions.find(x => x.source === prefer);
    if (x) return x;
  }
  const at = (x: Session) => Date.parse(x.observedAt ?? '') || 0;
  return [...s.sessions].sort((a, b) => Number(a.stale) - Number(b.stale) || at(b) - at(a))[0];
}

export function menuBar(s: Snapshot, lang: Lang, prefer = 'auto'): MenuBar {
  const x = focus(s, prefer);
  const tooltip = s.sessions.map(y => line(s, y, lang)).join('\n') || 'Model Plan';
  if (!x) return { title: '', tooltip };
  const a = accountOf(s, x);
  const parts = a ? meters(a, lang) : [];
  const hint = s.events.find(e => e.source === x.source && e.inMenuBar && !e.stale && e.short?.[lang])?.short?.[lang]
    ?? ({ spend: '↑', conserve: '↓', exhausted: '✕' } as Record<string, string>)[x.headroom] ?? '';
  const title = [parts.join(' · '), hint].filter(Boolean).join(' ');
  return { title, tooltip };
}

// meters: what is left in each window of the account's pool, the five-hour one bare and the week
// marked, as on the narrow status line.
function meters(a: Account, lang: Lang): string[] {
  const t = words(lang), out: string[] = [];
  for (const w of a.windows) {
    if (!inPool(a, w) || w.usedPercent == null || w.pace === 'reset_passed' || w.kind === 'unknown') continue;
    const left = Math.round(Math.max(0, 100 - w.usedPercent)) + '%';
    out.push(w.kind === 'five_hour' ? left : (w.kind === 'weekly' ? t.weekNarrow : t.kinds[w.kind] ?? w.kind) + left);
  }
  if (a.pool && out.length) out[0] = limitName(a.pool) + ' ' + out[0];
  return out;
}

// line: one session for the tooltip: "Claude Code · Opus 5.5 High · 12% left, resets in 1h35m".
function line(s: Snapshot, x: Session, lang: Lang): string {
  const t = words(lang);
  const model = [x.model.name ?? x.model.harnessId, x.effort?.label, x.speed ? t.fast : ''].filter(Boolean).join(' ');
  const a = accountOf(s, x);
  const w = a?.windows.find(w => inPool(a, w) && w.kind === (x.deciding || 'five_hour') && w.usedPercent != null);
  let q = '';
  if (w) {
    q = t.left.replace('%s', Math.round(100 - (w.usedPercent ?? 0)) + '%');
    if (w.resetsInMinutes != null) q += (lang === 'zh' ? '，' : ', ') + t.resetsIn.replace('%s', dur(lang, w.resetsInMinutes));
  }
  return [sourceName(lang, x.source), model, q].filter(Boolean).join(' · ');
}
