# Changelog

Releases of the `modelplan` CLI and the plugins in this repository. Binaries are on [Releases](https://github.com/modelplan/modelplan/releases). The website and data change continuously; see [modelplan.ai/updates](https://modelplan.ai/updates).

## v0.5.6 (2026-10-16)

- Plugins: Claude Code 0.5.0.
- **Task-start brief for Claude Code.** `advise --hook claude-code` now also hands the model the brief on the first prompt of each session (Anthropic models at ★, the default configuration, the current model's ladder, the quota headroom), as for Codex. The current model and effort come from the status line's reading only when it was this session's: the snapshot keeps a one-way `sessionKey` (a hash, never the id), and `quota` marks the Claude Code harness `current-thread` or `recent-thread` from the hook's `session_id` or `CLAUDE_CODE_SESSION_ID`. Without it the brief says "model unknown".
- The hook refreshes the published data in the background when it is older than 6 hours (before, only the status line did), and takes a plugin's setup notice (`--add-system`, `--add-context`) so one JSON object comes out.
- `statusline --preview` renders a sample without recording it; the plugin's preview used to write its sample windows into the real snapshot.

## Claude Code plugin 0.5.0 (2026-10-16)

- **One hook,** `UserPromptSubmit` → `hooks/modelplan-quota-hints.sh`; `SessionStart` is gone (the CLI refreshes data itself). It finds the CLI off PATH (`~/.local/bin`, Homebrew), records a heartbeat with the plugin version, and shows a setup notice when the CLI is missing or older than 0.5.6, or the status line has never recorded: the first notice asks Claude to offer the fix once (a "no" is recorded), later ones at most weekly without asking, none for 90 days after "not now". A current CLI with a recording status line gets hints and the brief only. Verified in Claude Code 2.1.301 (plugin hooks run without a separate review there).
- **`/modelplan:setup`** reports plugin, CLI (missing, outdated, failed, ok, and whether it is on PATH), status line (recording, set but no reading, not set), hook (last run, plugin version) and hints, each on its own line, then installs the CLI with consent, syncs and re-checks.
- `/modelplan:plan`, `/modelplan:effort`, `/modelplan:lineup` and `/modelplan:statusline` reach the CLI through the plugin, so they work when it is not on PATH; the status line is configured with the CLI's full path.
- Tests for the hooks and commands run in CI on Ubuntu and macOS.

## v0.5.5 (2026-10-16)

- Plugins: Codex 0.13.0.
- The task-start brief no longer needs a quota reading: without one (a first thread, an API-key login) it still lists the options and the default, with quota "unknown". It takes the thread's model from the hook input; when the thread's effort is not in its log, it says so and shows the ladder against ★ instead of assuming ★.

## Codex plugin 0.13.0 (2026-10-16)

- **One hook, named by its command.** `SessionStart` is gone; `UserPromptSubmit` runs `hooks/modelplan-quota-hints.sh` (status message "ModelPlan: quota hints and task-start brief"). Codex 0.157's review shows plugin hooks as "Hook 1"; `statusMessage` does not change that, so the script name, the README and the `setup` skill explain it.
- **Setup notice on the prompt, not the session start,** so it also works after an upgrade inside an open chat and after the hook is trusted mid-session (both verified in the Codex TUI). Missing or outdated CLI: the first notice asks the model to offer it once (on a no it records `cli-declined`); later notices at most weekly, without asking; none for 90 days after "not now". Asking about setup is never limited. With a current CLI only hints and the brief.
- **Setup on the dashboard, part by part:** CLI missing (Install / Not now), outdated (Upgrade), failing (with the error); hook never ran, or an update's hook has not run (Codex skips a changed hook until trusted again; the hook records its plugin version); one "setup complete" line otherwise. The text output says the same. Install and upgrade succeed only when the CLI the plugin will use reports at least 0.5.5; an older copy found first is named.
- `setup` skill rewritten: report each part from the check, never from a command having run; offer, install, re-check; record "not now"; explain hook trust and re-trust after updates. `doctor.cjs` shows when the hook last ran. App-only tool `dismiss_cli_setup` for "not now".

## v0.5.4 (2026-10-16)

- Task-start brief names a **default for ordinary tasks**: the published best value at ★, unless it scores more than 3 points below the strongest, then the strongest at ★ (today GPT-6.1 Sol ★Med, both). It lists the default model's ladder when the thread is on another model, and tells the model to suggest a step down for small tasks, High/XHigh of the default for complex ones and the default again afterwards.

## v0.5.3 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Task-start brief for Codex.** On the first prompt of a Codex thread, `advise --hook codex` also hands the model a short brief: the Codex models at ★ with ability, cost relative to the cheapest and lineup verdicts (dominated ones marked skip), the current model's effort ladder against the current effort, the quota headroom and, with a surplus, Fast when it draws plan quota. The model judges the task and suggests one configuration only when the current one clearly does not fit; the brief says it never changes settings. Once per thread (by the hook's `session_id`); `MODELPLAN_TASK_BRIEF=off` disables it.

## v0.5.2 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Codex account reading.** `modelplan quota`, `advise` and the Codex hook ask Codex itself for the account's windows and reset credits: `codex app-server` → `account/rateLimits/read`, in the background at most every 5 minutes (30 after a failure such as no login), with Codex's own login; `quota --refresh-account` asks now. The answer is cached in `observed/codex-account.json` without account or credit ids and merged with the session-log windows, newest observation per window, so a 5-hour window missing from recent logs is filled in. Available credits become `cards` of kind `full` with their expiry, which feed `cards_expiring` and `use_card`. The reading is marked `via: "codex-account"`. Nothing is redeemed. `MODELPLAN_CODEX_ACCOUNT=off` disables it.

## Codex plugin 0.12.0 (2026-10-16)

- The dashboard and the text output show full-reset credits (count, first expiry, redeem in Codex yourself) and name a Codex account reading as the source.

## v0.5.1 (2026-10-16)

- Plugins: Codex 0.11.0.
- `modelplan advise`: **spend ahead of an announced Codex reset.** When OpenAI has announced a reset with a time in the next 24 hours and the longer Codex window still has 20% or more that would otherwise last past it, `announced_reset_with_surplus` suggests the next effort, a stronger model or Fast, worded as applying only if the reset covers the account. The switch-back hint after it waits for a reading taken after the announced time that shows the window restarted, and is kept for up to six hours for that proof. An announcement whose time has passed is no longer shown as news.

## Codex plugin 0.11.0 (2026-10-16)

- **The hooks now load.** The manifest moved to Codex's native `.codex-plugin/plugin.json`. The old root `plugin.json` carried the Agent Plugins `$schema`, and Codex then skipped the plugin's hooks, so the `UserPromptSubmit` hint hook never ran. `codex app-server` `hooks/list` now shows both hooks; `doctor.cjs` reports whether they are loaded and trusted.
- **Getting the CLI:** an **Install CLI** button on the dashboard (macOS, Linux; app-only tool `install_modelplan_cli`, the click is the consent) runs the bundled copy of `install.sh`: latest release, checksum-checked, into `~/.local/bin`, nothing else changed. A `setup` onboarding skill checks for the CLI after install and offers it. A `SessionStart` hook shows a short notice with the install command when the CLI is missing, at most once a week.
- The server, hooks and doctor find the CLI in `~/.local/bin`, `$MODELPLAN_BIN` and Homebrew's directories as well as PATH, since Codex starts them with a short PATH.

## Codex plugin 0.10.0 (2026-10-16)

- **Panel beside the chat:** a separate `Effort & quota` thread entry (tool `open_model_panel`) opens the dashboard in the conversation's side panel; the sidebar board is its own `Model Plan` global entry. OpenAI's extension spec allows one entrypoint per tool; 0.9 declared both on `open_model_dashboard`. Each surface has its own UI resource, so the model's call still shows the inline card and a tool call never claims to open the side panel. The inline card says how to open the panel instead.
- **Width no longer follows the display mode:** hosts show every entrypoint `fullscreen`, which widened 0.9 to 640 px inside the side panel. The content is at most 420 px everywhere (borders and padding included). The inline card reports its own width to the host (`ui/notifications/size-changed`, within `containerDimensions.maxWidth`) and leaves the chat column around it unpainted. Expand appears only on the inline card.
- **Diagnosable size:** *Data & basis* shows what the host reported (surface, display mode, container dimensions) and the laid-out viewport and panel widths. `doctor.cjs` reports whether the side panel entry is registered.

## Codex plugin 0.9.0 (2026-10-16)

- **Compact inline dashboard:** opens inline (was fullscreen) at a 360–420 px target with content height and no inner scroll areas. The first screen shows the thread's model, effort and speed tier, its step against ★ and the quota. Model chips select the comparison. Curves, the full lineup and reset notices are folded; Expand opens them.
- **Speed tiers are consistent and honest:** the readout, mini curve and detail curve share one comparison state. Under Fast or Ultrafast, cost becomes an estimated plan-quota multiple vs ★ standard and task time is unknown, never shown as ×1.00 or divided by the generation speed-up. Generation speed is shown as an "up to" ceiling or as not stated, with credit multiples, eligibility, the official source and its review date.

## v0.5.0 (2026-10-16)

- Plugins: Codex 0.8.1.
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
