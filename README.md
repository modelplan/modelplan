# Model Plan clients

[Model Plan](https://modelplan.guanbear.com) 的公开客户端：在你常用的 AI 编程工具里直接回答「用哪个模型、开哪一档、往上推一档值不值」。
Public clients for [Model Plan](https://modelplan.guanbear.com): answer "which model, which effort, and is the next step worth it" inside the tools you already use.

| | 目录 Directory | 说明 What it is |
| --- | --- | --- |
| Claude Code 插件 | [`claude-code/`](claude-code/) | `/modelplan:lineup`、`/modelplan:effort`、状态栏、Model Plan Skill |
| Model Plan Skill | [`skills/model-plan/`](skills/model-plan/) | 任何支持 Skill 的 Agent 都能用；只需要 shell 和匿名 HTTPS |
| `modelplan` 命令行 CLI | [`cli/`](cli/) | 单文件、只读、匿名；插件的命令和状态栏靠它取数 |

所有客户端只读 Model Plan 已核验的公开数据：不需要账号、不收集数据、不会替你切换模型或档位。
Every client reads only Model Plan's verified public publication: no account, no telemetry, and it never switches your model or effort for you.

## 安装 Install

**1. 命令行 CLI**（macOS / Linux）

```sh
curl -fsSL https://raw.githubusercontent.com/modelplan/clients/main/install.sh | sh
modelplan sync
modelplan lineup --dev anthropic
```

Windows 或手动安装：从 [Releases](https://github.com/modelplan/clients/releases) 下载对应平台的压缩包，把 `modelplan` 放进 `PATH`。也可以 `go install github.com/modelplan/clients/cli/cmd/modelplan@latest`。

**2. Claude Code 插件**

```text
/plugin marketplace add modelplan/clients
/plugin install modelplan@modelplan
```

可选：运行 `/modelplan:statusline`，确认后安装状态栏。Optional: run `/modelplan:statusline` to add the status line after you confirm.

**3. 只要 Skill**：把 [`skills/model-plan`](skills/model-plan/) 整个目录复制到 `~/.claude/skills/model-plan`（或你的 Agent 的 skills 目录）。没有 CLI 时 Skill 会直接读公开 API。
Skill only: copy [`skills/model-plan`](skills/model-plan/) into `~/.claude/skills/model-plan` (or your agent's skills directory). Without the CLI it reads the public API directly.

## 数据 Data

数字（能力、参考任务成本、耗时、★ 推荐档、「最强 / 最划算」等结论）全部来自 Model Plan 公开发布的数据，客户端不自行计算排名。方法与来源见 [modelplan.guanbear.com](https://modelplan.guanbear.com)。
All numbers and verdicts come from Model Plan's published data; clients never compute their own rankings.
