#!/bin/sh
# PreToolUse hook (the Agent and Workflow tools): when the main session spawns subagents while its quota
# is low, the user sees one line and the model the same facts, plus a cheaper model as strong when
# the spawn names none (`modelplan advise --hook claude-code`). Notices share the prompt's 20/10/5%
# marks, at most three per session; a subagent's own spawns say nothing. Reads cached readings
# only: never fetches, never blocks or changes the call. Silent with automatic hints off or
# without a CLI that handles PreToolUse: at least the pin and spend_cli (an older one would read
# the input as a prompt and mark its notices as sent).
if [ "$(cat "$HOME/.config/modelplan/claude-code/automatic-hints" 2>/dev/null)" = off ]; then
  cat >/dev/null 2>&1
  exit 0
fi
here=$(dirname "$0")
. "$here/setup-lib.sh"
input=$(cat)
spend_cli=0.5.56
# Look for the higher of the two, so an old pinned copy does not hide a newer installed CLI.
want=$spend_cli
at_least "$min_cli" "$spend_cli" && want=$min_cli
cli=$(sh "$here/find-cli.sh" "$want") || exit 0
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
[ -n "$cliv" ] && at_least "$cliv" "$min_cli" && at_least "$cliv" "$spend_cli" || exit 0
printf '%s' "$input" | "$cli" advise --hook claude-code 2>/dev/null
exit 0
