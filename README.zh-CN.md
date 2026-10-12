# Model Plan

**写代码用哪个 AI 模型、开哪一档推理、往上推一档值不值？**
[Model Plan](https://modelplan.ai) 用已核验的公开数据回答这些问题：覆盖每个模型、每个原生档位的能力、参考任务成本和耗时，还有 Coding 套餐的价格、额度重置和用量时段。

[English](README.md) · 简体中文

本仓库是 Model Plan 的开源客户端。数字背后的方法以后也会在这里公开。

| | 目录 | 说明 |
| --- | --- | --- |
| Codex 插件 | [`codex/`](codex/) | GPT 档位看板、能力／成本／耗时曲线及公开重置公告 |
| Claude Code 插件 | [`claude-code/`](claude-code/) | `/modelplan:lineup`、`/modelplan:effort`、状态栏和 Model Plan Skill |
| Model Plan Skill | [`skills/model-plan/`](skills/model-plan/) | 任何支持 Skill 的 Agent 都能用，只需要 shell 和匿名 HTTPS |
| `modelplan` 命令行 | [`cli/`](cli/) | 单个可执行文件，只读、匿名；插件的命令和状态栏用它取数 |

所有客户端只读取 Model Plan 已核验的公开数据：不需要账号，不收集任何数据，也不会替你切换模型或档位。

## Codex 插件

GPT 推荐档、能力／成本／耗时曲线和公开重置公告，桌面看板与 CLI 文字回退。需要 Node.js 24+。

```sh
codex plugin marketplace add modelplan/modelplan
codex plugin add modelplan-codex@modelplan
```

[安装和使用](codex/README.zh-CN.md)

## 安装

**1. 命令行**（macOS / Linux）

```sh
curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh
modelplan sync
modelplan lineup --dev anthropic
```

Windows 或想手动安装：从 [Releases](https://github.com/modelplan/modelplan/releases) 下载对应平台的压缩包，把 `modelplan` 放进 `PATH`。装了 Go 的话：`go install github.com/modelplan/modelplan/cli/cmd/modelplan@latest`。

**2. Claude Code 插件**

```text
/plugin marketplace add modelplan/modelplan
/plugin install modelplan@modelplan
```

可选：运行 `/modelplan:statusline`，确认后加上状态栏。

**3. 只装 Skill**：把 [`skills/model-plan`](skills/model-plan/) 整个目录复制到 `~/.claude/skills/model-plan`（或你所用 Agent 的 skills 目录）。没装命令行时，Skill 会直接读公开 API。

## 数据

所有数字和结论都来自 Model Plan 公开发布的数据：能力、参考任务成本和耗时、★ 推荐档，以及「最强」「最划算」这类结论。客户端不会自己算排名。方法和数据来源见 [modelplan.ai](https://modelplan.ai)。

## 许可证

[MIT](LICENSE)
