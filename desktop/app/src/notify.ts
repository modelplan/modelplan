import type { AdviceEvent, Lang } from './snapshot.ts';
import { sourceName } from './i18n.ts';

// Which advice a desktop notification is sent for. Each event is notified once per key, with its
// own record kept apart from the prompt hooks' (they tell the agent's user in the chat; this tells
// the user at system level).
export const categories = {
  tight: ['window_exhausted', 'window_tight'],
  switchBack: ['reset_passed_switch_back'],
  better: ['better_model_available'],
  surplus: ['reset_soon_with_surplus', 'announced_reset_with_surplus'],
  other: ['peak_starts_soon', 'offpeak_starts_soon', 'cards_expiring', 'public_reset_announced'],
} as const;

export type Category = keyof typeof categories;
export type Prefs = Record<Category, boolean>;

// Owner-confirmed defaults (2026-10-18): on for tight/exhausted, switch back and a better model;
// off for surplus before a reset. The rest is off until the user turns it on.
export const defaults: Prefs = { tight: true, switchBack: true, better: true, surplus: false, other: false };

// A better model is not repeated for 90 days, as in the CLI; everything else is keyed per cycle
// or configuration by the CLI, so 90 days covers it too.
export const keepFor = 90 * 24 * 3600 * 1000;

// Notified: key → when it was notified (ISO).
export type Notified = Record<string, string>;

export function categoryOf(type: string): Category | undefined {
  for (const [c, types] of Object.entries(categories) as [Category, readonly string[]][]) if (types.includes(type)) return c;
  return undefined;
}

export interface Notice { key: string; title: string; body: string }

// due picks the events to notify now, most urgent first (the CLI's order), at most max at a time,
// and returns the record with them added and old keys dropped. Stale readings are not notified.
export function due(events: AdviceEvent[], prefs: Partial<Prefs>, notified: Notified, now: number, lang: Lang, max = 2): { send: Notice[]; notified: Notified } {
  const p = { ...defaults, ...prefs };
  const kept: Notified = {};
  for (const [k, at] of Object.entries(notified)) if (now - Date.parse(at) <= keepFor) kept[k] = at;
  const send: Notice[] = [];
  for (const e of events) {
    const c = categoryOf(e.type);
    if (!c || !p[c] || e.stale || !e.key || kept[e.key] || send.length >= max) continue;
    const body = e.text?.[lang] ?? e.text?.en ?? '';
    if (!body) continue;
    kept[e.key] = new Date(now).toISOString();
    send.push({ key: e.key, title: title(e, lang), body });
  }
  return { send, notified: kept };
}

const heads: Record<Lang, Record<string, string>> = {
  zh: {
    window_exhausted: '额度用完', window_tight: '额度偏紧', reset_passed_switch_back: '已重置，可以换回', better_model_available: '有更合适的模型',
    reset_soon_with_surplus: '重置前用不完', announced_reset_with_surplus: '公告重置前用不完', peak_starts_soon: '高峰时段快到了',
    offpeak_starts_soon: '低峰时段快到了', cards_expiring: '重置卡快过期', public_reset_announced: '公开重置公告',
  },
  en: {
    window_exhausted: 'Quota used up', window_tight: 'Quota is tight', reset_passed_switch_back: 'Reset: switch back', better_model_available: 'A better model',
    reset_soon_with_surplus: 'Unused before the reset', announced_reset_with_surplus: 'Unused before an announced reset', peak_starts_soon: 'Peak hours soon',
    offpeak_starts_soon: 'Off-peak soon', cards_expiring: 'Reset cards expiring', public_reset_announced: 'Public reset announced',
  },
};

// title: "Claude Code · 额度偏紧 ↓★Med ×0.73".
function title(e: AdviceEvent, lang: Lang): string {
  const who = e.source === 'public' || e.source === 'user' ? 'Model Plan' : sourceName(lang, e.source);
  return [who + ' · ' + (heads[lang][e.type] ?? e.type), e.short?.[lang]].filter(Boolean).join(' ');
}
