#!/bin/sh
# Persistent plugin preference; missing setting means on. No host settings change.
set -eu
setting="$HOME/.config/modelplan/claude-code/automatic-hints"
case "${1:-status}" in
  status)
    if [ "$(cat "$setting" 2>/dev/null || :)" = off ]; then echo 'automatic-hints: off'
    else echo 'automatic-hints: on'; fi ;;
  on|off)
    mkdir -p "$(dirname "$setting")"
    tmp=$(mktemp "$(dirname "$setting")/.automatic-hints-XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    printf '%s\n' "$1" > "$tmp"
    mv -f "$tmp" "$setting"
    printf 'automatic-hints: %s\n' "$1" ;;
  *) echo 'usage: automatic-hints.sh [status|on|off]' >&2; exit 2 ;;
esac
