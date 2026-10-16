<div align="center">

<a href="https://modelplan.ai/?lang=zh"><img src="docs/assets/banner-zh.jpg" alt="Model Plan：用哪个模型、开哪一档、买哪个套餐" width="100%"></a>

**写代码用哪个 AI 模型、开哪一档推理、再往上推一档值不值？**<br>
Model Plan 用实时、可复核的公开数据回答，网页上能看，在 Claude Code、Codex 和终端里也能直接用。

[![Release](https://img.shields.io/github/v/release/modelplan/modelplan?style=flat-square&color=df604c&label=release)](https://github.com/modelplan/modelplan/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/modelplan/modelplan/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/modelplan/modelplan/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-d4b994?style=flat-square)](LICENSE)
[![Website](https://img.shields.io/badge/modelplan.ai-live-f0a35e?style=flat-square)](https://modelplan.ai/?lang=zh)
[![Stars](https://img.shields.io/github/stars/modelplan/modelplan?style=flat-square&color=f6d38a)](https://github.com/modelplan/modelplan/stargazers)

[网站](https://modelplan.ai/?lang=zh) · [快速开始](#快速开始) · [截图](#能做什么) · [工作原理](#工作原理) · [常见问题](#常见问题) · [方法与来源](METHODOLOGY.zh-CN.md) · [English](README.md)

</div>

## 为什么用 Model Plan

大多数榜单只比各模型的**最高档**。但同一个模型从 Low 推到 Max，成本和耗时往往翻好几倍，能力只多几分。你真正在用的，是「某个模型的某一档」。

- **★ 推荐档：** 给每个模型算出最值的档位，并且明确告诉你再升一档能多拿几分（`+4.8`）、要多花几倍（`×1.37`）。
- **推荐档下的榜单：** 每个模型都按自己的 ★ 推荐档上榜，也就是你实际会用的配置；能力旁边同时列出单个参考编程任务的成本和耗时，被超越的模型（更贵又不更强）会直接标出来。
- **结合你的额度：** Skill 和命令行读取本机 Claude Code、Codex 的 5 小时和每周额度（只在本机读，不上传）。快重置还剩很多？升一档，或开 Codex Fast。额度紧？守住 ★ 或降一档。重置之后，还会提醒你换回 ★。
- **套餐与时段：** 按厂商、模型、价位比较 Coding 套餐的价格和额度；优惠时段、高峰时段和官方额度重置放在周历上。
- **在你的工具里：** 一个开源 Skill 适配各种 Agent，另有 Claude Code 和 Codex 插件、单文件命令行，和网站读同一份已核验的公开数据。

## 快速开始

**Skill**：Claude Code、Codex、Cline、Amp 等 20 多个 Agent 都能用：

```sh
npx skills add modelplan/modelplan
```

然后问你的 Agent：「这个重构任务用哪个模型、开哪一档？」或者「我的 5 小时额度 40 分钟后重置，要不要升档？」

<details>
<summary><b>Claude Code 插件</b>：Skill、<code>/modelplan:*</code> 命令和状态栏</summary>

```text
/plugin marketplace add modelplan/modelplan
/plugin install modelplan@modelplan
```

装好后运行 `/modelplan:setup`：逐项检查 CLI、状态栏和钩子，缺什么在你同意后补上。命令：`/modelplan:plan`、`/modelplan:effort`、`/modelplan:lineup`，以及 `/modelplan:statusline`（添加状态栏，改设置前会先问你）。[详情](claude-code/)

</details>

<details>
<summary><b>Codex 插件</b>：Skill 加 GPT 档位面板</summary>

```sh
codex plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex
codex plugin add modelplan-codex@modelplan
```

对 Codex 说「打开 Model Plan 看板」。需要 Node.js 22+，Codex 自带时会自动使用。安装检查、可选 CLI 与卸载：[详情](codex/README.zh-CN.md)

</details>

<details>
<summary><b>modelplan 命令行</b>：macOS、Linux、Windows 单个静态可执行文件</summary>

```sh
curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh
modelplan lineup --dev anthropic --lang zh
```

Windows 从 [Releases](https://github.com/modelplan/modelplan/releases) 下载；用 Go：`go install github.com/modelplan/modelplan/cli/cmd/modelplan@latest`。装了它 Skill 和插件会更快，没装也能用。[详情](cli/)

</details>

<details>
<summary><b>手动安装 Skill</b></summary>

把 [`skills/model-plan`](skills/model-plan/) 复制到 `~/.claude/skills/model-plan` 或你所用 Agent 的 skills 目录。只需要 shell 和匿名 HTTPS。

</details>

## 能做什么

### ★ 最值的档位，以及再升一档的代价

推动推力杆，看每个原生档位的能力、成本和耗时；打开 ⚡ Fast 或 ⚡⚡ Ultrafast，看套餐额度和耗时怎么变。

<img src="docs/assets/effort-zh.webp" alt="档位控制台：GPT-6 Astra 从 Med 推到 Max，再切 Fast 和 Ultrafast" width="100%">

### 推荐档下的模型榜单

<img src="docs/assets/launch-zh.webp" alt="发射：每个模型按推荐档的能力升到对应高度；拖动可旋转坐标轴" width="100%">

<img src="docs/assets/engine-zh.jpg" alt="选哪台：能力对成本，金色虚线连起值得选的模型" width="100%">

### 懂你额度的建议，就在 Claude Code 和 Codex 里

<table>
<tr>
<td width="56%" valign="top">

**Claude Code 状态栏**：实时显示模型和档位、5 小时与每周用量、重置倒计时；值得动手时给出提示（快重置还有余量时 `↑High ×1.37`，额度紧时 `↓`，重置后 `↺★`）。

<img src="docs/assets/statusline-zh.png" alt="Claude Code 状态栏">

**命令行**：阵容、档位阶梯、额度和建议。

<img src="docs/assets/cli-zh.png" alt="modelplan lineup 与 modelplan effort 输出">

</td>
<td width="44%" valign="top">

**Codex 面板**：GPT 模型按 ★ 推荐档比较、带 ⚡ 开关的档位曲线、你的 Codex 额度和官方重置公告。

<img src="docs/assets/codex-zh.jpg" alt="Codex 里的 Model Plan 面板">

</td>
</tr>
</table>

### Coding 套餐、优惠时段和额度重置

<img src="docs/assets/plans-zh.jpg" alt="补给套餐：按厂商看 Coding 套餐" width="100%">

## 不只是另一个榜单

| | 常见榜单 | Model Plan |
| --- | --- | --- |
| 比较的配置 | 各模型最高档 | 各模型的 ★ 推荐档，外加其他每一档 |
| 成本 | 每百万 token 单价 | 每一档完成一个参考编程任务的成本 |
| 耗时 | 很少有 | 每一档的任务耗时（估算会标出） |
| 再升一档 | 不显示 | 每一步的 `+能力` 和 `×成本` |
| 你的额度 | 无 | 本机 Claude Code、Codex 额度，不上传 |
| 套餐 | 无 | 价格、额度、优惠时段和重置 |
| 在哪用 | 网页 | 网页、API、Skill、命令行、Claude Code、Codex |

## 工作原理

```mermaid
flowchart LR
  S["公开来源<br/>基准 · 厂商页面 · 套餐页面 · 新闻"] --> P["Model Plan 发布<br/>已核验、按内容哈希，每几小时重建"]
  P --> W["modelplan.ai"]
  P --> A["只读 API<br/>/v1/client · llms.txt"]
  A --> K["Skill"]
  A --> C["modelplan 命令行"]
  C --> CC["Claude Code 插件<br/>状态栏 · hooks"]
  C --> CX["Codex 插件<br/>面板 · hooks"]
  Q["你的额度文件<br/>（只留在本机）"] --> C
  Q --> K
```

所有客户端只读取 Model Plan 已核验的公开发布，以及你的工具本来就写在本机的额度文件。排名、结论和倍数都来自发布数据，客户端从不自己排名。公式与来源见 [METHODOLOGY.zh-CN.md](METHODOLOGY.zh-CN.md)。

**原则：** 开源（MIT）· 只读 · 匿名、无账号、无遥测 · 额度只在本机读取 · 从不替你切换模型或档位。

## 常见问题

<details>
<summary><b>★ 推荐档是什么？</b></summary>

每个模型在原生档位（Low、Medium、High、XHigh、Max……）里，能力、成本和耗时最均衡的那一档。更高的档位会标出多拿几分、多花几倍，由你决定什么任务值得用。详见[方法与来源](METHODOLOGY.zh-CN.md)。

</details>

<details>
<summary><b>数据从哪来？多新？</b></summary>

能力分来自公开基准（如 Artificial Analysis），换算到统一口径；成本是按官方 API 价格完成一个参考编程任务的花费；耗时来自公开任务计时，缺失时估算并标注。套餐来自官方页面。每几小时生成并核验一次新发布，网站和每个客户端都会显示发布时间。

</details>

<details>
<summary><b>会上传我的任何信息吗？</b></summary>

不会。客户端匿名下载公开数据；Claude Code 和 Codex 的额度从本机文件读取，只在本机使用。没有账号，没有遥测。

</details>

<details>
<summary><b>会替我切换模型或档位吗？</b></summary>

从不。它只给建议，切换由你决定。只有出现新情况时，hooks 才会给 Agent 补一行提示。

</details>

<details>
<summary><b>覆盖哪些模型和套餐？</b></summary>

OpenAI、Anthropic、Google、xAI、智谱、Kimi、小米、MiniMax、Meta、阿里、DeepSeek、腾讯等厂商的现役编程模型及其 Coding 套餐。实时列表见 [modelplan.ai](https://modelplan.ai/?lang=zh) 和 [`/v1/client`](https://modelplan.ai/v1/client)。

</details>

<details>
<summary><b>我能在自己的工具或 Agent 里用这些数据吗？</b></summary>

可以：只读 API 免 key（[OpenAPI](https://modelplan.ai/openapi.json)），Agent 可以从 [llms.txt](https://modelplan.ai/llms.txt) 开始，优惠时段和重置日历可订阅 [ICS](https://modelplan.ai/calendar.ics)。

</details>

## 仓库结构

| | 目录 | 说明 |
| --- | --- | --- |
| **Model Plan Skill** | [`skills/model-plan/`](skills/model-plan/) | 主角，适用任何支持 Skill 的 Agent：选模型和档位、每升一档的倍数、按剩余额度和重置时间规划 |
| Claude Code 插件 | [`claude-code/`](claude-code/) | Skill、`/modelplan:*` 命令、状态栏，以及把新提示和任务开始简报只告诉 Claude 一次的 prompt hook |
| Codex 插件 | [`codex/`](codex/) | Skill 和 GPT 档位面板：⚡ Fast / Ultrafast 开关、你的 Codex 额度、官方重置公告 |
| `modelplan` 命令行 | [`cli/`](cli/) | 单个静态可执行文件：`lineup`、`effort`、`models`、`quota`、`advise`、`statusline`、`sync`、`doctor` |
| 方法与来源 | [`METHODOLOGY.zh-CN.md`](METHODOLOGY.zh-CN.md) | 能力、成本、耗时和 ★ 推荐档怎么算，以及数据源 |

## 参与贡献

发现价格、额度、档位或新闻有误？[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)；modelplan.ai 上的「报错」链接会自动填好页面和条目。欢迎提 bug、想法和 PR，见 [CONTRIBUTING.md](CONTRIBUTING.md)；版本记录见 [CHANGELOG.md](CHANGELOG.md)。

如果 Model Plan 帮你省了额度或钱，点个 ⭐ 能让更多人看到它。

[![Star History Chart](https://api.star-history.com/svg?repos=modelplan/modelplan&type=Date)](https://star-history.com/#modelplan/modelplan&Date)

## 许可

[MIT](LICENSE)。Model Plan 是独立项目，与任何模型厂商无关；厂商名称与商标归各自所有者。
