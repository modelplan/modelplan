// SPDX-License-Identifier: MIT
// WP-13 shared helper: the one time range the Models and Where pages follow (V1-FINAL 8.3, 8.4) and the title line
// "7天 · ...". The range is the app's (WP-09 / #1047, scope.js rangeOf: 'today' | '7d' | '30d'); this file only words it.
import {t} from '../i18n.js';
import '../strings/mfd.js';
import {rangeOf} from './scope.js';

export const pageRange = rangeOf;
const words = {today: 'mfd.pgToday', '7d': 'mfd.pg7d', '30d': 'mfd.pg30d'};
export const rangeWord = ui => t(words[rangeOf(ui)]);
/** Share of a whole as an integer percent; null when either is unknown. */
export const pct = (part, whole) => Number.isFinite(part) && Number.isFinite(whole) && whole > 0 ? Math.round(part / whole * 100) : null;
