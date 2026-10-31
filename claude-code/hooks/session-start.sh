#!/bin/sh
# SessionStart hook (matchers compact and resume): after Claude Code compacts or resumes a
# session, the model gets back the low or run-out quota notice that session was sent, while it
# still holds (`modelplan advise --hook claude-code`). Prints at most one JSON object. Never
# fetches, records nothing and changes no setting; silent with automatic hints off or without a
# CLI that handles SessionStart: at least the pin and session_cli (an older one would read the
# input as a prompt and mark its notices as sent; the pin moves only after a release).
if [ "$(cat "$HOME/.config/modelplan/claude-code/automatic-hints" 2>/dev/null)" = off ]; then
  cat >/dev/null 2>&1
  exit 0
fi
here=$(dirname "$0")
. "$here/setup-lib.sh"
input=$(cat)
cli=$(sh "$here/find-cli.sh" "$min_cli") || exit 0
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
session_cli=0.5.51
[ -n "$cliv" ] && at_least "$cliv" "$min_cli" && at_least "$cliv" "$session_cli" || exit 0
printf '%s' "$input" | "$cli" advise --hook claude-code 2>/dev/null
exit 0
