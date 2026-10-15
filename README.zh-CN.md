# Model Plan

**写代码用哪个 AI 模型、开哪一档推理、往上推一档值不值？**
[Model Plan](https://modelplan.ai) 用已核验的公开数据回答这些问题：覆盖每个模型、每个原生档位的能力、参考任务成本和耗时，还有 Coding 套餐的价格、额度重置和用量时段。

[English](README.md) · 简体中文

## 为什么用 Model Plan

- **★ 档位推荐：** 同一个模型从 Low 到 Max，差的不只是分数，成本和时间往往差好几倍。我们给每个模型算出最值的 ★ 推荐档，并告诉你再往上推一档能多拿几分、要多花几倍。
- **推荐档下的模型榜单：** 别家榜单通常只比各模型的最高档。Model Plan 让每个模型都按自己的推荐档上场，比的是你实际会用的配置；3D 发射场和「选哪台」图把能力、成本、耗时放在一起看。
- **套餐推荐**（完善中）：Coding 套餐按厂商、模型、价位比较，看价格、额度，以及每个套餐能用哪些模型和档位；优惠时段和额度重置放在周历上。精确的套餐—模型—档位对应还在补全。
- **按你的剩余额度规划：** 读取本机 Claude Code 和 Codex 的 5 小时 / 每周额度和重置时间（只在本机读，不上传）。快重置还剩很多时提示可以升档（Codex 还可以开 Fast），额度偏紧时提示保持 ★ 或降档。
- **在你的工具里：** 同样的答案，通过本仓库的插件、Skill 和命令行，直接出现在 Claude Code、Codex 和终端里。

本仓库是 Model Plan 的开源客户端，也公开了[方法与来源](METHODOLOGY.zh-CN.md)：能力、成本、耗时和 ★ 推荐档怎么算，以及背后的数据源。

| | 目录 | 说明 |
| --- | --- | --- |
| **Model Plan Skill** | [`skills/model-plan/`](skills/model-plan/) | 主角。Claude Code、Codex 和任何支持 Skill 的 Agent 都能用：选模型和档位、每升一档的倍数、按剩余额度和重置时间规划。只需要 shell 和匿名 HTTPS |
| Claude Code 插件 | [`claude-code/`](claude-code/) | Skill + `/modelplan:plan`、`/modelplan:effort`、`/modelplan:lineup`，以及显示实时档位和 5 小时 / 7 天额度的状态栏 |
| Codex 插件 | [`codex/`](codex/) | Skill + GPT 档位看板：能力／成本／耗时曲线、你的 Codex 额度和重置倒计时、公开重置公告 |
| `modelplan` 命令行 | [`cli/`](cli/) | 单个可执行文件，只读、匿名；`modelplan quota` 汇总本机额度，状态栏和插件命令用它取数 |

所有客户端只读取 Model Plan 已核验的公开数据，以及各工具本来就写在你电脑上的额度记录：不需要账号，不收集、不上传任何个人数据，也不会替你切换模型或档位。

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

所有数字和结论都来自 Model Plan 公开发布的数据：能力、参考任务成本和耗时、★ 推荐档，以及「最强」「最划算」这类结论。客户端不会自己算排名。方法和数据来源见 [METHODOLOGY.zh-CN.md](METHODOLOGY.zh-CN.md) 和 [modelplan.ai/methodology](https://modelplan.ai/methodology)。

发现价格、额度、档位或快报不对？欢迎[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)。modelplan.ai 上的「报错」链接会自动填好页面和条目。

## 许可证

[MIT](LICENSE)
