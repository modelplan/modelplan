// SPDX-License-Identifier: MIT
// CKP-MFD-55/56 (WP-11, V1-FINAL §8.6): the alert list the ALERT lamp opens. Title "提醒 · N"; one row per alert with two
// lines: the shared sentence (src/alert-sentence.ts, the same words as the lamp, overview, menu and widget card), then
// what helps (available resets; "去设置 ›" for an unreadable one). The rows arrive ordered red, amber, blue, grey,
// tightest first (src/caution.ts). A row is a button: it selects its subscription, or a grey row opens Settings ›
// Subscriptions; the deck handles the press. Pure view: no state, no listeners.
import {t} from '../i18n.js';
import {esc} from './fmt.js';

export function alertsPage(items, {back, mark = null, flash = false, ack = false}) {
  const rows = items.map((x, i) => `<li class="al-${x.level}${mark !== null && x.stable === mark ? ' al-mark' + (flash ? ' al-flash' : '') : ''}"><button type="button" class="al-row" data-al="${i}" data-al-id="${esc(x.stable)}" data-al-member="${esc(x.member ?? '')}"${x.settings ? ' data-al-settings=""' : ''}><i>●</i><span class="al-l1">${esc(x.text)}</span>${x.detail ? `<span class="al-l2">${esc(x.detail)}</span>` : ''}</button></li>`).join('');
  return `<button type="button" class="mfd-back" data-mfd="back" aria-label="${esc(back.aria)}">${esc(back.label)}</button>`
    + `<p class="al-head">${esc(t('mfd.alertsCount', {n: items.length}))}</p>`
    + `<ul class="mfd-alerts all${ack ? ' ack' : ''}">${rows || `<li class="al-none">${esc(t('mfd.noAlerts'))}</li>`}</ul>`;
}
