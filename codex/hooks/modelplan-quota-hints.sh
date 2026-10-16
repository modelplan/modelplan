#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). With the modelplan CLI: new quota hints and, on a
# thread's first prompt, the task-start brief (`modelplan advise --hook codex`). Without it, or
# with one too old: a setup notice (setup-notice.sh) instead, when one is due. Prints at most one
# JSON object. Reads and writes only ~/.cache/modelplan-codex. Never installs anything.
here=$(dirname "$0")
state="$HOME/.cache/modelplan-codex"
# Records, for the dashboard (all on this machine, from whichever chat ran last):
#   hook-ran     every start: the plugin version and the hook definition's checksum (Codex asks
#                to review a changed definition again and skips it until then; a new plugin
#                version with the same definition needs nothing);
#   hook-result  how the run ended: ok, failed (exit code, first error line), or why the CLI
#                was not asked (missing, outdated, declined);
#   hook-ok      the last run where the CLI computed the hints without an error.
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../package.json" 2>/dev/null | head -1)
def=$(cksum < "$here/hooks.json" 2>/dev/null | awk '{print $1}')
mkdir -p "$state" 2>/dev/null && printf '%s def=%s\n' "$version" "$def" > "$state/hook-ran" 2>/dev/null
result() { printf '%s\n' "$1" > "$state/hook-result" 2>/dev/null; }
min=$(cat "$here/../cli-min.txt" 2>/dev/null)
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
input=$(cat)
# The reply to the setup question asked on the previous prompt: a short "no" is recorded here, so
# declining needs no command (and no approval). Anything else leaves the weekly notice as it is.
prompt=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"prompt" *: *"\([^"\\]*\)".*/\1/p' | head -1)
declined=
for k in missing outdated; do
  [ -f "$state/awaiting-$k" ] || continue
  fresh=$(find "$state/awaiting-$k" -mmin -1440 2>/dev/null)
  rm -f "$state/awaiting-$k"
  if [ -n "$fresh" ] && [ "${#prompt}" -le 60 ] && printf '%s\n' "$prompt" | grep -iqE '^[[:space:]]*(不用|不要|不装|不需要|不必|不了|暂不|暂时不|先不|算了|以后再说|下次再说|no([^a-z]|$)|nope|nah|not now|skip|later|don.?t)'; then
    : > "$state/cli-declined" 2>/dev/null && declined=yes
  fi
done
if [ -n "$declined" ]; then
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
    'ModelPlan：已记下“暂不”，90 天内不再提示。随时可以在 Model Plan 看板安装。\nModelPlan: noted, no reminders for 90 days; install from the dashboard any time.' \
    'The user just declined installing the modelplan CLI. The ModelPlan plugin recorded it and will not raise it for 90 days; acknowledge in at most one short sentence if at all, and run nothing for it.'
  result "skipped: declined"
  exit 0
fi
cli=$(sh "$here/find-cli.sh" "$min")
if [ -z "$cli" ]; then
  result "skipped: cli missing"
  sh "$here/setup-notice.sh" missing "" "$min"
  exit 0
fi
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min"; then
  # Older CLIs still give hints; the upgrade notice takes their place when it is due.
  sh "$here/setup-notice.sh" outdated "${cliv:-unknown}" "$min" && result "skipped: cli ${cliv:-unknown} outdated" && exit 0
fi
# The prompt never waits on a failure, but the dashboard hears about it.
out=$(printf '%s' "$input" | "$cli" advise --hook codex 2>"$state/hook-stderr")
code=$?
if [ "$code" -eq 0 ]; then
  result ok
  : > "$state/hook-ok" 2>/dev/null
else
  result "failed: exit $code: $(head -1 "$state/hook-stderr" 2>/dev/null | cut -c1-160)"
fi
rm -f "$state/hook-stderr"
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
