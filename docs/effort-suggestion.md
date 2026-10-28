# Local default-effort suggestion

After a weekly reset, `modelplan history`, the Claude Code status-line hint and
Claude Code / Codex hooks share one suggestion notice per rolling seven days,
when enough local history is known. Hooks put the line only in the user's
`systemMessage`, never the model's `additionalContext`. The status line shows a
compact summary such as `default: 3wk 45% ★Med→High ref ×1.37`; urgent quota advice
has priority. Preview, record-only and missing quota meters do not consume a notice.
It is advice only: ModelPlan never changes the harness's model, effort or Fast setting.

The inputs are the local `<cache>/observed/cycles.json` ledger and the already
verified public publication. No new account, credential, transcript or log reader
is added. No quota history, suggestion or dismissal state is uploaded, aggregated
across users, or added to the automatic agent context. The existing public
publication refresh is independent of this calculation. `history --json` keeps its
existing raw history/measurement format; it does not add the derived suggestion to
the plugins' measurement feed.

The latest three completed weekly cycles must belong to the same source, recorded
plan, limit and window duration. Claude Code's status-line readings do not name a
plan: those cycles retain an empty label, kept separate from labelled pools;
no plan is inferred from the model. Resets must be five to nine days apart, with the
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

The status line supplies its explicit current model and effort (including
`--model` / `--effort` flags) to the pure `SuggestDefaultEffort` function, together
with finished weeks from its weekly pool. The adjacent step starts at that current
effort rather than an older historical effort. Unknown current effort, another
model or a changed speed setting produces no status-line suggestion. History and
the existing hook/desktop view use the dominant recorded configuration when no
current default is supplied. No new configuration reader is added.

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
Text history claims the same weekly notice as the status line and hooks. Desktop
inspection remains read-only and can review an eligible suggestion repeatedly
without consuming the notice. Corrupt state or a failed notification claim is silent.

`desktop --json` optionally adds `effortSuggestion` with the source, plan, model,
from/to published effort keys and labels, ★ key, Fast, three-week summary,
reference-cost ratio/basis, publication identity, reset/expiry and localized
`message`. It remains contract version 1. Absence means unavailable or suppressed;
it does not mean “keep” or “change” anything. Reading the suggestion never writes
its state; `desktop --read-only` preserves the command’s no-write behavior. The
input revision hashes observed ledger/preferences independently of the
clock; `validUntil` includes upcoming reset, expiry and dismissal boundaries.

## 中文

每周重置后，`modelplan history`、Claude Code 状态栏和 Claude Code / Codex 钩子
共享每七天最多一次的本机默认档位建议。钩子只在用户的 `systemMessage` 中提示，
绝不放入模型的 `additionalContext`。状态栏显示三周平均用量、相邻档位和公开参考
成本比，紧急额度提示优先；预览、仅记录和无额度条时不消耗提示次数。状态栏使用
当前明确的型号和档位（包括 `--model` / `--effort`），从当前档位迈一步；档位未知、
型号或速度模式不匹配时不建议。历史和已有钩子/桌面视图在未提供当前默认档位时
沿用主要已记录配置，不新增配置读取器。Claude Code 状态栏不报告套餐名，记录保持
空标签且不与有标签的额度池混用，不从型号推断套餐。
只读取本机额度周期记录和已验证的公开发布，不新增凭证或会话读取，不上传、跨用户
汇总，也不会替用户切换档位或 Fast。三个已结束的同来源、同套餐、同额度池周周期中，
每周至少归因 5 个百分点且归因比例至少 60%；主配置至少占已归因用量的 60%。平均
不超过 60%、每周不超过 75% 且未触顶时建议上调一档；平均至少 90% 或两周触顶时
建议下调一档。其他情况不猜测。倍数是公开的同一基准参考成本比，不是额度用量预测。

`modelplan history --effort-suggestion dismiss` 隐藏七天，`off` 不再建议，`on` 恢复；
状态只保存在本机缓存。环境变量 `MODELPLAN_EFFORT_SUGGESTION=off` 或
`MODELPLAN_HISTORY=off` 也会关闭。历史文本与状态栏、钩子共享每周提示次数；桌面
只读查询可重复查看且不消耗次数。桌面 JSON 的可选字段为 `effortSuggestion`，契约版本仍为 1。
