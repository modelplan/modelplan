# Model Plan

**Which AI coding model should you use, at which effort, and is the next step up worth it?**
[Model Plan](https://modelplan.guanbear.com) answers that from verified public data: ability, cost per reference task and task time for every model and native effort, plus Coding Plan pricing, quota resets and usage windows.

English · [简体中文](README.zh-CN.md)

This repository holds Model Plan's open-source clients. The method behind the numbers will be published here as well.

| | Directory | What it is |
| --- | --- | --- |
| Codex plugin | [`codex/`](codex/) | GPT effort dashboard, capability/cost/time curves and public reset notices |
| Claude Code plugin | [`claude-code/`](claude-code/) | `/modelplan:lineup`, `/modelplan:effort`, a status line and the Model Plan Skill |
| Model Plan Skill | [`skills/model-plan/`](skills/model-plan/) | Works in any agent that supports Skills. Needs only a shell and anonymous HTTPS |
| `modelplan` CLI | [`cli/`](cli/) | Single static binary, read-only and anonymous. The plugin's commands and status line use it |

Every client reads only Model Plan's verified public publication. There is no account and no telemetry, and it never switches your model or effort for you.

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

All numbers and verdicts come from Model Plan's published data: ability, reference-task cost and time, the ★ recommended effort, and verdicts such as "strongest" and "best value". Clients never compute their own rankings. Methods and sources are on [modelplan.guanbear.com](https://modelplan.guanbear.com).

## License

[MIT](LICENSE)
