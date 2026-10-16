# Model Plan × Claude Code

把 Model Plan 已核验的公开数据和你自己的额度带进 Claude Code：用哪个模型、开哪一档、每升一档多几分贵几倍，以及额度快重置时该不该升档。只读、只给建议，不会替你切换模型、档位或 fast。
Model Plan's verified public data plus your own quota inside Claude Code. Read-only and advisory.

| 功能 Piece | 作用 What it does |
| --- | --- |
| `model-plan` Skill | 回答「用哪个模型 / 哪一档」「升一档值不值」「额度快重置了要不要开 fast」。也可以单独装到任何支持 Skill 的 Agent |
| `/modelplan:plan [要做的事]` | 结合 5 小时 / 7 天额度和重置时间，给出现在用什么、为什么、什么时候换回来 |
| `/modelplan:effort [模型]` | 档位阶梯：相对 ★ 推荐档和相对低一档的能力与成本倍数；不写模型时用当前会话的模型 |
| `/modelplan:lineup [厂商]` | 一家厂商各模型在 ★ 推荐档下的能力与成本，哪些可以跳过 |
| `/modelplan:setup` | 逐项检查插件、CLI、状态栏、钩子是否就绪；缺 CLI 时征得同意后安装，装完再查一遍 |
| `/modelplan:statusline` | 征得同意后写入状态栏设置（用 CLI 的完整路径，桌面端或 IDE 的 PATH 较短也能用） |
| `UserPromptSubmit` 钩子（唯一的钩子） | 你发消息时：有新的额度提示（快重置还有余量、额度偏紧或用完、重置后换回 ★、手填套餐的高峰时段或重置卡快过期）就用一句话转告 Claude，同一件事只说一次；每个会话的第一条消息附一份**任务开始简报**（下面说明）；数据过旧时在后台刷新。只读本机缓存，从不等网络 |

**任务开始简报**：每个会话第一条消息时，钩子交给 Claude 一份简短材料：Anthropic 各模型在 ★ 档的能力和相对成本（被更好选项压过的标“可跳过”）、普通任务的默认配置（已发布的最划算模型 ★ 档；它比最强模型低 3 分以上时改用最强的，现在是 Opus 5.5 ★Med，两者都是它）、当前模型各档相对当前档的分数和倍数，以及额度余量。Claude 自己判断任务难度，只有当前设置明显不合适时才用一句话建议，不会替你切换。当前模型和档位来自状态栏为**本会话**记录的读数；状态栏记录的是别的会话时写“未知”。`MODELPLAN_TASK_BRIEF=off` 关闭。

**设置提醒**：没装 CLI、CLI 太旧、状态栏还没记录过额度时，钩子在聊天里提示一次，并请 Claude 在回答末尾问你一次要不要补上；你说“暂不”，它会记下来，90 天内不再提。之后同一件事最多每周提示一次，不再询问。CLI 版本够新、状态栏也在记录时，不会有任何设置提示。状态都在 `~/.cache/modelplan-claude-code`。

状态栏 Status line:

```text
▲ Opus 5.5 ★Med │ 能力 55.4 │ 成本 ×6.0 vs Haiku 5.5 │ 最强 最划算 │ 5小时 35% ↻40分 · 每周 30% ↑High ×1.37
▲ Opus 5.5 High (★Med) │ 能力 60.2 │ 5小时 93% ↻40分 · 每周 30% ↓★Med ×0.73
▲ Opus 5.5 High (★Med) │ 能力 60.2 │ 5小时 3% ↻4时40分 · 每周 31% ↺★Med
```

- 档位和 fast 状态来自 Claude Code 本身；★ 是 Model Plan 的推荐档。
- 额度：Claude Code 只把 5 小时 / 7 天用量传给状态栏（Pro / Max 订阅）。Model Plan 状态栏把这几个数字存进本机缓存，`/modelplan:plan` 和 Skill 才读得到。不上传任何东西。
- `↑`：这个窗口重置前大概率用不完，升档不浪费。注意 Claude Code 的 fast 模式扣的是 usage credits（另付费），不占订阅额度，额度富余不是开 fast 的理由。`↓`：按当前速度会提前用完，保持 ★ 或降一档。
- `↑High ×1.37`：5 小时窗口 40 分钟后重置还剩很多，可以升到 High，成本是现在的 1.37 倍。`↓★Med ×0.73`：偏紧，降回 ★。`↺★Med`：之前提示过升档或降档的窗口已经重置，可以换回 ★ 推荐档（重置后 90 分钟内显示，已经在 ★ 就不显示）。
- 状态栏只读本地缓存，从不等网络。
- 想看完整提示：`modelplan advise`。

The status line shows the live effort and fast mode Claude Code reports, Model Plan's ★ effort, and your 5-hour / 7-day usage with time to reset. It saves those numbers in the local Model Plan cache so `/modelplan:plan` and the Skill can plan around them. Nothing leaves your machine.

## 安装 Install

1. 在 Claude Code 里：

   ```text
   /plugin marketplace add modelplan/modelplan
   /plugin install modelplan@modelplan
   ```

2. `/modelplan:setup`：检查各部分，缺 `modelplan` CLI 时征得同意后安装（最新版本，按发布的校验和核对，装到 `~/.local/bin`，不改 PATH、配置文件，也不用 sudo）。
3. `/modelplan:statusline`，然后就可以用 `/modelplan:plan`。

升级插件：`/plugin marketplace update modelplan`，然后在 `/plugin` 里更新 modelplan，重启 Claude Code。插件钩子随插件启用，不需要单独审核；钩子没运行时 `/modelplan:setup` 会说明（`disableAllHooks` 或组织策略会关掉它）。

1. Install the plugin as above, then run `/modelplan:setup`: it reports the plugin, CLI, status line and hook one by one and, with your consent, installs the CLI. 2. `/modelplan:statusline`. The single `UserPromptSubmit` hook passes new quota hints once, gives Claude a task-start brief on each session's first prompt (the published options, the default configuration, the current model's ladder; advice only), and shows a setup notice once when something is missing (asked once, then at most weekly, quiet for 90 days after "not now").

已经有自己的状态栏？在脚本开头加一行即可只记录额度、不改显示：
Keep your own status line and only record quota:

```sh
input=$(cat); printf %s "$input" | modelplan statusline --record-only
```
