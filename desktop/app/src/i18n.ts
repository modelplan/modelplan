import type { Lang } from './snapshot.ts';

// The shell's own words. Advice sentences come from the CLI (event.text) and are not repeated here.
const zh = {
  tabs: { now: '现在', quota: '额度', effort: '档位' },
  refresh: '刷新', expand: '展开窗口', settings: '设置', quit: '退出',
  source: { 'claude-code': 'Claude Code', codex: 'Codex', user: '手填套餐' } as Record<string, string>,
  kinds: { five_hour: '5小时', weekly: '每周', monthly: '每月', spend: '限额', full: '完整', unknown: '窗口' } as Record<string, string>,
  weekNarrow: '周',
  headroom: {
    spend: '额度富余：重置前用不完，可以升档', normal: '额度正常：按 ★ 推荐档用', conserve: '额度偏紧：保持 ★ 或降一档',
    exhausted: '额度已用完：等重置或换用其他套餐', unknown: '额度未知',
  } as Record<string, string>,
  pace: { surplus: '富余', on_track: '正常', tight: '偏紧', exhausted: '用完', reset_passed: '已过重置，等待读数', unknown: '—' } as Record<string, string>,
  day: '天', hour: '时', min: '分',
  left: '剩 %s', resetsIn: '%s后重置', runsOut: '按最近的用量约 %s后用完',
  observed: '%s前', justNow: '刚刚', stale: '读数较旧',
  recentThread: '最近本机会话，不一定是当前对话',
  vsStar: '比 ★%s %s分 %s', atStar: '★ 推荐档', fast: 'Fast', notListed: '公开数据里没有这个模型',
  noSessions: '还没有会话读数。Claude Code 要启用 ModelPlan 状态栏（/modelplan:statusline），Codex 用过一次就有。',
  noAdvice: '现在没有要提醒的。',
  advice: '提醒', quota: '额度', noQuota: '没有可读的本机额度。',
  sourceStatus: { missing: '没有读数', empty: '没有数据', invalid: '读数无效', unreadable: '读不了', stale: '读数较旧', unavailable: '不可用' } as Record<string, string>,
  effortFor: '%s · %s', current: '在用', rec: '推荐', ability: '能力', cost: '成本', time: '耗时', points: '分',
  effortNote: '相对 ★ 推荐档；成本是参考任务的 API 成本，耗时是参考任务时长。',
  fastNote: 'Fast：同样的活约 %s 倍速度，按套餐额度约 %s 倍消耗（估算）。',
  noModel: '没有可以显示的模型：先在 Claude Code 或 Codex 里用一次，或者等公开数据加载。',
  measured: '你的实测（只在这台电脑上，近 28 天）', noMeasured: '还没有实测。',
  turn: '每轮 %s', rate: '输出 %s tok/s', ttft: '首字 %s', turns: '%d 轮', few: '样本不足（%d 轮）', sec: '秒',
  publication: '公开数据 %s', checked: '%s前检查', pubStale: '公开数据较旧', noPublication: '公开数据还没加载',
  local: '个人数据只在这台电脑上，不上传。',
  cliMissing: '找不到 modelplan CLI。', cliFailed: '读取失败：%s',
  notify: {
    title: '通知', tight: '额度偏紧、用完', switchBack: '重置后换回', better: '有更合适的模型', surplus: '重置前用不完（升档、开 Fast）',
    other: '高峰时段、重置卡、公开重置', test: '发一条测试通知', testBody: '通知可以正常显示。', denied: '系统没有允许通知。',
  },
  lang: '语言', menuBar: '菜单栏显示', auto: '自动（最近用的）',
};

type Words = typeof zh;

