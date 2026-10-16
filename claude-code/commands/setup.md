---
description: Check the Model Plan plugin's setup (its CLI, status line, hook) part by part and finish what is missing
allowed-tools: Bash(sh:*)
---

Setup as it is on this machine now:

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/setup-status.sh"`

Report each part above on its own short line in the user's language (plugin, CLI, status line, hook, hints). Never call a part done because a command ran; only what a check shows. Then, for what is not ready:

1. **CLI**: the plugin brings its own: the release pinned in the plugin, downloaded in the background after a message and used only if its SHA-256 matches the one in the plugin; it lives in `~/.cache/modelplan-cli` and changes nothing else. Nothing to install or upgrade by hand. If the check says the fetch failed, show why and retry with `sh "${CLAUDE_PLUGIN_ROOT}/hooks/fetch-cli.sh"` (it prints the error again if it fails): `download failed` means network, proxy or GitHub; `checksum mismatch` means nothing was installed (retry later, report it if it persists); `unsupported` systems (Windows) need a CLI from https://github.com/modelplan/modelplan/releases on PATH. `MODELPLAN_PLUGIN_CLI=off` turns fetching off; then a CLI the user installed is used. A CLI the user installed elsewhere is left alone.
2. **Status line not set up**: it records the 5-hour and weekly usage Claude Code passes to it (Pro/Max), which the quota hints need. Suggest `/modelplan:statusline` (it previews the line and asks before changing settings).
3. **Hook**: these records are this machine's, from whichever session ran last. `result: failed …` means the hook ran but the CLI could not compute hints (the exit code and error say why; `hook-last-success` is the last good run); the message itself was not blocked and the next one retries. `hints: not verified yet` means no run has computed them since setup. **Has not run**: it runs on every message (`UserPromptSubmit`, `sh "${CLAUDE_PLUGIN_ROOT}/hooks/modelplan-quota-hints.sh"`, 5 s). It reads the local quota and the cached publication and only adds context; it changes no setting, and the only thing it fetches is the plugin's pinned CLI (step 1). If it still has not run after a message, hooks are off (`disableAllHooks` or a managed policy) or the plugin is disabled (`/plugin`).
4. The user says not now to the status line: run `sh "${CLAUDE_PLUGIN_ROOT}/hooks/decline.sh" statusline`; the hook then stays quiet about it for 90 days.

When everything is ready, say so in one line. Never switch the model, effort or fast mode; those stay the user's.
