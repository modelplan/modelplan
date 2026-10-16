---
name: setup
description: Check and finish the ModelPlan Codex plugin's setup - after it is installed or upgraded, or whenever the user asks why ModelPlan quota hints or the task-start brief do not appear. Reports each part (plugin, its own CLI, hook, hints) on its own and says what to do about what is not ready.
---

Codex may run this after the plugin is installed; the user can also ask for it at any time ("check ModelPlan setup"). A user's question always gets a full answer, whatever the automatic notices did before. Keep it short and in the user's language.

1. Check, and report each part on its own line:
   - **Plugin**: answering if `get_model_dashboard` works; its `structuredContent.setup` has the rest.
   - **CLI** (`setup.cli.status`): the plugin brings its own, the release pinned in `cli-pin.json`, fetched in the background into `~/.cache/modelplan-cli` and used only if its SHA-256 matches the pinned one. `ok` (`source` plugin, or user for one the user installed), `fetching`, `failed` (with `fetchError` or `error`), `outdated` (the user's own older copy while the plugin's is missing), `missing` (`MODELPLAN_PLUGIN_CLI=off` and none installed) or `unsupported` (Windows). Without the tool: `sh "<plugin root>/hooks/find-cli.sh"`, then `<path> version`.
   - **Hook**: `setup.hook.lastRun` empty means Codex has not run it yet, normally because it is not trusted.
   - **Hints**: on when the CLI is `ok` (or `outdated`) and the hook's last run computed them.
   Never call a part done because a command was run; only what the check shows.
2. CLI not ready: nothing to install or agree to; installing or updating the plugin is enough. `fetching`: it lands within a minute or so, hints start with the next message after that. `failed`: say why; the dashboard's **Retry** fetches again, or run `sh "<plugin root>/hooks/fetch-cli.sh"`, which prints the error if it fails (`download failed`: network, proxy or GitHub; `checksum mismatch`: nothing was installed, retry later and report it if it persists). `unsupported`: point to https://github.com/modelplan/modelplan/releases for a `modelplan` on PATH.
3. Hook not run (`setup.hook.lastRun` empty), its definition changed (`setup.hook.current` false), or its last run failed (`setup.hook.result` starts with `failed`, with the exit code and error; `lastSuccess` is the last good run). These records are this machine's, from any chat; plugins cannot see trust, so never say the hook is trusted, only when it last ran and how. Codex runs plugin hooks only after the user allows them. The review lists it as "UserPromptSubmit · Hook 1", source `Plugin - modelplan-codex@modelplan`, command `sh "$PLUGIN_ROOT/hooks/modelplan-quota-hints.sh"`, timeout 5 s. It reads the local quota and the cached publication and only adds context; it downloads and changes nothing (the plugin's server fetches the CLI). To allow it: in the desktop app, the hook icon with a yellow dot next to the input, source `modelplan-codex`; in the CLI, `/hooks`. It starts with the next message, and a changed definition needs allowing again. Hints arrive with a prompt only, not during a long turn. Do not change hook trust yourself.
4. Offer the dashboard (`open_model_dashboard`); it shows the same setup lines. For a full check: `node "<plugin root>/doctor.cjs" --lang zh`.

Never switch the model, effort or Fast, and never redeem a reset credit; those stay the user's.
