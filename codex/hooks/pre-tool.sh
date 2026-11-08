#!/bin/sh
# PreToolUse hook (the spawn_agent tool): when the main thread spawns subagents while its quota
# is low, the user sees one line and the model the same facts, plus a cheaper model as strong when
# the spawn names none (`modelplan advise --hook codex`). Notices share the prompt's 20/10/5%
# marks, at most three per thread; a subagent's own spawns say nothing. Reads cached readings
# only: never fetches, never blocks or changes the call. Silent with automatic hints off or
# without a CLI that handles PreToolUse: at least the pin and spend_cli (an older one would read
# the input as a prompt and mark its notices as sent).
if [ "$(cat "$HOME/.config/modelplan/codex/automatic-hints" 2>/dev/null)" = off ]; then
  cat >/dev/null 2>&1
  exit 0
fi
here=$(dirname "$0")
min=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../cli-pin.json" 2>/dev/null | head -1)
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
input=$(cat)
spend_cli=0.5.56
# Look for the higher of the two, so an old pinned copy does not hide a newer installed CLI.
want=$spend_cli
at_least "$min" "$spend_cli" && want=$min
cli=$(sh "$here/find-cli.sh" "$want") || exit 0
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
[ -n "$cliv" ] && at_least "$cliv" "$min" && at_least "$cliv" "$spend_cli" || exit 0
printf '%s' "$input" | "$cli" advise --hook codex 2>/dev/null
exit 0
