#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). It runs the plugin's own modelplan CLI (the release
# pinned in ../cli-pin.json, which fetch-cli.sh downloads in the background and checks against
# the pinned SHA-256), else one the user installed: new quota hints and, on a session's first
# prompt, the task-start brief (`modelplan advise --hook claude-code`). Prints at most one JSON
# object and never blocks the prompt. Writes ~/.cache/modelplan-claude-code and, through
# fetch-cli.sh, ~/.cache/modelplan-cli; changes no setting. MODELPLAN_PLUGIN_CLI=off: no fetch.
here=$(dirname "$0")
. "$here/setup-lib.sh"
input=$(cat)
mkdir -p "$state" 2>/dev/null && plugin_version > "$state/hook-ran" 2>/dev/null
result() { printf '%s\n' "$1" > "$state/hook-result" 2>/dev/null; }
out() { printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(esc "$1")" "$(esc "$2")"; }
# One message for the user and one for the model, from whatever is due this prompt.
sys= ctx_all=
add() { sys="${sys:+$sys
}$1"; [ -n "$2" ] && ctx_all="${ctx_all:+$ctx_all }$2"; return 0; }
# The CLI's run: the prompt never waits on a failure, but /modelplan:setup hears about it.
hints() {
  if [ -n "$sys" ]; then o=$(printf '%s' "$input" | "$cli" advise --hook claude-code --add-system "$sys" --add-context "$ctx_all" 2>"$state/hook-stderr")
  else o=$(printf '%s' "$input" | "$cli" advise --hook claude-code 2>"$state/hook-stderr"); fi
  c=$?
  if [ "$c" -eq 0 ]; then result ok; : > "$state/hook-ok" 2>/dev/null
  else result "failed: exit $c: $(head -1 "$state/hook-stderr" 2>/dev/null | cut -c1-160)"; [ -n "$sys" ] && o=$(out "$sys" "$ctx_all"); fi
  rm -f "$state/hook-stderr"
  [ -n "$o" ] && printf '%s\n' "$o"
  return 0
}

# The reply to the status-line question asked on the previous prompt: a short "no" is recorded.
reply "$(prompt_of "$input")"
[ -n "$declined" ] && add "ModelPlan：已记下“暂不”，90 天内不再提示。随时可以用 /modelplan:statusline 设置。
ModelPlan: noted, no reminders for 90 days; /modelplan:statusline any time." \
  "The user just declined setting up the Model Plan status line. The ModelPlan plugin recorded it and will not raise it for 90 days; acknowledge in at most one short sentence if at all, and run nothing for it."

# The pinned CLI: fetched in the background (at once after an install or a plugin update), so
# this prompt uses whatever is there and the next one has it.
[ -x "$pinned_cli" ] || sh "$here/fetch-cli.sh" --background >/dev/null 2>&1
cli=$(sh "$here/find-cli.sh" "$min_cli")
why=$(fetch_error)
if [ -z "$cli" ]; then
  result "skipped: cli not ready${why:+ (fetch failed: $why)}"
  [ -n "$why" ] && notice fetch "$why" && add "$msg" "$ctx"
  [ -n "$sys" ] && out "$sys" "$ctx_all"
  exit 0
fi
if [ "$cli" = "$pinned_cli" ] && [ ! -f "$state/announced-$min_cli" ]; then
  : > "$state/announced-$min_cli" 2>/dev/null
  add "ModelPlan：已就绪插件配套的 modelplan CLI $min_cli（按插件锁定的校验值核对），额度提醒和任务开始简报已启用。
ModelPlan: the plugin's modelplan CLI $min_cli is ready (checked against the checksum pinned in the plugin); quota hints and the task-start brief are on." ""
fi
# A user-installed CLI older than the pin still gives hints while the fetch catches up; only a
# failed fetch is worth a word.
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min_cli"; then
  [ -n "$why" ] && notice fetch "$why" && add "$msg" "$ctx"
  if [ -n "$sys" ]; then out "$sys" "$ctx_all"; result "skipped: cli ${cliv:-unknown} older than $min_cli"
  else hints; fi
  exit 0
fi
! statusline_set && notice statusline "" && add "$msg" "$ctx"
hints
exit 0
