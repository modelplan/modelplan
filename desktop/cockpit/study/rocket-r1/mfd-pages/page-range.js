// SPDX-License-Identifier: MIT
// WP-13 shared helper (new file so it never conflicts with scope.js, which WP-09 / #1047 edits): the one time range the
// Models and Where pages follow (V1-FINAL 8.3, 8.4: "follows the header range, no range key of its own") and the
// title line "7天 · ...". The app's range (WP-09) arrives as ui.range ('today' | '7d' | '30d'); until it does, 7d.
// After #1047 merges this reads rangeOf() from scope.js instead.
import {t} from '../i18n.js';
import '../strings/mfd.js';

export const PAGE_RANGES = ['today', '7d', '30d'];
export const pageRange = ui => PAGE_RANGES.includes(ui.range) ? ui.range : '7d';
const words = {today: 'mfd.pgToday', '7d': 'mfd.pg7d', '30d': 'mfd.pg30d'};
export const rangeWord = ui => t(words[pageRange(ui)]);
/** Share of a whole as an integer percent; null when either is unknown. */
export const pct = (part, whole) => Number.isFinite(part) && Number.isFinite(whole) && whole > 0 ? Math.round(part / whole * 100) : null;
