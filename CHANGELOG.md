# Changelog

Releases of the `modelplan` CLI and the plugins in this repository. Binaries are on [Releases](https://github.com/modelplan/modelplan/releases). The website and data change continuously; see [modelplan.ai/updates](https://modelplan.ai/updates).

## Codex plugin 0.9.0 (unreleased)

- **Compact inline dashboard:** opens inline (was fullscreen) at a 360–420 px target with content height and no inner scroll areas. The first screen shows the thread's model, effort and speed tier, its step against ★ and the quota. Model chips select the comparison. Curves, the full lineup and reset notices are folded; Expand opens them.
- **Speed tiers are consistent and honest:** the readout, mini curve and detail curve share one comparison state. Under Fast or Ultrafast, cost becomes an estimated plan-quota multiple vs ★ standard and task time is unknown, never shown as ×1.00 or divided by the generation speed-up. Generation speed is shown as an "up to" ceiling or as not stated, with credit multiples, eligibility, the official source and its review date.

## Unreleased: CLI v0.5.0, Codex plugin 0.8.1

- **Codex quota and the current thread are separate.** Account windows are merged across recent Codex threads, newest reading per limit id and window, each with its own `observedAt` and age; a window absent from the newest log is no longer dropped. Model and effort come from one thread: the calling one when `CODEX_THREAD_ID` (or a hook's `session_id`) names it, marked `attribution: "current-thread"`, else the newest interactive thread, marked `recent-thread`. Background threads (`subagent:*`, `internal:*`, `codex-auto-review`) never supply them. The harness also reports `observedAt`, `origin`, `serviceTier`, and the effort from `collaboration_mode` when the turn context has no top-level one. Go and Python read one shared multi-thread fixture.
- Codex plugin: the MCP server is never told which thread called it, so its reading is labelled "latest local thread, may not be this conversation" with its age; readings from older CLIs that carry `codex-auto-review` are dropped. Windows older than an hour show their age; five-hour or weekly windows not seen are listed as such.

## Codex plugin 0.8.0 (2026-10-16)

- **Runtime discovery:** Codex now starts `launch.cjs`, which runs the server on the first Node.js 22+ that passes a feature check: a pin in `~/.config/modelplan/runtime.json`, the Node Codex used, Codex desktop's own runtime when present, other PATH entries, standard locations and version managers. Re-checked at every start; PATH and global Node are never changed. With no usable runtime both tools still register and return the diagnosis. The minimum is Node.js 22 (was 24); CI runs 22 and 24.
- **Setup check:** `node doctor.cjs` starts the installed plugin through Codex's app-server without a turn and reports Codex support, install state, the runtime Codex actually used, MCP tools, the dashboard resource, public data, quota reader and hints, ending with separate *installed* / *tools callable* / *panel shown (unverified)* verdicts.
- **Install:** `--sparse .agents --sparse codex` checks out about 2 MB instead of the whole repository; README covers each step, retries, update and uninstall, and required versus optional components.
- Quota and hint results name their reader and why hints are off (`cli_missing`, `cli_without_advise`); the text output and dashboard show it.
- Fixed `tests/mcp-smoke.mjs`, which compared the effort text without the speed-tier lines.

## v0.4.1 (2026-10-15)

- `modelplan advise`: one switch-back hint per window, even when it was advised more than once (#10).

## v0.4.0 (2026-10-15)

- **Proactive advisor:** `modelplan advise [--json] [--source] [--hook claude-code|codex]` with events for a window about to reset with allowance left, tight or used-up windows, switching back to ★ after a reset, peak and off-peak starting soon, reset cards expiring and public Codex resets. Each hint is given once (#9).
- **Hooks:** UserPromptSubmit hooks for Claude Code and Codex pass new hints to the agent once.
- **Status line hints:** `↑High ×1.37`, `↓★Med ×0.73`, `↺★Med`.
- **Speed tiers:** ⚡ Fast and ⚡⚡ Ultrafast lines in `modelplan effort`; the Codex dashboard gets a Standard / Fast / Ultrafast switch; the Skill reads them. The CLI accepts any `client-v1.x` projection.
- Skill: Claude Code fast mode bills usage credits, not plan quota (#8).
- Plugins: Claude Code 0.4.0, Codex 0.7.0.

## v0.3.0 (2026-10-15)

- Quota-aware Skill, status line and Codex dashboard: Claude Code and Codex 5-hour and weekly windows read locally (#7).
- Codex effort dashboard and install instructions (#1); clients point at modelplan.ai (#2); methodology and sources published (#3); data-problem issue form (#4).
- CLI accepts the ten-component compact publication (#6).

## v0.2.1 and v0.2.0 (2026-10-12)

- First releases of the `modelplan` CLI: `lineup`, `effort`, `models`, `statusline`, `sync`, `doctor`.
