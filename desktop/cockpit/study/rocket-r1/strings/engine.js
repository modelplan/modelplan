// Engine table strings (P2 owns this file). [class, zh-CN, en]
// Times inside the values use the fixed d/h/m forms (45m, 2h14, 3d5h) in both languages (spec 2.2).
import {register} from '../i18n.js';

register('eng', {
  // D474 §3.1: columns per page by language (zh 6, en 5); the pseudo-long test locale overrides it to 4.
  perPage: ['aria', '6', '5'],
  // D474 §7.1 hover card (title / facts / basis). Every figure and mark of the band explains itself.
  hcRead: ['aria', '读数 {a}前', 'read {a} ago'],
  hcEstimate: ['aria', '按最近的用量估算', 'estimated from recent use'],
  hcTotal: ['aria', '共 {n} token', '{n} tokens in total'],
  hcInput: ['aria', '输入 {n}', 'input {n}'],
  hcCacheWrite: ['aria', '缓存写入 {n}', 'cache write {n}'],
  hcCacheRead: ['aria', '缓存读取 {n}', 'cache read {n}'],
  hcOutput: ['aria', '输出 {n}', 'output {n}'],
  hcReasoning: ['aria', '含推理 {n}', 'incl. reasoning {n}'],
  hcCacheShare: ['aria', '缓存读占 {p}%', 'cache reads are {p}%'],
  hcCost: ['aria', '{c} · 按公开 API 价估算', '{c} at public API prices'],
  hcUnpriced: ['aria', '{p}% 的用量没有公开价，未计入', '{p}% of use has no public price, not counted'],
  hcShared: ['aria', '今天的用量按工具记，这 {n} 个 {tool} 订阅分不开 · {tool} 合计 {total}', 'Today’s use is counted per tool, so these {n} {tool} subscriptions cannot be split · {tool} total {total}'],
  hcSharedTitle: ['aria', '{tool} · 今天', '{tool} · today'],
  hcRangeTitle: ['aria', '{s} · {r}', '{s} · {r}'],
  hcWindowTitle: ['aria', '{s} · {w}', '{s} · {w}'],
  hcReserveTitle: ['aria', '{s} · 储备', '{s} · Reserve'],
  hcCardLine: ['aria', '{n} 次重置 · {t} 后到期', '{n} reset(s) · expires in {t}'],
  hcCardNoExpiry: ['aria', '{n} 次重置 · 没有到期时间', '{n} reset(s) · no expiry time'],
  hcPoints: ['aria', '点数 {v}', 'points {v}'],
  hcKeyPlan: ['aria', '方案 {p}', 'plan {p}'],
  hcKeyAlias: ['aria', '别名 {a}', 'alias {a}'],
  agoLine: ['lcd', '{t}前', '{t} ago'],
  aroundAt: ['lcd', '{t} 前后', 'around {t}'],
  addSubscription: ['aria', '＋ 添加订阅', '＋ Add a subscription'],
  usage7: ['lcd', '7日用量', '7d usage'],
  now: ['lcd', '现在', 'Now'],
  resetPoint: ['lcd', '重置', 'Reset'],
  timelineAria: ['aria', '现在到重置 {reset}', 'Now to reset {reset}'],
  // Owner C01: fixed 5小时 / 每周 / 其他 labels; nonmatching windows carry their own period tag in Other.
  today: ['silk', '今天', 'Today'], // CKP-ENG-53: the range row is labelled with its range (today until the range switch lands)
  speed: ['silk', '速度', 'Speed'],
  reserve: ['silk', '储备', 'Reserve'],
  // Owner D76: what the Reserve row holds, as a hover hint on its label (not drawn otherwise).
  reserveHint: ['aria', '储备：还能用的额外重置次数和剩余点数', 'Reserve: banked resets you can still use and remaining credits'],
  row5h: ['lcd', '5小时', '5h'],
  rowDay: ['lcd', '每日', 'Daily'],
  rowWeek: ['lcd', '每周', 'Weekly'],
  rowMonth: ['lcd', '每月', 'Monthly'],
  todayBasis: ['aria', '今日 token 总量（输入、缓存、输出）；今日平均生成速度为可测速输出 token 总量除以生成秒数总量，不是实时速度；按当前来源关联，非历史账户归属', 'Today’s total tokens (input, cache, output); today’s average generation speed is summed eligible output tokens divided by summed generation seconds, not live speed; current source binding, not historical account attribution'],
  averageAria: ['aria', '今日平均生成速度 {n} token 每秒', {"one": "Today’s average generation speed {n} token per second", "other": "Today’s average generation speed {n} tokens per second"}],
  resetUnknownShort: ['lcd', '未知', '?'],
  resetWordOne: ['lcd', '重置 1 次', '1 reset'],
  resetCompactOne: ['lcd', '1次', '1 reset'],
  resetsWords: ['lcd', '重置 {n} 次', {"one": "{n} reset", "other": "{n} resets"}],
  resetsCompact: ['lcd', '{n}次', {"one": "{n} reset", "other": "{n} resets"}], // D474 §3.1 narrow: 3次·40h到期
  balance: ['lcd', '余额 {v}', 'Balance {v}'], // G3-109: a money balance in the reserve row
  creditWords: ['lcd', '{n} 点', {"one": "{n} credit", "other": "{n} credits"}],
  other: ['silk', '其他', 'Other'], // a window of unknown kind
  extra: ['silk', '额外', 'Extra'], // D417: heading of the third row when its columns name different windows (each cell names its own)
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
  resetIn: ['lcd', '{t} 后重置', 'resets in {t}'],
  resetUnknown: ['lcd', '重置未知', 'reset ?'],
  // D474 §3.2 (CKP-ENG-26, LBL-2.2-51): 预估 is our forecast; 约 is only for ≈$ and published approximations.
  runOut: ['lcd', '预估 {t} 用完', 'est. out in {t}'], // the hover and the timeline: the window runs out before it resets
  runOutC: ['lcd', '预估 {t} 用完', 'est. out in {t}'],
  // D474 §3.2: every quota cell has two lines. Line 1 = the real reset (ink-3, never coloured); line 2 = the estimate
  // (amber or red only when it runs out before the reset), else faint 够用到重置. Narrow cells use the short forms.
  resetLine: ['lcd', '{t} 后重置', 'resets in {t}'],
  resetNarrow: ['lcd', '{t}后', 'in {t}'],
  estLine: ['lcd', '预估 {t} 用完', 'est. out in {t}'],
  estNarrow: ['lcd', '{t}完', 'out {t}'],
  lasts: ['lcd', '够用到重置', 'lasts to reset'],
  lastsNarrow: ['lcd', '够用', 'lasts'],
  lastTry: ['aria', '上次尝试 {at}', 'Last attempt {at}'], // §3.4 lapse: a lapsed kept reading's hover
  // round D2 cell states
  drawCell: ['lcd', '扣点中', 'credits'], // used up, credits being drawn (red, line 2)
  drawLine: ['line', '扣点中 · {t}', 'credits · {t}'], // the same in a wide cell, with the time to the reset
  noData: ['lcd', '无数据', 'No data'], // a good reading without a value for this window
  failed: ['lcd', '读取失败', 'No read'],
  unreadable: ['lcd', '读不到', 'no reading'], // CKP-ENG-50: dim -- with this grey word; the cause is in the card, Settings and the overview
  usedUp: ['lcd', '已用完', 'used up'], // CKP-ENG-50: red 0% with this word; the reset time is in the dots and the alert line
  failedAge: ['lcd', '失败·{a}', 'Fail·{a}'],
  failedShort: ['lcd', '失败', 'Failed'],
  loading: ['lcd', '读取中', 'Reading'],
  loadingShort: ['lcd', '读取', 'Wait'],
  ageCompact: ['lcd', '−{t}', '−{t}'],
  quotaOnly: ['lcd', '仅额度', 'Quota only'],
  // G3-156 / CKP-ENG-53: the range row follows the header range; history is read but nothing is recorded in the range
  noUsage: ['lcd', '{r}暂无用量', 'No usage {r}'],
  rangeToday: ['silk', '今天', 'Today'], range7d: ['silk', '7天', '7d'], range30d: ['silk', '30天', '30d'],
  noUsageRangeToday: ['lcd', '今天', 'today'], noUsageRange7d: ['lcd', '7天', 'in 7d'], noUsageRange30d: ['lcd', '30天', 'in 30d'],
  rangeBasis: ['aria', '所选时间范围内的 token 总量与平均生成速度（可测速输出 token 总量除以生成秒数总量），按当前来源关联，非历史账户归属', 'Total tokens and average generation speed over the selected range (measurable output tokens over generation seconds); bound to the current source, not historic account ownership'],
  costHint: ['aria', '估算费用：按公开价格和你的用量估算，不是账单', 'Estimated cost: your usage at public prices, not a bill'], // CKP-ENG-53 ≈
  tps: ['lcd', 't/s', 't/s'],
  // 专项: extra quotas (a model's or a feature's own limit); +1 = one more extra in the column
  xMore: ['lcd', '+{n}', '+{n}'],
  // 储备: banked resets and credits
  cards: ['lcd', '↺{n}', '↺{n}'],
  credits: ['lcd', '{n}点', '{n} cr'],
  // D474 §3.1 (CKP-ENG-52, C24, C43): the reserve's amber clause says how many expire and when, within 48 h only.
  expires: ['lcd', '{n} 次 {t} 后到期', {"one": "{n} expires in {t}", "other": "{n} expire in {t}"}],
  expiresShort: ['lcd', '{t}到期', '{n} exp. {t}'],
  expiresNarrowest: ['lcd', '{t}到期', 'reset exp. {t}'],
  // D466: the reserve's blue "+1" (a banked reset confirmed during its news clock) and the key's one blue news dot.
  plusAria: ['aria', '新增 {n} 次', {"one": "{n} new", "other": "{n} new"}],
  newsAnnounced: ['aria', '有重置公告（已预告）', 'Reset news (announced)'],
  newsConfirmed: ['aria', '有重置公告（已确认）', 'Reset news (confirmed)'],
  points: ['lcd', '点数 {v}', 'Credits {v}'], // CKP-ENG-52: the reserve's credits say what they are
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
  name: ['lcd', '{n} · {p}', '{n} · {p}'], // CKP-ENG-51: MCP · 月
  nameShort: ['lcd', '{n}·{p}', '{n}·{p}'], // the narrow tag (F·周)
  'per.5h': ['lcd', '5时', '5h'],
  'per.day': ['lcd', '日', 'day'],
  'per.week': ['lcd', '周', 'wk'],
  'per.month': ['lcd', '月', 'mo'],
  // C33: an extra's hover always names its period: "MCP · 每月额度".
  hover: ['aria', '{n} · {p}', '{n} · {p}'],
  'quota.5h': ['aria', '5小时额度', '5h quota'],
  'quota.day': ['aria', '每日额度', 'daily quota'],
  'quota.week': ['aria', '每周额度', 'weekly quota'],
  'quota.month': ['aria', '每月额度', 'monthly quota'],
  titleMore: ['aria', '另有 {n} 项专项额度', {"one": "{n} more extra quota", "other": "{n} more extra quotas"}],
});
register('xdemo', {
  simFable: ['demo', 'Fable 降到 9%', 'Fable drops to 9 %'],
  simTwo: ['demo', 'Claude 两项专项', 'Two extras on Claude'],
});
