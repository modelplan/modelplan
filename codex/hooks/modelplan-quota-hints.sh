#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). With the modelplan CLI: new quota hints and, on a
# thread's first prompt, the task-start brief (`modelplan advise --hook codex`). Without it, or
# with one too old: a setup notice (setup-notice.sh) instead, when one is due. Prints at most one
# JSON object. Reads and writes only ~/.cache/modelplan-codex. Never installs anything.
here=$(dirname "$0")
state="$HOME/.cache/modelplan-codex"
# Heartbeat with this plugin's version: the dashboard tells "never ran" and "an update's hook has
# not run yet" (Codex skips a changed hook until it is trusted again) apart from "ran".
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../package.json" 2>/dev/null | head -1)
mkdir -p "$state" 2>/dev/null && printf '%s' "$version" > "$state/hook-ran" 2>/dev/null
min=0.5.5
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
  exit 0
fi
cli=$(sh "$here/find-cli.sh")
if [ -z "$cli" ]; then
  sh "$here/setup-notice.sh" missing "" "$min"
  exit 0
fi
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min"; then
  # Older CLIs still give hints; the upgrade notice takes their place when it is due.
  sh "$here/setup-notice.sh" outdated "${cliv:-unknown}" "$min" && exit 0
fi
printf '%s' "$input" | "$cli" advise --hook codex 2>/dev/null
exit 0
