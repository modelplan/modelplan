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
  wontLast: ['alert', '{s} {w} {r}% · 撑不到 {reset} 后重置', "{s} {w} {r}% · won't last {reset}"],
  low: ['alert', '{s} {w} 剩 {r}%', '{s} {w} {r}% left'],
  advice: ['alert', '{m} {e}→★{rec} 成本×{cost} 能力{abl}', '{m} {e}→★{rec} ×{cost} cost, {abl}'],
  official: ['alert', '{s} 官方：{text}', '{s} official: {text}'],
  peak: ['alert', '{s} {in} 后进入高峰 · 持续 {dur}', '{s} peak in {in} for {dur}'],
});
register('proj', {
  none: ['lcd', '未归属', 'No project'],
  letter: ['lcd', '项目 {x}', 'Project {x}'],
});
