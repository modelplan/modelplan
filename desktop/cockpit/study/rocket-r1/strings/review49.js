// Accepted task 49 cockpit details; separate from concurrent art and field-label work.
import {register} from '../i18n.js';
register('rev49', {
  point: ['aria','{m} · {e}\n能力 {a} · 参考成本 {c}\n{s}','{m} · {e}\nAbility {a} · reference cost {c}\n{s}'],
  current: ['aria','当前','current'], recommended: ['aria','★ 推荐','★ recommended'], trial: ['aria','试档（不改会话）','trial (no session changes)'], published: ['aria','已发布配置','published configuration'],
  page: ['aria','第 {p} 页：{names}。{scope}','Page {p}: {names}. {scope}'],
  pageAll: ['aria','翻页不改变全部订阅范围；按订阅键筛选','Paging preserves All; use a subscription key to filter'],
  pageSub: ['aria','翻页不改变当前订阅范围','Paging preserves the selected subscription'],
});
register('mfd', {
  projectUnknown: ['aria','本订阅的项目用量未报告；全部订阅合计 {n}','Project output for this subscription is unreported; combined total {n}'],
  projectCombined: ['aria','全部订阅的项目合计','Project total across subscriptions'],
  projectScoped: ['aria','所选订阅的项目用量','Project output attributed to the selected subscriptions'],
  sessionSpeedBasis: ['aria','本次会话的平均生成速度，不是近 60 秒速度','Average generation speed over this session, not the last 60 seconds'],
});
