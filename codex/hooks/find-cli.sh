#!/bin/sh
# Prints the modelplan CLI the plugin uses. First the copy the plugin fetched for its pinned
# release (fetch-cli.sh, ~/.cache/modelplan-cli/<version>); else one the user installed (PATH,
# then where install.sh puts it), the plugin's previous copy (~/.cache/modelplan-cli/modelplan,
# while an update's copy downloads) or Homebrew's (hosts may run hooks with a short PATH). Only
# executable files count; the first one at least the pinned version wins, else the first one
# found. The dashboard's findCli (codex/quota.mjs) uses the same order and rules. Shared,
# identical, by the Claude Code and Codex plugins.
pin="$(dirname "$0")/../cli-pin.json"
min=${1:-$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$pin" 2>/dev/null | head -1)}
if [ -n "$min" ] && [ -x "$HOME/.cache/modelplan-cli/$min/modelplan" ]; then printf '%s\n' "$HOME/.cache/modelplan-cli/$min/modelplan"; exit 0; fi
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
first=
old_ifs=$IFS; IFS=:
set -- $PATH "${MODELPLAN_BIN:-$HOME/.local/bin}" "$HOME/.cache/modelplan-cli" /opt/homebrew/bin /usr/local/bin
IFS=$old_ifs
for d in "$@"; do
  c="$d/modelplan"
  [ -n "$d" ] && [ -f "$c" ] && [ -x "$c" ] || continue
  [ -z "$first" ] && first=$c
  [ -z "$min" ] && break
  v=$("$c" version </dev/null 2>/dev/null | awk 'NR == 1 {print $2}')
  if [ -n "$v" ] && at_least "$v" "$min"; then printf '%s\n' "$c"; exit 0; fi
done
[ -n "$first" ] && printf '%s\n' "$first" && exit 0
exit 1
