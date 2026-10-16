#!/bin/sh
# Prints the modelplan CLI's path. Codex runs hooks with a short PATH (the desktop app's often lacks
# ~/.local/bin), so also look where install.sh and Homebrew put it. Same order as quota.mjs findCli.
for c in "$(command -v modelplan 2>/dev/null)" "${MODELPLAN_BIN:-$HOME/.local/bin}/modelplan" /opt/homebrew/bin/modelplan /usr/local/bin/modelplan; do
  if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then printf '%s\n' "$c"; exit 0; fi
done
exit 1
