---
description: Optionally display the ModelPlan status line (live effort, fast mode, 5h/7d quota with reset countdown, and a hint when a cheaper model is as strong)
allowed-tools: Bash(sh:*), Read, Edit
---

Goal: optionally display the `modelplan` CLI's `statusline` in Claude Code, with the user's consent. In the current release this optional display also records the local snapshot used for Claude Code quota; automatic detection is coming. Without a snapshot Claude quota stays unknown, while public advice and other sources still work.

The CLI on this machine:

!`sh "${CLAUDE_PLUGIN_ROOT}/hooks/setup-status.sh" | grep -E '^(cli|statusline)'`

1. Unless the CLI line says `ok`, suggest `/modelplan:setup` (it shows why) and stop. Call the CLI `<cli>` below, written out in full because Claude Code may run the status line with a shorter PATH than this shell's: for the plugin's own copy use `~/.cache/modelplan-cli/modelplan` expanded to an absolute path (it always links the newest copy the plugin fetched, so plugin updates do not break the status line); for a CLI the user installed, its path as shown.
2. Preview it:

   ```sh
   echo '{"model":{"id":"claude-opus-5-5"},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":39,"resets_at":'$(( $(date +%s) + 2520 ))'},"seven_day":{"used_percentage":41,"resets_at":'$(( $(date +%s) + 273600 ))'}}}' | <cli> statusline --preview --no-color
   ```

   Show the user the line and explain it: model and effort (★ marks ModelPlan's recommended effort; off ★, the effort is warm above it and cool below it, with ★ in brackets), ability, the quota **left** per window as a bar (green 30% or more, amber from 10% or when the pace is tight, red below 10%) with the time to reset, `≈… 用完` / `out ~…` when the recent rate runs the window out within three hours, and the hint or an arrow: ↑ quota will reset unused (a step up is cheap), ↓ quota is tight. Under 100 columns the line is shorter: no ability, and the week as a percentage only.
3. Read `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR/settings.json`). If it already has a `statusLine`, show it and ask whether to replace it, or to keep it. If the user specifically wants legacy recording alongside their own display, `statusline --record-only` remains available. Never overwrite silently.
4. After the user agrees, set:

   ```json
   "statusLine": { "type": "command", "command": "<cli> statusline", "padding": 0 }
   ```

5. Tell the user: the optional display appears at once and reads the local cache without waiting on the network. Today it records the Claude Code quota snapshot when usage windows are passed to it. Automatic detection is coming; without a snapshot, that quota is unknown. Nothing is uploaded. Turning automatic hints off in `/modelplan:setup` does not disable this display.
