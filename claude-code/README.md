# Model Plan × Claude Code

把 Model Plan 已核验的公开数据带进 Claude Code。只读、只给建议，不会替你切换模型或档位。
Model Plan's verified public data inside Claude Code. Read-only and advisory.

| 功能 Piece | 作用 What it does |
| --- | --- |
| `/modelplan:lineup [厂商]` | 某家厂商各模型在 ★ 推荐档下的能力与成本，往上换一台多几分、贵几倍，哪些可以跳过 |
| `/modelplan:effort <模型>` | 一个模型各档位相对 ★ 推荐档的能力、成本、耗时 |
| `/modelplan:statusline` | 征得同意后写入状态栏设置（插件清单本身不能设置状态栏） |
| `model-plan` Skill | 让 Claude 回答「用哪个模型 / 哪档」「Sonnet 够不够」「Opus 贵多少」 |
| `SessionStart` 钩子 | 后台刷新本地缓存，不阻塞会话；没装 CLI 时静默跳过 |

状态栏 Status line:

```text
▲ Opus 5.5 ★Med │ 能力 55.4 │ 成本 ×6.0 vs Haiku 5.5 │ 最强 最划算
▲ Opus 5 ★Med │ 能力 46.5 │ 成本 ×11 vs Haiku 5.5 │ ≈ Sonnet 5.5 但更贵
```

状态栏只读本地缓存，不会每次刷新都联网。Claude Code 传给状态栏的是模型而不是档位，所以默认显示 ★ 推荐档。
The status line reads only the local cache. Claude Code passes the model, not the effort, so it shows ★ recommended by default.

## 安装 Install

1. 安装 `modelplan` 命令行（见仓库根目录 README），运行 `modelplan sync`。
2. 在 Claude Code 里：

   ```text
   /plugin marketplace add modelplan/modelplan
   /plugin install modelplan@modelplan
   ```

3. 可选：`/modelplan:statusline`。
