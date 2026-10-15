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

状态栏 Status line:

```text
▲ Opus 5.5 High (★Med) │ 能力 60.2 │ 5小时 39% ↻42分 · 每周 41% ↑
▲ Opus 5.5 ★Med │ 能力 55.4 │ 成本 ×6.0 vs Haiku 5.5 │ 最强 最划算 │ 5小时 72% ↻3时20分 · 每周 88% ↓
```

- 档位和 fast 状态来自 Claude Code 本身；★ 是 Model Plan 的推荐档。
- 额度：Claude Code 只把 5 小时 / 7 天用量传给状态栏（Pro / Max 订阅）。Model Plan 状态栏把这几个数字存进本机缓存，`/modelplan:plan` 和 Skill 才读得到。不上传任何东西。
- `↑`：这个窗口重置前大概率用不完，升档或开 fast 不浪费。`↓`：按当前速度会提前用完，保持 ★ 或降一档。
- 状态栏只读本地缓存，从不等网络。

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
