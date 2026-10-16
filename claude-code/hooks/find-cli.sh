#!/bin/sh
# Prints the modelplan CLI's path. Claude Code started from the desktop or an IDE may run hooks and
# commands with a short PATH, so also look where install.sh and Homebrew put it.
for c in "$(command -v modelplan 2>/dev/null)" "${MODELPLAN_BIN:-$HOME/.local/bin}/modelplan" /opt/homebrew/bin/modelplan /usr/local/bin/modelplan; do
  if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then printf '%s\n' "$c"; exit 0; fi
done
exit 1
