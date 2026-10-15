# Model Plan × Claude Code

把 Model Plan 已核验的公开数据和你自己的额度带进 Claude Code：用哪个模型、开哪一档、每升一档多几分贵几倍，以及额度快重置时该不该升档。只读、只给建议，不会替你切换模型、档位或 fast。
Model Plan's verified public data plus your own quota inside Claude Code. Read-only and advisory.

| 功能 Piece | 作用 What it does |
| --- | --- |
| `model-plan` Skill | 回答「用哪个模型 / 哪一档」「升一档值不值」「额度快重置了要不要开 fast」。也可以单独装到任何支持 Skill 的 Agent |
| `/modelplan:plan [要做的事]` | 结合 5 小时 / 7 天额度和重置时间，给出现在用什么、为什么、什么时候换回来 |
| `/modelplan:effort [模型]` | 档位阶梯：相对 ★ 推荐档和相对低一档的能力与成本倍数；不写模型时用当前会话的模型 |
| `/modelplan:lineup [厂商]` | 一家厂商各模型在 ★ 推荐档下的能力与成本，哪些可以跳过 |
| `/modelplan:statusline` | 征得同意后写入状态栏设置 |
| `SessionStart` 钩子 | 后台刷新本地缓存，不阻塞会话；没装 CLI 时静默跳过 |
| `UserPromptSubmit` 钩子 | 你发消息时，如果有新提示（快重置还有余量、额度偏紧或用完、重置后换回 ★、手填套餐的高峰时段或重置卡快过期），用一句话转告 Claude。同一件事只说一次，只读本机缓存，不联网 |

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

1. 安装 `modelplan` 命令行（见仓库根目录 README），运行 `modelplan sync`。
2. 在 Claude Code 里：

   ```text
   /plugin marketplace add modelplan/modelplan
   /plugin install modelplan@modelplan
   ```

3. `/modelplan:statusline`，然后就可以用 `/modelplan:plan`。

已经有自己的状态栏？在脚本开头加一行即可只记录额度、不改显示：
Keep your own status line and only record quota:

```sh
input=$(cat); printf %s "$input" | modelplan statusline --record-only
```
