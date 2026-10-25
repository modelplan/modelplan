# Local default-effort suggestion

`modelplan history` shows an effort suggestion section when enough local history is
known. Claude Code and Codex hooks may show the same line in the user's
`systemMessage`, at most once per rolling seven days across both harnesses, after
a weekly reset. The line is never included in the model's `additionalContext`.
It is advice only: ModelPlan never changes the harness's model, effort or Fast setting.

The inputs are the local `<cache>/observed/cycles.json` ledger and the already
verified public publication. No new account, credential, transcript or log reader
is added. No quota history, suggestion or dismissal state is uploaded, aggregated
across users, or added to the automatic agent context. The existing public
publication refresh is independent of this calculation. `history --json` keeps its
existing raw history/measurement format; it does not add the derived suggestion to
the plugins' measurement feed.

The latest three completed weekly cycles must belong to the same source, recorded
plan, limit and window duration. Resets must be five to nine days apart, with the
latest reset less than seven days ago. A cycle needs at least five attributed
percentage points and at least 60% of its final use attributed to reviewed model
identifiers and explicit published efforts. The rest includes use before the first
reading and unknown configurations: more than 40% unattributed excludes the cycle.
We abstain if any of the latest three cycles is ineligible, rather than cherry-pick
older favorable weeks. The ledger's last usage reading is an observation, not an
estimate of unobserved use. Claude Code attributes changes to its latest session's
configuration; this cannot prove which concurrent session spent those points.

The dominant model/effort/Fast configuration must account for at least 60% of known
points and appear in at least two of those weeks. Average use at most 60%, every
week at most 75%, and no limit hits suggests one step up. Average use at least 90%
or at least two limit hits suggests one step down. Intermediate/mixed results show
nothing. These named constants are deliberately conservative: five points rejects
meter jitter, dominance avoids a mixed workload, and a wide middle range avoids
frequent reversals. They are client presentation heuristics over a user's own
observations, not a new public model ranking or a production recommendation scorer.

Adjacent efforts, the ★ marker and reference costs come from the verified
publication. Both costs must be positive and share the same nonempty cost basis;
the ratio must agree with the direction. It is a **published reference-cost ratio**,
not a forecast of the user's quota consumption. Missing effort, endpoint-dependent
alias, ladder, cost basis or applicable Fast billing means no suggestion. Fast is
preserved, requiring a published eligible subscription rate billed to plan quota;
its unchanged factor cancels in the adjacent-effort reference ratio. No Fast ratio
is invented and no recommendation to enable/disable Fast is made.

Use `modelplan history --effort-suggestion dismiss` to hide it for seven days,
`--effort-suggestion off` for “don't suggest again”, or `--effort-suggestion on` to
restore it. State is local in `<cache>/observed/effort-suggestion.json` (0600); deleting
that file clears preferences and the notice throttle. `MODELPLAN_EFFORT_SUGGESTION=off`
or `MODELPLAN_HISTORY=off` disables the feature, including hooks and desktop output.
Manual history and desktop reads can review an eligible suggestion repeatedly;
they never consume a hook notice. Corrupt state or a failed notification
claim is silent.

`desktop --json` optionally adds `effortSuggestion` with the source, plan, model,
from/to published effort keys and labels, ★ key, Fast, three-week summary,
reference-cost ratio/basis, publication identity, reset/expiry and localized
`message`. It remains contract version 1. Absence means unavailable or suppressed;
it does not mean “keep” or “change” anything. Reading the suggestion never writes
its state; `desktop --read-only` preserves the command’s no-write behavior. The
input revision hashes observed ledger/preferences independently of the
clock; `validUntil` includes upcoming reset, expiry and dismissal boundaries.

## 中文

`modelplan history` 在数据足够时显示本机默认档位建议。Claude Code / Codex 钩子
每七天最多在用户的 `systemMessage` 中提示一次，绝不放入模型的 `additionalContext`。
只读取本机额度周期记录和已验证的公开发布，不新增凭证或会话读取，不上传、跨用户
汇总，也不会替用户切换档位或 Fast。三个已结束的同来源、同套餐、同额度池周周期中，
每周至少归因 5 个百分点且归因比例至少 60%；主配置至少占已归因用量的 60%。平均
不超过 60%、每周不超过 75% 且未触顶时建议上调一档；平均至少 90% 或两周触顶时
建议下调一档。其他情况不猜测。倍数是公开的同一基准参考成本比，不是额度用量预测。

`modelplan history --effort-suggestion dismiss` 隐藏七天，`off` 不再建议，`on` 恢复；
状态只保存在本机缓存。环境变量 `MODELPLAN_EFFORT_SUGGESTION=off` 或
`MODELPLAN_HISTORY=off` 也会关闭。手动历史和桌面只读查询可重复查看，不消耗每周
钩子提示次数。桌面 JSON 的可选字段为 `effortSuggestion`，契约版本仍为 1。
