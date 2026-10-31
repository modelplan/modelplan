#!/bin/sh
# SessionStart hook (matchers compact and resume): after Codex compacts or resumes a thread, the
# model gets back the low or run-out quota notice that thread was sent, while it still holds
# (`modelplan advise --hook codex`). Prints at most one JSON object. Never fetches, records
# nothing and changes no setting; silent with automatic hints off or without a CLI that handles
# SessionStart: at least the pin and session_cli (an older one would read the input as a prompt
# and mark its notices as sent; the pin moves only after a release).
if [ "$(cat "$HOME/.config/modelplan/codex/automatic-hints" 2>/dev/null)" = off ]; then
  cat >/dev/null 2>&1
  exit 0
fi
here=$(dirname "$0")
min=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../cli-pin.json" 2>/dev/null | head -1)
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
input=$(cat)
cli=$(sh "$here/find-cli.sh" "$min") || exit 0
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
session_cli=0.5.51
[ -n "$cliv" ] && at_least "$cliv" "$min" && at_least "$cliv" "$session_cli" || exit 0
printf '%s' "$input" | "$cli" advise --hook codex 2>/dev/null
exit 0
