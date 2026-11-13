import {websiteWords,modelUrl,methodologyUrl} from './public-helpers.js';
import {secondaryLink} from './public-helpers.js';
// 档位: the shared scope selection, including eligible older versions actually used in the last week.
// The HUD opens this page as a view
// (return rule). Pure view (spec 2.6).
import {t} from '../i18n.js';
import {fill} from './fmt.js';
import {chartModels, currentOf} from './scope.js';
import {frontierSvg} from './frontier.js';
import {withOlderLabel} from './public-helpers.js';

export const tune = {
  id: 'tune', title: 'mfd.pTune',
  // The four registered key slots stay in place; selection has no manual legacy toggle.
  optionKeys: () => [null, null, null, null],
  render(d, ui) {
    const ms = chartModels(d, ui).map(m=>withOlderLabel(m,t('mfd.olderBadge')));
    if (!ms.length) return `<p class="mp-empty">${t('mfd.noModels')}</p>`;
    const {w, h} = fill(ui, 'fc', {w: 260, h: 180}), current = {};
    for (const m of ms) { const c = currentOf(d, ui, m.id); if (c?.effort) current[m.id] = c.effort; }
    return `<div class="mfd-fill" data-fill="fc" data-models="${ms.map(m => m.id).join(' ')}">${frontierSvg(ms, {w, h, current, trial: ui.trials, selected: ui.selModel,
      axis: {ability: t('mfd.ability'), cost: t('mfd.cost')}, aria: t('mfd.frontierAria')})}<span class="tune-links">${secondaryLink(modelUrl(ms.find(m=>m.id===ui.selModel)?.id||ms[0].id),websiteWords(ui.lang).compare)} ${secondaryLink(methodologyUrl('effort-ladder'),websiteWords(ui.lang).how)}</span></div>`;
  },
  onClick(act, val, ui) {
    // Selection policy is shared and automatic; no include-legacy override.
    return null;
  },
};