const en: Words = {
  tabs: { now: 'Now', quota: 'Quota', effort: 'Effort' },
  refresh: 'Refresh', expand: 'Open window', settings: 'Settings', quit: 'Quit',
  source: { 'claude-code': 'Claude Code', codex: 'Codex', user: 'Manual plan' },
  kinds: { five_hour: '5h', weekly: 'week', monthly: 'month', spend: 'spend', full: 'full', unknown: 'window' },
  weekNarrow: 'wk',
  headroom: {
    spend: 'Surplus: it resets unused, worth stepping up', normal: 'On track: use the ★ effort', conserve: 'Tight: stay at ★ or step down',
    exhausted: 'Exhausted: wait for the reset or use another plan', unknown: 'Quota unknown',
  },
  pace: { surplus: 'surplus', on_track: 'on track', tight: 'tight', exhausted: 'exhausted', reset_passed: 'reset passed; awaiting reading', unknown: '—' },
  day: 'd', hour: 'h', min: 'm',
  left: '%s left', resetsIn: 'resets in %s', runsOut: 'at the recent rate, used up in %s',
  observed: '%s ago', justNow: 'just now', stale: 'old reading',
  recentThread: 'latest local thread, may not be this one',
  vsStar: 'vs ★%s %s pts %s', atStar: '★ recommended', fast: 'Fast', notListed: 'Not in the published data',
  noSessions: 'No session readings yet. Claude Code needs the ModelPlan status line (/modelplan:statusline); Codex shows up once used.',
  noAdvice: 'Nothing to flag right now.',
  advice: 'Advice', quota: 'Quota', noQuota: 'No local quota readings.',
  sourceStatus: { missing: 'no reading', empty: 'no data', invalid: 'invalid reading', unreadable: 'unreadable', stale: 'old reading', unavailable: 'unavailable' },
  effortFor: '%s · %s', current: 'in use', rec: 'recommended', ability: 'Ability', cost: 'Cost', time: 'Time', points: 'pts',
  effortNote: 'Against the ★ effort; cost is the reference task\'s API cost, time its duration.',
  fastNote: 'Fast: about ×%s the speed for ×%s the plan quota (estimate).',
  noModel: 'No model to show: use Claude Code or Codex once, or wait for the published data.',
  measured: 'Measured here (this machine only, last 28 days)', noMeasured: 'Nothing measured yet.',
  turn: 'turn %s', rate: '%s tok/s out', ttft: 'first token %s', turns: '%d turns', few: 'too few samples (%d turns)', sec: 's',
  publication: 'Published data %s', checked: 'checked %s ago', pubStale: 'Published data is old', noPublication: 'Published data not loaded yet',
  local: 'Personal data stays on this computer.',
  cliMissing: 'The modelplan CLI was not found.', cliFailed: 'Could not read: %s',
  notify: {
    title: 'Notifications', tight: 'Tight or exhausted quota', switchBack: 'Switch back after a reset', better: 'A better model is available',
    surplus: 'Unused before a reset (step up, Fast on)', other: 'Peak hours, reset cards, public resets', test: 'Send a test notification',
    testBody: 'Notifications work.', denied: 'Notifications are not allowed by the system.',
  },
  lang: 'Language', menuBar: 'Menu bar shows', auto: 'Auto (most recent)',
};

export const words = (lang: Lang): Words => (lang === 'en' ? en : zh);

export const fill = (f: string, ...v: (string | number)[]): string => {
  let i = 0;
  return f.replace(/%[sd]/g, () => String(v[i++] ?? ''));
};

export function pickLang(setting: string | undefined, navigatorLanguage: string | undefined): Lang {
  if (setting === 'zh' || setting === 'en') return setting;
  return (navigatorLanguage ?? '').toLowerCase().startsWith('zh') ? 'zh' : 'en';
}

const providers: Record<string, string> = {
  copilot: 'GitHub Copilot', cursor: 'Cursor', zai: 'Z.ai / GLM Coding Plan', kiro: 'Kiro', opencodego: 'OpenCode Go',
};

export function sourceName(lang: Lang, source: string): string {
  const t = words(lang);
  if (t.source[source]) return t.source[source];
  if (source.startsWith('codexbar:')) {
    const p = source.slice('codexbar:'.length);
    return (providers[p] ?? p) + ' · CodexBar';
  }
  return source;
}

// dur: minutes as the CLI writes them ("35分", "1时35分", "3天2时"; "35m", "1h35m", "3d2h").
export function dur(lang: Lang, min: number): string {
  const t = words(lang);
  min = Math.max(0, Math.round(min));
  if (min < 60) return min + t.min;
  if (min < 48 * 60) return min % 60 === 0 ? min / 60 + t.hour : Math.floor(min / 60) + t.hour + (min % 60) + t.min;
  const d = Math.floor(min / 1440), h = Math.floor((min % 1440) / 60);
  return h === 0 ? d + t.day : d + t.day + h + t.hour;
}

// LimitName: an allowance kept apart from the main one.
export const limitName = (limit: string | undefined): string => (limit === 'reserve' ? 'Reserve' : limit ?? '');
