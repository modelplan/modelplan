# ModelPlan × Claude Code

把 ModelPlan 已核验的公开数据和你自己的额度带进 Claude Code：用哪个模型、开哪一档、每升一档多几分贵几倍，以及额度快重置时该不该升档。只读、只给建议，不会替你切换模型、档位或 fast。
ModelPlan's automatic in-agent help bundles the Skill and a checksum-checked CLI. Automatic hints default to on; the status line is an optional display. Read-only and advisory.

| 功能 Piece | 作用 What it does |
| --- | --- |
| `model-plan` Skill | 回答「用哪个模型 / 哪一档」「升一档值不值」「额度快重置了要不要开 fast」。也可以单独装到任何支持 Skill 的 Agent |
| `/modelplan:plan [要做的事]` | 结合 5 小时 / 7 天额度和重置时间，给出现在用什么、为什么、什么时候换回来 |
| `/modelplan:effort [模型]` | 档位阶梯：相对 ★ 推荐档和相对低一档的能力与成本倍数；不写模型时用当前会话的模型 |
| `/modelplan:lineup [厂商]` | 一家厂商各模型在 ★ 推荐档下的能力与成本，哪些可以跳过 |
| `/modelplan:setup` | 逐项检查插件、配套 CLI、状态栏、钩子是否就绪，没就绪的说明原因和办法 |
| `/modelplan:statusline` | **可选显示**，征得同意后写入状态栏设置（用插件配套 CLI 的固定路径 `~/.cache/modelplan-cli/modelplan`，插件升级后也不用改） |
| `UserPromptSubmit` 钩子（唯一的钩子） | 你发消息时：有新的额度提示（快重置还有余量、额度偏紧或用完、重置后换回之前的档位、手填套餐的高峰时段或重置卡快过期）就在界面上显示一行给你看，同一件事只显示一次，**不进 Claude 的上下文**，Claude 的回答不会被它打断；每个会话的第一条消息给 Claude 一份**任务开始简报**（下面说明）；数据过旧时在后台刷新。只读本机缓存，从不等网络 |

**任务开始简报**：每个会话第一条消息时，钩子交给 Claude 一份简短材料：Anthropic 各模型在 ★ 档的能力和相对成本（被更好选项压过的标“可跳过”）、普通任务的默认配置（已发布的最划算模型 ★ 档；它比最强模型低 3 分以上时改用最强的，现在是 Opus 5.5 ★Med，两者都是它）、当前模型各档相对当前档的分数和倍数，约 1200 字符。简报里没有额度数字：额度在给你看的提示里；你问到额度或某条提示时，Claude 会运行 `modelplan quota` 或 `modelplan advise` 查当前数据。额度偏紧时简报不提供升档选项。Claude 自己判断任务难度，只有当前设置明显不合适时才用一句话建议，不主动提额度，不会替你切换。每个会话只给一次；之后换到没介绍过的模型时，只补一行那个模型的档位对比，额度和档位变化不再重发。当前模型和档位来自状态栏为**本会话**记录的读数；状态栏记录的是别的会话时写“未知”。`MODELPLAN_TASK_BRIEF=off` 关闭。

**插件自带 CLI**：插件在 `cli-pin.json` 里锁定一个 `modelplan` CLI 版本和各平台程序包的 SHA-256。装好或升级插件后，钩子在后台从 GitHub 下载这个版本到 `~/.cache/modelplan-cli/<版本>`，校验值和插件里写的完全一致才使用。所以不需要另外安装或升级 CLI。不改 PATH、配置文件，也不用 sudo；你自己装的 `modelplan` 保持不动，只在配套的那份还没下载好时临时使用。下载好后聊天里提示一次；下载失败会说明原因，每周最多一次。`MODELPLAN_PLUGIN_CLI=off` 关闭自动下载。

**自动提示（默认开启） / Automatic hints (default ON)**：运行 `/modelplan:setup automatic-hints off` 关闭，`/modelplan:setup automatic-hints on` 恢复。设置保存在 `~/.config/modelplan/claude-code/automatic-hints`；关闭后提示钩子完全不输出（包括设置通知和任务开始简报），命令和状态栏仍可使用。Use these setup commands to silence or restore the whole prompt hook; explicit commands and the optional status line keep working. `/modelplan:setup` reports the saved preference.

**状态栏是可选显示。** 当前版本的 Claude Code 额度只来自它记录的本机快照；自动检测尚未上线。没有快照时额度保持未知，公开模型/档位建议和其他来源仍可使用。/ **The status line is OPTIONAL.** Today Claude Code quota comes only from its recorded local snapshot; automatic detection is coming. Without a snapshot that quota stays unknown, while public advice and other sources still work.

状态栏 Status line:

```text
▲ Opus 5.5 ★Med │ 能力 55.4 │ 5小时 ▓▓▓▓▓▓▓░░░ 剩65% ↻40分 · 每周 ▓▓▓▓▓▓▓░░░ 剩70%  ↑High ×1.37
▲ Opus 5.5 High (★Med) │ 能力 60.2 │ 5小时 ▓░░░░░░░░░ 剩7% ↻40分 · 每周 ▓▓▓▓▓▓▓░░░ 剩70%  ↓★Med ×0.73
▲ Opus 5.5 High (★Med) │ 能力 60.2 │ 5小时 ▓▓▓▓▓▓▓▓▓▓ 剩97% ↻4时40分 · 每周 ▓▓▓▓▓▓▓░░░ 剩69%  ↺★Med
▲ Opus 5.5 ★Med │ ▓▓▓▓░░ 65%↻40分 周70% ↑High ×1.37        （终端不到 100 列时）
▲ Opus 5.5 ★Med │ 能力 55.4 │ 成本 ×6.0 vs Haiku 5.5 │ 最强 最划算        （没有额度读数时）
```

