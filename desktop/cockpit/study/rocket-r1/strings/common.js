// Shared strings: times, ages, alerts and project names built in core.js. [class, zh-CN, en]
import {register} from '../i18n.js';

register('time', {
  inHm: ['line', '{h} 时 {m} 分后', 'in {h} h {m} min'],
  unknown: ['lcd', '未知', 'unknown'],
});
register('age', {
  hours: ['lcd', '{h} 小时前', '{h} h ago'],
  hoursShort: ['lcd', '{h}h前', '{h}h ago'],
});
// One line each in the public-screen alert list (ellipsised on one LCD line).
register('alert', {
  runOut: ['alert', '{s} {w} {r}% · {out} 后用完 · {reset} 重置', '{s} {w} {r}% · out in {out} · reset {reset}'],
  // ALR-50 (WP-11): the parts of the one shared alert sentence (alert-sentence.js). The native table
  // (ModelPlanSettings AlertSentence.swift) holds the same words; tests/shared/alert-sentences.json pins both.
  quota: ['alert', '{s} {w} {r}%', '{s} {w} {r}%'],
  usedUp: ['alert', '{s} {w} 已用完', '{s} {w} used up'],
  out: ['alert', '约{t}用完', 'out ~{t}'],
  resets: ['alert', '{t} 后重置', 'resets in {t}'],
  unread: ['alert', '{s} 读不到', '{s} no reading'],
  unreadMany: ['alert', '{n} 个订阅读不到', {one: '{n} subscription has no reading', other: '{n} subscriptions have no reading'}],
  causeSignIn: ['alert', '未登录', 'not signed in'],
  causeKey: ['alert', '缺少密钥', 'key missing'],
  causeKeychain: ['alert', '需要钥匙串权限', 'Keychain access needed'],
  causePermission: ['alert', '需要授权', 'needs permission'],
  causeInstall: ['alert', '未安装', 'not installed'],
  causeUpdate: ['alert', '需要更新', 'update needed'],
  causeNetwork: ['alert', '网络问题', 'network problem'],
  openSettings: ['alert', '去设置 ›', 'Open Settings ›'],
  resetsAvailable: ['alert', '可用重置 {n} 次', {one: '{n} reset available', other: '{n} resets available'}],
  advice: ['alert', '{m} {e}→★{rec} 成本×{cost} 能力{abl}', '{m} {e}→★{rec} ×{cost} cost, {abl}'],
  official: ['alert', '{s} 官方：{text}', '{s} official: {text}'],
  peak: ['alert', '{s} {in} 后进入高峰 · 持续 {dur}', '{s} peak in {in} for {dur}'],
});
register('proj', {
  none: ['lcd', '未归属', 'No project'],
  letter: ['lcd', '项目 {x}', 'Project {x}'],
});
