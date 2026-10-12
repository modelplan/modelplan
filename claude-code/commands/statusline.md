---
description: Install the Model Plan status line (shows ★ effort, cost vs the cheapest sibling, and a hint when a cheaper model is as strong)
allowed-tools: Bash(modelplan:*), Bash(command -v modelplan), Read, Edit
---

Goal: set Claude Code's status line to `modelplan statusline`, with the user's consent.

1. Run `command -v modelplan`. If it is missing, show the install steps from the plugin README and stop.
2. Run `echo '{"model":{"id":"claude-opus-5-5"}}' | modelplan statusline --no-color` and show the user the preview line.
3. Read `~/.claude/settings.json`. If it already has a `statusLine`, show it and ask whether to replace it. Never overwrite it silently.
4. After the user agrees, set:

   ```json
   "statusLine": { "type": "command", "command": "modelplan statusline", "padding": 0 }
   ```

5. Tell the user the status line reads only the local cache. The session hook refreshes it in the background, and `modelplan sync` refreshes it on demand.
