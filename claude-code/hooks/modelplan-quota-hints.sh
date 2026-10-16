#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). With the modelplan CLI: new quota hints and, on a
# session's first prompt, the task-start brief (`modelplan advise --hook claude-code`, which also
# refreshes the published data in the background when it is old). Without it, or with one too
# old: a setup notice instead, when one is due (setup-lib.sh). Prints at most one JSON object.
# Writes only ~/.cache/modelplan-claude-code (and, through the CLI, its own cache). Never
# installs anything or changes a setting.
here=$(dirname "$0")
. "$here/setup-lib.sh"
input=$(cat)
mkdir -p "$state" 2>/dev/null && plugin_version > "$state/hook-ran" 2>/dev/null
out() { printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(esc "$1")" "$(esc "$2")"; }
hints() { printf '%s' "$input" | "$cli" advise --hook claude-code "$@" 2>/dev/null; }
# The reply to a setup question asked on the previous prompt: a short "no" is recorded here.
reply "$(prompt_of "$input")"
if [ -n "$declined" ]; then
  what="installing the modelplan CLI"
  [ "$declined" = statusline ] && what="setting up the Model Plan status line"
  sys="ModelPlan：已记下“暂不”，90 天内不再提示。随时可以用 /modelplan:setup 补上。
ModelPlan: noted, no reminders for 90 days; /modelplan:setup any time."
  ack="The user just declined $what. The ModelPlan plugin recorded it and will not raise it for 90 days; acknowledge in at most one short sentence if at all, and run nothing for it."
fi
cli=$(sh "$here/find-cli.sh")
if [ -z "$cli" ]; then
  if [ -n "$declined" ]; then out "$sys" "$ack"
  elif notice missing ""; then out "$msg" "$ctx"; fi
  exit 0
fi
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min_cli"; then
  # Older CLIs still give hints; the upgrade notice (or a recorded "no") takes their place.
  [ -n "$declined" ] && out "$sys" "$ack" && exit 0
  notice outdated "${cliv:-unknown}" && out "$msg" "$ctx" && exit 0
  hints
  exit 0
fi
if [ -n "$declined" ]; then hints --add-system "$sys" --add-context "$ack"
elif ! statusline_set && notice statusline ""; then hints --add-system "$msg" --add-context "$ctx"
else hints; fi
exit 0
