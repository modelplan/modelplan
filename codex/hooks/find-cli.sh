#!/bin/sh
# Prints the modelplan CLI the plugin uses. Hosts may run hooks with a short PATH (desktop apps
# and IDEs often lack ~/.local/bin), so after PATH it also looks where install.sh and Homebrew
# put it. Only executable files count; the first one at least as new as the plugin needs
# (../cli-min.txt, or $1) wins, else the first one found, so an older copy earlier on PATH does
# not hide a current one. The dashboard's findCli (quota.mjs) uses the same order and rules.
min=${1:-$(cat "$(dirname "$0")/../cli-min.txt" 2>/dev/null)}
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
first=
old_ifs=$IFS; IFS=:
set -- $PATH "${MODELPLAN_BIN:-$HOME/.local/bin}" /opt/homebrew/bin /usr/local/bin
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
