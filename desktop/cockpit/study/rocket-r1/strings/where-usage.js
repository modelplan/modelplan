// SPDX-License-Identifier: MIT
// 去向 on D470 `history.usage` (master spec S13, §2.3, §6.1, §7.1, §7.2): its own table, so parallel work on
// strings/mfd.js never collides with it.
import {register} from '../i18n.js';
register('mfd', {
  wuIndependent: ['line', '独立对话', 'Independent chats'],
  wuHome: ['line', '主目录', 'Home folder'],
  wuNone: ['line', '无项目', 'No project'],
  wuHidden: ['line', '项目名已隐藏', 'Project name hidden'],
  wuUnnamed: ['line', '未命名项目', 'Unnamed project'],
  wuUntitled: ['line', '未命名会话', 'Untitled session'],
  wuReview: ['line', '自动审查', 'Auto Review'],
  wuReviewRuns: ['lcd', '{n} 次', {one: '{n} run', other: '{n} runs'}],
  wuOther: ['line', '其他 {n} 个', 'Other {n}'],
  wuAllSessions: ['line', '← 全部会话', '← All sessions'],
  wuProjSess: ['line', '{p} · 会话 {n} 个', {one: '{p} · {n} session', other: '{p} · {n} sessions'}],
  wuTokens: ['aria', '{t} tokens：输入 {i} · 输出 {o} · 缓存读 {cr} · 缓存写 {cw}', '{t} tokens: input {i} · output {o} · cache read {cr} · cache write {cw}'],
  wuPartial: ['aria', '部分 token 种类未报告', 'Some token kinds were not reported'],
  wuLast: ['aria', '最后活跃 {at}', 'Last active {at}'],
  wuFirst: ['aria', '首次活跃 {at}', 'First active {at}'],
  wuSessions: ['aria', '{n} 个会话', {one: '{n} session', other: '{n} sessions'}],
  wuShare: ['aria', '占本时段 token 的 {s}%', '{s}% of the tokens in this range'],
  wuCost: ['aria', '估算费用 {c}（按 API 价目估算）', 'Estimated cost {c} (API list prices)'],
  wuApprox: ['aria', '{m}（按日期推定的模型）', '{m} (model assumed by date)'],
  wuReviewTip: ['aria', 'Codex 自动审查，合成一行，不算模型', 'Codex Auto Review, folded into one row; never a model'],
  wuCutScope: ['text', '只列出全部订阅前列的行；其余计入"其他"，不按订阅区分', 'Only the top rows of all subscriptions are listed; the rest are in "other", not split by subscription'],
  wuMoreBelow: ['line', '另有 {n} 个会话不在列表中', {one: '{n} more session not listed', other: '{n} more sessions not listed'}],
  wuScopedTop: ['text', '仅列出本订阅排名靠前的会话', "Only this subscription's top-ranked sessions are listed"],
  wuCombined: ['aria', '全部订阅的项目合计', 'Project total across subscriptions'],
});
