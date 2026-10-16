#!/bin/sh
# /modelplan:setup's check: each part on its own line, from what is on disk now. Reads only; the
# CLI is asked for its version and nothing else.
here=$(dirname "$0")
. "$here/setup-lib.sh"
ago() { # minutes since a file changed
  t=$(date -r "$1" +%s 2>/dev/null) || return 1
  echo $(( ($(date +%s) - t) / 60 ))
}
echo "plugin: modelplan $(plugin_version) (answering: this check ran)"
cli=$(sh "$here/find-cli.sh")
if [ -z "$cli" ]; then
  echo "cli: missing (none on PATH, in ~/.local/bin or Homebrew)"
else
  out=$("$cli" version </dev/null 2>&1); cliv=$(printf '%s' "$out" | awk 'NR == 1 {print $2}')
  if [ -z "$cliv" ]; then echo "cli: failed at $cli: $(printf '%s' "$out" | head -1 | cut -c1-160)"
  elif at_least "$cliv" "$min_cli"; then echo "cli: ok $cliv at $cli"
  else echo "cli: outdated $cliv at $cli (needs $min_cli or later)"; fi
  [ "$(command -v modelplan 2>/dev/null)" = "$cli" ] || echo "cli-path: not on this shell's PATH; the plugin finds it anyway, a status line needs the full path $cli"
fi
snap=$(snapshot)
if m=$(ago "$snap"); then
  if grep -q '"windows": *\[\]' "$snap" 2>/dev/null; then echo "statusline: recording, last ${m} min ago, but Claude Code passed no usage windows (API key, or no response yet in that session)"
  else echo "statusline: recording, last reading ${m} min ago"; fi
elif grep -q 'modelplan statusline' "$(settings_file)" 2>/dev/null; then
  echo "statusline: set in $(settings_file), no reading recorded yet (it records once the interactive status line renders)"
else
  echo "statusline: not set up (quota hints need it; /modelplan:statusline)"
fi
if m=$(ago "$state/hook-ran"); then echo "hook: last ran ${m} min ago, plugin $(cat "$state/hook-ran" 2>/dev/null)"
else echo "hook: has not run yet (it runs when you send a message; disabled hooks or a managed policy stop it)"; fi
recent cli-declined 90 && echo "declined: cli (the hook stays quiet about it for 90 days)"
recent statusline-declined 90 && echo "declined: statusline"
if [ -n "$cli" ] && [ -n "$cliv" ] && at_least "$cliv" "$min_cli" && [ -f "$state/hook-ran" ]; then
  if [ -f "$snap" ]; then echo "hints: on (quota hints and the task-start brief)"; else echo "hints: task-start brief on; quota hints wait for the status line"; fi
else
  echo "hints: off until the CLI is ok and the hook has run"
fi