- 进度条画的是**剩余**额度：剩 30% 以上为绿色，10–30% 为黄色，不到 10% 为红色；按当前速度会提前用完时，即使还剩很多也显示黄色。
- 不在 ★ 推荐档时，档位高于推荐用黄色、低于推荐用蓝色，括号里是 ★ 推荐档。
- 终端不到 100 列（Claude Code 传入的 `COLUMNS`）时自动收成短的一行：不显示能力分，每周只显示剩余百分比。

- 档位和 fast 状态来自 Claude Code 本身；★ 是 ModelPlan 的推荐档。
- 额度：当前 CLI 只读取可选状态栏记录的 Claude Code 5 小时 / 7 天快照；自动检测尚未上线。没有快照时额度未知。不上传任何东西。
- 额度记录：状态栏和钩子运行时，CLI 还会在本机记下每个额度周期用到多少、花在哪个模型和档位上（`modelplan history` 查看，保留 5 小时周期 28 天、每周周期 12 周；`MODELPLAN_HISTORY=off` 停止记录）。以后据此按你自己的几周用量建议默认档位。同时开多个会话时，用量算在最近刷新状态栏的那个会话的档位上。
- 实测速度：状态栏和钩子运行时，CLI 还会读当前会话记录里的时间戳和 token 数（不读对话内容），按模型、档位和 Fast 统计输出 tok/s、首字延迟、每轮耗时和 token；`/modelplan:effort` 和 `modelplan history` 里显示，和 ★ 推荐档对比。每份记录只存本机，同样由 `MODELPLAN_HISTORY=off` 关闭。
- `↑`：这个窗口重置前大概率用不完，升档不浪费。注意 Claude Code 的 fast 模式扣的是 usage credits（另付费），不占订阅额度，额度富余不是开 fast 的理由。`↓`：按当前速度会提前用完，保持 ★ 或降一档。`≈2时20分用完`：按最近 10–45 分钟的用量，这个窗口约 2 小时 20 分钟后用完，早于重置（只在 3 小时内会用完时显示，同时算作偏紧）。
- `↑High ×1.37`：5 小时窗口 40 分钟后重置还剩很多，可以升到 High，成本是现在的 1.37 倍。`↓★Med ×0.73`：偏紧，降回 ★。`↺★Med`：之前提示过升档或降档的窗口已经重置，可以换回提示前用的档位（这里是 ★Med）。你照提示改过档才会出现，从出现起显示 90 分钟；重置后你下一次发消息时也会说一次（24 小时内）。
- 状态栏只读本地缓存，从不等网络。
- 想看完整提示：`modelplan advise`。

The status line shows the live effort and fast mode Claude Code reports, ModelPlan's ★ effort, and your 5-hour / 7-day usage with time to reset. It saves those numbers in the local ModelPlan cache so `/modelplan:plan` and the Skill can plan around them. Nothing leaves your machine.

## 安装 Install

1. 在 Claude Code 里：

   ```text
   /plugin marketplace add modelplan/modelplan
   /plugin install modelplan@modelplan
   ```

2. 发一条消息，插件会在后台下载配套的 CLI（几秒钟）。`/modelplan:setup` 可以逐项查看是否就绪。
3. 直接使用 `/modelplan:plan`；需要可选显示时再运行 `/modelplan:statusline`。

升级插件：`/plugin marketplace update modelplan`，然后在 `/plugin` 里更新 modelplan，重启 Claude Code；配套 CLI 随后自动换成新版本。插件钩子随插件启用，不需要单独审核；钩子没运行时 `/modelplan:setup` 会说明（`disableAllHooks` 或组织策略会关掉它）。

1. Install the plugin as above and send a message: the plugin fetches its own `modelplan` CLI in the background, the release pinned in `cli-pin.json`, used only if its SHA-256 matches the pinned one, into `~/.cache/modelplan-cli` (nothing else changes; `MODELPLAN_PLUGIN_CLI=off` turns it off). Plugin updates bring the matching CLI; there is no separate install or upgrade. `/modelplan:setup` shows each part. The status line is optional; use `/modelplan:statusline` only if you want the display. With automatic hints on, the single `UserPromptSubmit` hook passes new quota hints once, gives Claude a task-start brief on each session's first prompt (the published options, the default configuration, the current model's ladder; advice only), tells you once when the CLI is ready or why its download failed. Hints and setup notices are shown to you only (the hook's `systemMessage`); Claude gets only the brief, once per session, plus one line when the session moves to a model it was not briefed on.

已经有自己的状态栏？可以继续使用；只有需要兼容旧版额度记录时，才选择在脚本开头加这一行：
Keep your own status line. If you specifically want legacy recording alongside it, this remains optional:

```sh
input=$(cat); printf %s "$input" | modelplan statusline --record-only
```
