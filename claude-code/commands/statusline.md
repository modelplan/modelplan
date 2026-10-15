---
description: Install the Model Plan status line (live effort, fast mode, 5h/7d quota with reset countdown, and a hint when a cheaper model is as strong)
allowed-tools: Bash(modelplan:*), Bash(command -v modelplan), Read, Edit
---

Goal: set Claude Code's status line to `modelplan statusline`, with the user's consent.

1. Run `command -v modelplan`. If it is missing, show the install steps from the plugin README and stop.
2. Preview it:

   ```sh
   echo '{"model":{"id":"claude-opus-5-5"},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":39,"resets_at":'$(( $(date +%s) + 2520 ))'},"seven_day":{"used_percentage":41,"resets_at":'$(( $(date +%s) + 273600 ))'}}}' | modelplan statusline --no-color
   ```

   Show the user the line and explain it: model and effort (★ marks Model Plan's recommended effort), ability, quota used per window with the time to reset, and an arrow: ↑ quota will reset unused (a step up is cheap), ↓ quota is tight.
3. Read `~/.claude/settings.json`. If it already has a `statusLine`, show it and ask whether to replace it, or to keep it and only record quota by adding this at the top of their script: `input=$(cat); printf %s "$input" | modelplan statusline --record-only` (then use `$input` instead of stdin). Never overwrite silently.
4. After the user agrees, set:

   ```json
   "statusLine": { "type": "command", "command": "modelplan statusline", "padding": 0 }
   ```

5. Tell the user: the status line reads only the local cache and never waits on the network. It records the usage windows Claude Code passes to it (Pro/Max plans) in the Model Plan cache on this machine, so `/modelplan:plan` and the model-plan Skill can plan around them. Nothing is uploaded.
