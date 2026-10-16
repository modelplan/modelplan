---
name: setup
description: Check and finish the ModelPlan Codex plugin's setup - after it is installed or upgraded, or whenever the user asks why ModelPlan quota hints or the task-start brief do not appear. Reports each part (plugin, optional CLI, hook trust, hints) on its own, offers the CLI with consent, and re-checks.
---

Codex may run this after the plugin is installed; the user can also ask for it at any time ("check ModelPlan setup"). A user's question always gets a full answer, whatever the automatic notices did before. Keep it short and in the user's language.

1. Check, and report each part on its own line:
   - **Plugin**: answering if `get_model_dashboard` works; its `structuredContent.setup` has the rest.
   - **CLI** (`setup.cli.status`): `ok` (version), `missing`, `outdated` (older than `setup.cli.min`), or `failed` (with `error`). Without the tool: `sh "<plugin root>/hooks/find-cli.sh"`, then `<path> version`.
   - **Hook**: `setup.hook.lastRun` empty means Codex has not run it yet, normally because it is not trusted.
   - **Hints**: on only when the CLI is `ok` (or `outdated`) and the hook has run.
   Never call a part done because a command was run; only what the check shows.
2. CLI missing or outdated: say in one sentence what it adds (quota hints before and after resets, a model and effort suggestion at the start of a task, the Codex account reading with reset credits) and ask. Only on a yes, run
   `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh`
   (latest release for this OS and CPU, checked against the release checksums, into `~/.local/bin`; no PATH, profile or sudo changes; on Windows point to https://github.com/modelplan/modelplan/releases). Then check again (`~/.local/bin/modelplan version`, or the tool) and report the version actually found. If an older copy elsewhere is still found first, say where. The dashboard's Install/Upgrade CLI button does the same.
   If the user says not now: `mkdir -p ~/.cache/modelplan-codex && touch ~/.cache/modelplan-codex/cli-declined` (the hook then stays quiet for 90 days; the dashboard's "Not now" does the same).
3. Hook not run: Codex runs plugin hooks only after the user trusts them. The review lists it as "UserPromptSubmit · Hook 1", source `Plugin - modelplan-codex@modelplan`, command `sh "$PLUGIN_ROOT/hooks/modelplan-quota-hints.sh"`, timeout 5 s. It reads the local quota and the cached publication and only adds context; it installs and changes nothing. Trust it with `/hooks` in the CLI or in the desktop app's hook review; it starts with the next message. A changed hook needs trusting again after a plugin update. Do not change hook trust yourself.
4. Offer the dashboard (`open_model_dashboard`); it shows the same setup lines. For a full check: `node "<plugin root>/doctor.cjs" --lang zh`.

Never switch the model, effort or Fast, and never redeem a reset credit; those stay the user's.
