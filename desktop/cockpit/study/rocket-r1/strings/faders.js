// Fader strings (P3 owns this file). [class, zh-CN, en]. Effort names (Low … Max) are published data, not strings.
import {register} from '../i18n.js';

register('fad', {
  // silkscreen
  // CKP-FAD-55: the row label over the session lamps.
  status: ['silk', '会话', 'Sessions'],
  indicatorAria: ['aria', '{m}：{s}；{fast}', '{m}: {s}; {fast}'],
  sessionLive: ['aria', '有会话在跑', 'a session is running'],
  sessionUsed: ['aria', '这段时间用过', 'used in this range'],
  sessionNone: ['aria', '没有会话', 'no sessions'],
  // Model card lines (V1-FINAL §7, CKP-FAD-50…52): each line is at most 9 characters in both languages.
  cardUnused: ['lcd', '未使用', 'Unused'],
  cardUnlisted: ['lcd', '未收录', 'Unlisted'],
  cardNoRecord: ['lcd', '无用量记录', 'No record'],
  cardUnreported: ['lcd', '档位未报告', 'Effort ?'],
  cardTry: ['lcd', '试 {e}', 'Try {e}'],
  cardNow: ['lcd', '当前 {e}', 'Now {e}'],
  cardNowUnknown: ['lcd', '当前未报告', 'Now ?'],
  cardTryShare: ['lcd', '能{a} 费{c}', 'A{a} C{c}'],
  cardTrying: ['lcd', '试算中', 'Trying'],
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
  stripAria: ['aria', '{m}：{cur}，推荐 ★{rec}{x}{more}{use}。点一下打开档位页，长按收藏到第 1 组。只是试算，不改工具设置', '{m}: {cur}, recommended ★{rec}{x}{more}{use}. Click to open the effort page, long-press to pin to bank 1. A trial only; your tool settings stay unchanged'],
  stripAriaUse: ['aria', '；这段时间 {u}', '; in this range {u}'],
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
