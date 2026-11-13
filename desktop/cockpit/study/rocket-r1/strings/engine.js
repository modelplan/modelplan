// Engine table strings (P2 owns this file). [class, zh-CN, en]
// Times inside the values use the fixed d/h/m forms (45m, 2h14, 3d5h) in both languages (spec 2.2).
import {register} from '../i18n.js';

register('eng', {
  addSubscription: ['aria', '＋ 添加订阅', '＋ Add a subscription'],
  usage7: ['lcd', '7日用量', '7d usage'],
  now: ['lcd', '现在', 'Now'],
  resetPoint: ['lcd', '重置', 'Reset'],
  timelineAria: ['aria', '现在到重置 {reset}', 'Now to reset {reset}'],
  // Owner C01: fixed 5小时 / 每周 / 其他 labels; nonmatching windows carry their own period tag in Other.
  today: ['silk', '今日', 'Today'],
  speed: ['silk', '速度', 'Speed'],
  reserve: ['silk', '储备', 'Reserve'],
  // Owner D76: what the Reserve row holds, as a hover hint on its label (not drawn otherwise).
  reserveHint: ['aria', '储备：还能用的额外重置次数和剩余点数', 'Reserve: extra resets you can still use and remaining credits'],
  row5h: ['lcd', '5小时', '5h'],
  rowDay: ['lcd', '每日', 'Daily'],
  rowWeek: ['lcd', '每周', 'Weekly'],
  rowMonth: ['lcd', '每月', 'Monthly'],
  todayBasis: ['aria', '今日输出；今日平均生成速度为可测速输出 token 总量除以生成秒数总量，不是实时速度；按当前来源关联，非历史账户归属', 'Today’s output; today’s average generation speed is summed eligible output tokens divided by summed generation seconds, not live speed; current source binding, not historical account attribution'],
  averageAria: ['aria', '今日平均生成速度 {n} token 每秒', {"one": "Today’s average generation speed {n} token per second", "other": "Today’s average generation speed {n} tokens per second"}],
  resetAnn: ['line', '预告 {at} 重置', 'Reset {at} announced'],
  resetAnnShort: ['lcd', '预告 {at}', 'Due {at}'],
  resetAnnCompact: ['lcd', '预告{at}', 'Due{at}'],
  resetDone: ['line', '已重置 · 等读数', 'Reset · awaiting reading'],
  resetDoneShort: ['lcd', '已重置', 'Reset'],
  resetTba: ['lcd', '预告待定', 'Reset TBA'],
  resetUnknownShort: ['lcd', '未知', '?'],
  resetWordOne: ['lcd', '重置 1 次', '1 reset'],
  resetCompactOne: ['lcd', '重置1次', '1 reset'],
  resetsWords: ['lcd', '重置 {n} 次', {"one": "{n} reset", "other": "{n} resets"}],
  resetsCompact: ['lcd', '重置{n}次', {"one": "{n} reset", "other": "{n} resets"}],
  creditWords: ['lcd', '{n} 点', {"one": "{n} credit", "other": "{n} credits"}],
  other: ['silk', '其他', 'Other'], // all nonmatching general windows and scoped quotas
  // round D2: each quota cell's period tag (the extras use extra.name: Fable·周)
  t5h: ['lcd', '5小时', '5h'],
  tDay: ['lcd', '日', 'day'],
  tWeek: ['lcd', '周', 'wk'],
  tMonth: ['lcd', '月', 'mo'],
  head: ['silk', '剩余%', '% left'],
  headUsed: ['silk', '已用%', '% used'],
  // keys and lamps
  all: ['silk', '全部', 'All'],
  caution: ['silk', '注意', 'Alert'],
  // the text under (or beside) each quota bar
  resetIn: ['lcd', '{t} 后重置', 'resets {t}'],
  resetUnknown: ['lcd', '重置未知', 'reset ?'],
  runOut: ['lcd', '约 {t} 用完', 'out ~{t}'], // the pace says the window runs out before it resets (amber)
  runOutShort: ['lcd', '约{t}', '~{t}'], // the same in a narrow column (5–7 subscriptions)
  runOutC: ['lcd', '约{t}用完', 'out ~{t}'], // round D2: the compact forecast in medium and wide cells
  resetLine: ['line', '{t} · {at}', '{t} · {at}'], // round D2: the wide cell's one line, 3h18 · 17:23
  // round D2 cell states
  drawCell: ['lcd', '扣点中', 'credits'], // used up, credits being drawn (red)
  drawLine: ['line', '扣点中 · {t}', 'credits · {t}'], // the same in a wide cell, with the time to the reset
  noData: ['lcd', '无数据', 'No data'], // a good reading without a value for this window
  evAt: ['lcd', '↺~{at}', '↺~{at}'], // a public reset announced for about this time (blue)
  evMark: ['lcd', '↺', '↺'], // the same in a narrow column
  evDone: ['lcd', '↺✓', '↺✓'], // a public reset confirmed, the next reading will show it
  evTitle: ['aria', '官方预告约 {at} 额外重置', 'Public reset announced for about {at}'],
  evDoneTitle: ['aria', '官方已确认额外重置，等下次读数', 'Public reset confirmed, waiting for the next reading'],
  failed: ['lcd', '读取失败', 'No read'],
  failedAge: ['lcd', '失败·{a}', 'Fail·{a}'],
  failedShort: ['lcd', '失败', 'Failed'],
  loading: ['lcd', '读取中', 'Reading'],
  loadingShort: ['lcd', '读取', 'Wait'],
  ageCompact: ['lcd', '−{t}', '−{t}'],
  quotaOnly: ['lcd', '仅额度', 'Quota only'],
  tps: ['lcd', 't/s', 't/s'],
  // 专项: extra quotas (a model's or a feature's own limit); +1 = one more extra in the column
  xMore: ['lcd', '+{n}', '+{n}'],
  // 储备: reset cards and credits
  cards: ['lcd', '↺{n}', '↺{n}'],
  credits: ['lcd', '{n}点', '{n} cr'],
  expires: ['lcd', '{t}后到期', 'exp {t}'],
  hours: ['lcd', '{n}h', '{n}h'],
  days: ['lcd', '{n}天', '{n}d'],
  drawing: ['line', '额度用完 · 正在扣点数', 'Used up · drawing credits'],
  drawingShort: ['lcd', '扣点中', 'drawing'],
  // accessible names and hover titles (not drawn)
  noReading: ['aria', '无读数', 'No reading'],
  left: ['aria', '剩 {v}%', '{v}% left'],
  used: ['aria', '已用 {v}%', '{v}% used'],
  lvMid: ['aria', '偏紧', 'tight'],
  lvLow: ['aria', '告急', 'critical'],
  stale: ['aria', '读数过期', 'stale reading'],
  keyAria: ['aria', '{name}：只看这份订阅（键 {k}）', '{name}: show this subscription only (key {k})'],
  allAria: ['aria', '全部订阅（键 0）', 'All subscriptions (key 0)'],
  cautionLitAria: ['aria', '主告警：按下确认并查看告警', 'Master caution: press to acknowledge and see the alerts'],
  cautionAria: ['aria', '主告警灯（无告警）', 'Master caution (no alerts)'],
  empty: ['text', '未检测到订阅 · modelplan doctor', 'No subscriptions found · modelplan doctor'],
  pgPrevAria: ['aria', '上一页订阅', 'Previous subscriptions'],
  pgNextAria: ['aria', '下一页订阅', 'Next subscriptions'],
  pgAria: ['aria', '第 {p} 页，共 {n} 页', 'Page {p} of {n}'],
  pgAlert: ['aria', '第 {p} 页有{lv}的订阅', 'page {p} has a {lv} subscription'],
});

// Extra quotas (专项): the name with its period, shared by the engine table, the hover card, the Main screen and the
// alerts (core.js builds the label). In a narrow column the name shrinks to a short tag (F·周, MCP).
register('extra', {
  name: ['lcd', '{n}·{p}', '{n}·{p}'],
  'per.5h': ['lcd', '5时', '5h'],
  'per.day': ['lcd', '日', 'day'],
  'per.week': ['lcd', '周', 'wk'],
  'per.month': ['lcd', '月', 'mo'],
  titleMore: ['aria', '另有 {n} 项专项额度', {"one": "{n} more extra quota", "other": "{n} more extra quotas"}],
});
register('xdemo', {
  simFable: ['demo', 'Fable 降到 9%', 'Fable drops to 9 %'],
  simTwo: ['demo', 'Claude 两项专项', 'Two extras on Claude'],
});
