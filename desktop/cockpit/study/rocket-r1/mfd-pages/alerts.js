// SPDX-License-Identifier: MIT
// CKP-MFD-55/56 (WP-11, V1-FINAL §8.6): the alert list the ALERT lamp opens. Title "提醒 · N"; one row per alert with two
// lines: the shared sentence (src/alert-sentence.ts, the same words as the lamp, overview, menu and widget card), then
// what helps (available resets; "去设置 ›" for an unreadable one). The rows arrive ordered red, amber, blue, grey,
// tightest first (src/caution.ts). A row is a button: it selects its subscription, or a grey row opens Settings ›
// Subscriptions; the deck handles the press. Pure view: no state, no listeners.
import {t} from '../i18n.js';
import {esc} from './fmt.js';

// D474 §3.3 (CKP-MFD-55): the header "提醒 · N" counts only 提醒, amber and red (a reserve item expiring within 48 h is
// amber and counted). Below them, uncounted: 新消息 with the one blue dot (hollow = announced, solid = confirmed), 时段
// (a published peak) with a small square, 读取 (grey). No other bullets: an amber or red row's colour and words say it.
export const counted = x => x.level === 'red' || x.level === 'amber';
export const bullet = x => x.dot ? `<i class="al-dot ${x.dot === 'hollow' ? 'hollow' : 'solid'}" aria-hidden="true"></i>`
  : x.topic === 'peak' ? '<i class="al-sq" aria-hidden="true"></i>' : '<i aria-hidden="true"></i>';
// §6.2: when line 1 does not fit, the subscription name fades first; the time is never cut. The name is its own span.
const line1 = x => x.who && x.text.startsWith(x.who) && x.text.length > x.who.length
  ? `<span class="al-l1 al-split"><span class="al-who">${esc(x.who)}</span><span class="al-rest">${esc(x.text.slice(x.who.length))}</span></span>`
  : `<span class="al-l1">${esc(x.text)}</span>`;

export function alertsPage(items, {back, mark = null, flash = false, ack = false}) {
  const rows = items.map((x, i) => `<li class="al-${x.level}${x.topic ? ' al-t-' + x.topic : ''}${mark !== null && x.stable === mark ? ' al-mark' + (flash ? ' al-flash' : '') : ''}"${x.news ? ` data-news="${esc(x.news)}"` : ''}><button type="button" class="al-row" data-al="${i}" data-al-id="${esc(x.stable)}" data-al-member="${esc(x.member ?? '')}"${x.tip ? ` title="${esc(x.tip)}"` : ''}${x.settings ? ' data-al-settings=""' : ''}>${bullet(x)}${line1(x)}${x.detail ? `<span class="al-l2">${esc(x.detail)}</span>` : ''}</button></li>`).join('');
  return `<button type="button" class="mfd-back" data-mfd="back" aria-label="${esc(back.aria)}">${esc(back.label)}</button>`
    + `<p class="al-head">${esc(t('mfd.alertsCount', {n: items.filter(counted).length}))}</p>`
    + `<ul class="mfd-alerts all${ack ? ' ack' : ''}">${rows || `<li class="al-none">${esc(t('mfd.noAlerts'))}</li>`}</ul>`;
}
