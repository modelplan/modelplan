# Local effort suggestion

The suggestion is **on by default** (owner decisions D101 and D102). It is advice
only: ModelPlan never changes the harness's model, effort or Fast setting, never
uploads anything, and never puts it in hook output, agent context, MCP results or
desktop JSON. Turn it off with `modelplan history --effort-suggestion off`,
`MODELPLAN_EFFORT_SUGGESTION=off`, or the Settings toggle (`history.SetEffortSuggestion`
writes the same state; `history.EffortSuggestionEnabled` reads it). `dismiss` hides it
for seven days and `on` turns it back on. State is `<cache>/observed/effort-suggestion.json`
(0600); `MODELPLAN_HISTORY=off` disables it too.

## The rule

The base is the published ★ (recommended) effort of the model you mainly use. The rule
only adjusts it from your own quota, on the **same model**, at most **two rungs** from ★,
on the published ladder. Your current effort does not change the target (a suggestion
you already sit at or beyond is not shown). There are no model-switch and no Fast
suggestions. Projections are internal gates, never shown.

- **Up** (one rung above ★ at most): the last three finished weekly cycles of one pool
  show headroom (average final use at most 60%, none above 75%, no limit hit) and the
  projected use at that rung stays at or below 85%; or a reset (scheduled or officially
  announced) is close with much left (advise's existing "resets unused" verdict, no
  cycle history needed).
- **Down** (one or two rungs below ★): history shows a limit hit in two of the last three
  cycles or average use of 90% or more; or the live pace (used% at least ten points over
  elapsed%, window at least 10% elapsed, recent day rate runs out before the reset)
  shows a shortfall. The smallest drop whose projection fits is chosen, else the
  largest allowed. No history is needed for the live case.
- Otherwise nothing. Silence also covers fewer than three finished cycles (for history),
  gaps, mixed workload (under 60% of points on one configuration), a missing ★ or
  published cost, and a stale publication.

Every outcome has a reason code (`history.Reason*`, also on the suggestion's `reason` and
`basis` fields): `headroom-history`, `reset-unused`, `tight-history`, `live-runout`, and
the silent ones (`few-cycles`, `coverage-gap`, `mixed-workload`, `middle-range`,
`reset-before-runout`, `reset-imminent`, ...).

## Reset gating

The reset used is the earlier of the scheduled window reset and any officially announced
extra reset that is still standing in the published reset events
(`advise.AnnouncedResets`). A withdrawn, cancelled or not upstream-confirmed
announcement is ignored, and it is re-read on every publication read, so a change takes
effect at once. "Down" is silent when the reset comes before the projected run-out or
within about an hour.

## Copy

One short line, no numbers; the basis goes in an optional detail line.

| | zh | en |
|---|---|---|
| up | 额度富余 · 可升到 {effort} | Quota to spare · {effort} is affordable |
| down | 额度偏紧 · 建议降到 {effort} | Quota running low · try {effort} |
| detail | 依据：最近 {h} 小时 / 过去 {n} 个周期 | based on last {h}h / {n} cycles |

The status line prefixes the line with the arrow of the headroom hints (↑ spare, ↓
tight). History-based advice appears in the first 24 hours after a weekly reset; live and
reset-close advice until the reset it was gated on. All of them share one notice per
rolling seven days between `modelplan history` and the status line.

## Not yet

The cockpit fader's ★ hint (slice 4 of the spec) follows the v1 cockpit PRs. It should
read the same `DecideEffort` result (`Direction`, `ToEffort`, `Reason`, `Basis`) so its
arrow matches the status line, with dismiss and "stop suggesting" in its tooltip.

## 中文

本机档位建议**默认开启**（所有者决定 D101、D102）。它只是建议：不会改变任何工具的
型号、档位或 Fast，不上传，也不进入钩子输出、Agent 上下文、MCP 结果或桌面 JSON。
关闭方式：`modelplan history --effort-suggestion off`、`MODELPLAN_EFFORT_SUGGESTION=off`
或设置里的开关；`dismiss` 隐藏七天，`on` 重新开启。

规则：以所用型号公开发布的 ★ 档位为起点，只在同一型号内、离 ★ 最多两档，依据本机额度
历史和当前用量节奏调整；当前档位不改变目标；不建议换型号，不建议 Fast，不显示数字。
“可升”：最近三个完整周周期有富余（平均不超过 60%、没有超过 75%、未触顶，且升一档后
预计不超过 85%），或重置（含官方宣布的）临近而额度还多。“建议降”：两周触顶或平均至少
90%，或当前节奏会在重置前用完。重置在预计用完之前或一小时内时不提示“降”；被撤回或未
确认的官方重置不计入，每次读取发布数据都会重新判断。证据不足时保持沉默。
