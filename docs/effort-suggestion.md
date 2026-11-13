# Local default-effort suggestion

C14 is **off by default** pending the owner's go-live, no earlier than
2026-11-07. There is no automatic date-based activation. For local review, explicitly
opt in with `modelplan history --effort-suggestion on` or
`MODELPLAN_EFFORT_SUGGESTION=on`. Previously saved state without an explicit opt-in
stays off. Changing the shipped default requires a separate owner-approved change.

Within the first 24 hours after a weekly reset, `modelplan history` text output and
the Claude Code status-line hint share one suggestion notice per rolling seven days,
when enough local history is known. A missed reset window is skipped until a later
weekly reset. The status line shows a compact summary such as
`default: 3wk 45% ★Med→High ref ×1.37`; urgent quota advice has priority. Preview,
record-only and missing quota meters do not consume a notice. It is advice only:
ModelPlan never changes the harness's model, effort or Fast setting.

Suggestions are never included in hook output (including `systemMessage`), agent
context, MCP results or desktop JSON. Those paths neither calculate a suggestion
nor consume its weekly notice. JSON history keeps its existing raw measurement
format. The optional desktop contract field is retained for compatibility with
older clients and fixtures, but the CLI no longer populates it.

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
latest reset less than 24 hours ago. A cycle needs at least five attributed
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
model or a changed speed setting produces no status-line suggestion. Text history
uses the dominant recorded configuration when no current default is supplied. No new configuration reader is added.

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
opt in locally. State is local in `<cache>/observed/effort-suggestion.json` (0600);
deleting that file restores the shipped default and clears preferences and the
notice throttle. `MODELPLAN_EFFORT_SUGGESTION=off` or `MODELPLAN_HISTORY=off`
disables the feature even with a saved opt-in. A saved `off` also suppresses an
environment opt-in until `on` is chosen locally. Corrupt state or a failed
notification claim is silent.

## 中文

C14 默认关闭，等待所有者上线批准，最早为 2026-11-07；到期不会自动启用。
本机审核可用 `modelplan history --effort-suggestion on` 或
`MODELPLAN_EFFORT_SUGGESTION=on` 明确开启。旧状态没有明确开启标记时仍关闭；
默认开启需要另一次所有者批准的变更。

每周重置后的首 24 小时内，`modelplan history` 文本和 Claude Code 状态栏共享
每滚动七天最多一次的本机默认档位建议；错过窗口就等下一次周重置。状态栏显示三周
平均用量、相邻档位和公开参考成本比，紧急额度提示优先；预览、仅记录和无额度条时
不消耗提示次数。建议不进入钩子输出（包括 `systemMessage`）、Agent 上下文、MCP
结果或桌面 JSON；这些路径不计算建议，也不消耗提示次数。历史 JSON 保留原始测量
格式。桌面契约的可选字段为兼容旧客户端和样例而保留，CLI 不再填充。

状态栏使用当前明确的型号和档位（包括 `--model` / `--effort`），从当前档位迈一步；
档位未知、型号或速度模式不匹配时不建议。历史文本沿用主要已记录配置，不新增配置
读取器。Claude Code 状态栏不报告套餐名，记录保持空标签且不与有标签的额度池混用，
不从型号推断套餐。用量增量归于最近会话配置，不能确定并发会话各用了多少；首次读数
之前的用量不归因。

只读取本机额度周期记录和已验证的公开发布，不新增凭证或会话读取，不上传、跨用户
汇总，也不会替用户切换档位或 Fast。三个已结束的同来源、同套餐、同额度池周周期中，
每周至少归因 5 个百分点且归因比例至少 60%；主配置至少占已归因用量的 60%。平均
不超过 60%、每周不超过 75% 且未触顶时建议上调一档；平均至少 90% 或两周触顶时
建议下调一档。其他情况不猜测。倍数是公开的同一基准参考成本比，不是额度用量预测。

`modelplan history --effort-suggestion dismiss` 隐藏七天，`off` 不再建议，`on` 明确
开启；状态只保存在本机缓存。删除状态文件恢复出厂默认并清除偏好与提示次数。
环境变量 `MODELPLAN_EFFORT_SUGGESTION=off` 或 `MODELPLAN_HISTORY=off` 优先关闭；
本机保存的 `off` 也优先于环境变量开启，直到用户在本机选择 `on`。状态损坏或提示
次数写入失败时保持安静。
