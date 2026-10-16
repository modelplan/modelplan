---
name: setup
description: Finish setting up the ModelPlan Codex plugin right after it is installed, or when the user asks how to turn on its proactive quota hints - check the optional modelplan CLI, offer to install it, and explain the hook trust step.
---

Codex runs this once after the plugin is installed. Keep it short and in the user's language. Install nothing without the user's yes.

1. Check for the optional CLI. Codex may run commands with a short PATH, so look in the usual places too:
   `command -v modelplan || ls ~/.local/bin/modelplan /opt/homebrew/bin/modelplan /usr/local/bin/modelplan 2>/dev/null`.
   If it is there, run `<path> version` and skip to step 3.
2. Without it, say in two sentences what it adds: proactive hints when a quota window will reset with allowance left (step up or turn on Fast), when it runs tight, after an announced Codex reset, and a reminder to switch back to ★ once the reset happened; the dashboard and the quota reading work without it. Ask whether to install it. Only on a yes, run
   `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh`
   (latest release for this OS and CPU, checked against the release checksums, into `~/.local/bin`; it changes no PATH or shell profile). On Windows, point to https://github.com/modelplan/modelplan/releases instead. The dashboard's "Install CLI" button does the same.
3. Hints reach the chat through the plugin's hooks, which Codex runs only after the user trusts them: in the CLI with `/hooks`, in the desktop app in its hooks review. Say this once; do not try to change hook trust or any setting yourself.
4. Offer to open the dashboard with `open_model_dashboard`. For a full check, the user can run `node "<plugin root>/doctor.cjs" --lang zh`.

Never switch the model, effort or Fast, and never use a reset credit; those stay the user's choice.
