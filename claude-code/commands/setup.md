---
description: Check the Model Plan plugin's setup (CLI, status line, hook) part by part and finish what is missing, with your consent
allowed-tools: Bash(sh:*)
---

Setup as it is on this machine now:

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/setup-status.sh"`

Report each part above on its own short line in the user's language (plugin, CLI, status line, hook, hints). Never call a part done because a command ran; only what a check shows. Then, for what is not ready:

1. **CLI missing or outdated**: say in one sentence what it adds (quota hints before and after resets, a model and effort suggestion at the start of each session) and ask. Only on a yes, run
   `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh`
   (latest release for this OS and CPU, checked against the release checksums, into `~/.local/bin`; no PATH, profile or sudo changes; on Windows point to https://github.com/modelplan/modelplan/releases). Then run `~/.local/bin/modelplan sync` once (it fetches the published data; the hook would otherwise start that in the background on the next message) and `sh "${CLAUDE_PLUGIN_ROOT}/hooks/setup-status.sh"` again, and report the version it finds. If an older copy is still found first, say where.
   CLI failed: show the error and suggest reinstalling with the same command.
2. **Status line not set up**: it records the 5-hour and weekly usage Claude Code passes to it (Pro/Max), which the quota hints need. Suggest `/modelplan:statusline` (it previews the line and asks before changing settings).
3. **Hook has not run**: it runs on every message (`UserPromptSubmit`, `sh "${CLAUDE_PLUGIN_ROOT}/hooks/modelplan-quota-hints.sh"`, 5 s). It reads the local quota and the cached publication and only adds context; it installs and changes nothing. If it still has not run after a message, hooks are off (`disableAllHooks` or a managed policy) or the plugin is disabled (`/plugin`).
4. The user says not now: `mkdir -p ~/.cache/modelplan-claude-code && touch ~/.cache/modelplan-claude-code/cli-declined` (or `statusline-declined`); the hook then stays quiet about it for 90 days.

When everything is ready, say so in one line. Never switch the model, effort or fast mode; those stay the user's.
