# Model Plan

**Which AI coding model should you use, at which effort, and is the next step up worth it?**
[Model Plan](https://modelplan.ai) answers that from verified public data: ability, cost per reference task and task time for every model and native effort, plus Coding Plan pricing, quota resets and usage windows.

English · [简体中文](README.zh-CN.md)

## Why Model Plan

- **★ Effort recommendation.** Within one model, Low to Max changes not just the score but cost and time, often by several times. Every model gets its best-value ★ effort, and you see what one more step up buys and costs.
- **A leaderboard at the recommended effort.** Most leaderboards compare each model's top setting. Model Plan ranks every model at its own ★ effort, the setup you would actually run. A 3D launch field and the Which Engine chart show ability, cost and time together.
- **Plan recommendations** *(in progress).* Coding plans are compared by maker, model and price band: price, quota and which models and efforts each plan covers. Off-peak hours and quota resets are on a week calendar. Exact plan-model-effort coverage is still being completed.
- **Plans around your own quota.** Reads your Claude Code and Codex 5-hour / weekly usage and reset times on your machine (never uploaded). With plenty left just before a reset it says stepping up or fast mode is cheap; when a window is tight it says stay at ★ or step down.
- **In your tools.** The same answers are inside Claude Code, Codex and the terminal through this repository's plugins, Skill and CLI.

This repository holds Model Plan's open-source clients and the [methodology](METHODOLOGY.md): how ability, cost, time and the ★ recommended effort are worked out, and the sources behind them.

| | Directory | What it is |
| --- | --- | --- |
| **Model Plan Skill** | [`skills/model-plan/`](skills/model-plan/) | The main client. Works in Claude Code, Codex and any agent that supports Skills: model and effort choice, the multiplier for each step up, planning around your remaining quota and reset times. Needs only a shell and anonymous HTTPS |
| Claude Code plugin | [`claude-code/`](claude-code/) | The Skill plus `/modelplan:plan`, `/modelplan:effort`, `/modelplan:lineup` and a status line with live effort and 5h/7d quota |
| Codex plugin | [`codex/`](codex/) | The Skill plus a GPT effort dashboard: capability/cost/time curves, your Codex quota and reset countdown, public reset notices |
| `modelplan` CLI | [`cli/`](cli/) | Single static binary, read-only and anonymous. `modelplan quota` gathers local quota; the status line and plugin commands use it |

Every client reads only Model Plan's verified public publication, plus quota files the harnesses already write on your machine. There is no account and no telemetry, nothing personal is uploaded, and it never switches your model or effort for you.

## Codex plugin

GPT effort recommendations, capability/cost/time curves and public reset notices, with a desktop panel and CLI text fallback. Requires Node.js 24+.

```sh
codex plugin marketplace add modelplan/modelplan
codex plugin add modelplan-codex@modelplan
```

[Installation and usage](codex/README.md)

## Install

**1. The `modelplan` CLI** (macOS / Linux)

```sh
curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh
modelplan sync
modelplan lineup --dev anthropic
```

On Windows, or to install by hand, download your platform's archive from [Releases](https://github.com/modelplan/modelplan/releases) and put `modelplan` on your `PATH`. With Go: `go install github.com/modelplan/modelplan/cli/cmd/modelplan@latest`.

**2. Claude Code plugin**

```text
/plugin marketplace add modelplan/modelplan
/plugin install modelplan@modelplan
```

Optionally, run `/modelplan:statusline` to add the status line after you confirm.

**3. Skill only:** copy [`skills/model-plan`](skills/model-plan/) into `~/.claude/skills/model-plan` (or your agent's skills directory). Without the CLI it reads the public API directly.

## Example

```text
$ modelplan lineup --dev anthropic --lang en
WHICH ENGINE Which engine · Anthropic · every model at its ★ recommended effort · cost relative to Haiku 5.5 = ×1
  Haiku 5.5 → Sonnet 5.5      ability +8.3  cost ×3.1
  Sonnet 5.5 → Opus 5.5       ability +8.5  cost ×1.9
  Skip: Opus 5, Fable 5.1 (costs more, not stronger)
```

```text
▲ Opus 5.5 ★Med │ ability 55.4 │ cost ×6.0 vs Haiku 5.5 │ strongest best value
```

## Data

All numbers and verdicts come from Model Plan's published data: ability, reference-task cost and time, the ★ recommended effort, and verdicts such as "strongest" and "best value". Clients never compute their own rankings. Methods and sources: [METHODOLOGY.md](METHODOLOGY.md) and [modelplan.ai/methodology](https://modelplan.ai/methodology).

See a wrong price, quota, effort or news item? [Report a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml). The **Report** links on modelplan.ai fill in the page and item for you.

## License

[MIT](LICENSE)
