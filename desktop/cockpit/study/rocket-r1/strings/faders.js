// Fader strings (P3 owns this file). [class, zh-CN, en]. Effort names (Low … Max) are published data, not strings.
import {register} from '../i18n.js';

register('fad', {
  // silkscreen
  status: ['silk', '状态', 'State'],
  indicatorAria: ['aria', '{m}：{s}；{fast}', '{m}: {s}; {fast}'],
  indicatorTrying: ['aria', '在试', 'trying'],
  indicatorSelected: ['aria', '已选', 'selected'],
  indicatorIdle: ['aria', '未选', 'not selected'],
  // One LCD state; cost/ability/speed text is retained for tooltip/accessibility facts.
  tryEffort: ['lcd', '试 {e}', 'Try {e}'],
  tryCurrent: ['lcd', '试 = 当前', 'Try = Current'],
  tryRec: ['lcd', '试 = ★', 'Try = ★'],
  tryFast: ['lcd', '快速', 'Fast'],
  tryStd: ['lcd', '标准', 'Std'],
  costCurrent: ['lcd', '当前', 'vs current'],
  cost: ['lcd', '成本{x}', 'Cost {x}'],
  abl: ['lcd', '能力{d}', 'Abl. {d}'],
  speed: ['lcd', '速度{x}', 'Speed {x}'],
  bank: ['line', '第{i}组/共{n}组', 'Bank {i}/{n}'],
  // accessible names and tooltips (not drawn)
  running: ['aria', '运行 {t}', 'running {t}'],
  stripAria: ['aria', '{m}：{cur}，推荐 ★{rec}{x}{more}。按下在公共屏比较，长按钉到第 1 组。仅本机比较，不改真实会话', '{m}: {cur}, recommended ★{rec}{x}{more}. Press to compare on the Main screen, long-press to pin to bank 1. Local comparison; your session stays unchanged'],
  stripAriaX: ['aria', '，成本是推荐的 {x}', ', cost {x} of the recommendation'],
  stripAriaMore: ['aria', '，另有 {more}', ', also {more}'],
  stripTrialAria: ['aria', '{m}：在试 {e}，{cost}，{d}（只在本机比较，不改会话）', '{m}: trying {e}, {cost}, {d} (a local comparison, no session changes)'],
  unreportedAria: ['aria', '档位未报告', 'effort not reported'],
  pinnedAria: ['aria', '已钉住', 'Pinned'],
  fastLampAria: ['aria', '快速模式：{s}', 'Fast mode: {s}'],
  lampOff: ['aria', '关', 'off'],
  lampOn: ['aria', '最近会话在用', 'in use by the latest session'],
  lampTry: ['aria', '在试', 'trying'],
  // polish A: the level names moved to the right of the three channels (the first LCD starts at the grid's edge)
  travelAria: ['aria', '{m} 档位试一试：拖动推杆帽、↑↓ 或点右边的档位名（只在本机比较，不改会话）', '{m} effort trial: drag the cap, use ↑↓ or click a level on the right (a local comparison, no session changes)'],
  // round D1: the ⚡ push button is gone (fast mode is tried with the comparison view's ⚡ key, strings/mfd.js)
  bankPrevAria: ['aria', '上一组推杆（键 [）', 'Previous fader bank (key [)'],
  bankNextAria: ['aria', '下一组推杆（键 ]）', 'Next fader bank (key ])'],
});

// Demo panel (study only): the simulation that makes the latest Codex session use fast mode (white ⚡).
register('faddemo', {
  simFast: ['demo', '最近会话用快速', 'Latest uses fast'],
});
