// SPDX-License-Identifier: MIT
// ALR-50 (WP-11, V1-FINAL §0, §8.1, §11): the one sentence an alert has. The ALERT tooltip, the column wash, the
// overview line, the alert list, the menu line and the widget-card footer all show this sentence and no other wording:
// "Claude 每周 42% · 约1d20h用完", plus "· 2d10h 后重置" when the reset is known and fits (`text`; `short` without it).
// The words are in strings/common.js (alert.*). The native table (ModelPlanSettings AlertSentence.swift) builds the same
// words; tests/shared/alert-sentences.json holds both to the same cases. Pure: no clock, no current-language state.
import {tables} from './i18n.js';
import './strings/common.js';

const pluralRules = {en: new Intl.PluralRules('en'), 'zh-CN': new Intl.PluralRules('zh-CN')};
const fill = (key, lang, vars = {}) => {
  const raw = tables[lang]['alert.' + key];
  if (raw == null) throw new Error(`alert sentence: missing alert.${key}`);
  const s = typeof raw === 'string' ? raw : raw[pluralRules[lang].select(Number(vars.n))] ?? raw.other;
  return s.replace(/\{(\w+)\}/g, (m, n) => vars[n] ?? m);
};
const both = (key, vars = () => ({})) => ({en: fill(key, 'en', vars('en')), zh: fill(key, 'zh-CN', vars('zh-CN'))});
const name = (x, lang) => lang === 'en' ? x.en : x.zh;
const join = (...parts) => { const p = parts.filter(x => x !== null); return {en: p.map(x => x.en).join(' · '), zh: p.map(x => x.zh).join(' · ')}; };

/** V1-FINAL §0 times: "40m", "3h18", "1d20h". Whole minutes first, so 119.7 minutes is "2h00", never "1h60"; at least 1m. */
export function alertDuration(minutes) {
  const m = Math.max(1, Math.round(minutes));
  if (m < 60) return `${m}m`;
  if (m < 1440) return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}`;
  return `${Math.floor(m / 1440)}d${Math.floor(m % 1440 / 60)}h`;
}

// The short cause after "no reading", by reader failure code. Any other code has none; codes that mean "still reading"
// or "nothing to read" never make an unreadable alert at all (`isUnreadable`).
const CAUSES = {
  not_signed_in: 'causeSignIn', login_expired: 'causeSignIn', http_401: 'causeSignIn', unsupported_login: 'causeSignIn',
  key_missing: 'causeKey',
  keychain_unset: 'causeKeychain', keychain_denied: 'causeKeychain', keychain_canceled: 'causeKeychain', keychain_not_found: 'causeKeychain', keychain_unavailable: 'causeKeychain', keychain_confirmation_needed: 'causeKeychain',
  consent_required: 'causePermission', consent_denied: 'causePermission', consent_outdated: 'causePermission', consent_changed: 'causePermission', no_consent: 'causePermission', browser_session_consent_required: 'causePermission', privacy_blocked: 'causePermission',
  tool_not_found: 'causeInstall', runtime_missing: 'causeInstall', file_missing: 'causeInstall',
  update_required: 'causeUpdate', schema_changed: 'causeUpdate',
  network: 'causeNetwork', timeout: 'causeNetwork', http_5xx: 'causeNetwork', http_429: 'causeNetwork', http_403: 'causeNetwork',
};
const NOT_UNREADABLE = new Set(['ok', 'estimated', 'not_read_yet', 'reader_busy', 'usage_not_reported', 'no_usage_windows', 'stale_reading', 'catalogue_off', 'readers_off', 'no_dock_rows', 'not_admitted', 'cleanup_pending']);
export function unreadableCause(code) { return Object.hasOwn(CAUSES, code) ? both(CAUSES[code]) : null; }
/** A failure that means the subscription cannot be read (grey), not one still being read or with nothing to read. */
export const isUnreadable = code => !!code && !NOT_UNREADABLE.has(code);

export function alertSentence(input) {
  if (input.kind === 'unreadableMany') { const s = both('unreadMany', () => ({n: String(input.count)})); return {text: s, short: s}; }
  if (input.kind === 'unreadable') {
    const head = both('unread', lang => ({s: name(input.subscription, lang)})), cause = input.cause === null ? null : unreadableCause(input.cause);
    return {text: join(head, cause), short: head};
  }
  const usedUp = input.remaining <= 0, who = lang => ({s: name(input.subscription, lang), w: name(input.window, lang), r: String(Math.round(input.remaining))});
  const head = both(usedUp ? 'usedUp' : 'quota', who);
  const out = !usedUp && input.runOutMinutes !== null && Number.isFinite(input.runOutMinutes) ? both('out', () => ({t: alertDuration(input.runOutMinutes)})) : null;
  const reset = input.resetMinutes !== null && Number.isFinite(input.resetMinutes) && input.resetMinutes > 0 ? both('resets', () => ({t: alertDuration(input.resetMinutes)})) : null;
  return {text: join(head, out, reset), short: join(head, out)};
}
/** The alert list's second line. */
export const openSettingsAction = () => both('openSettings');
/** `null`: the producer listed only some of the cards, so no number is claimed. */
export const resetsAvailable = n => n === null ? both('resetsAvailableSome') : both('resetsAvailable', () => ({n: String(n)}));
