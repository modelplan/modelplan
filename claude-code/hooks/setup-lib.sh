# Shared by the hook and /modelplan:setup (sourced, POSIX sh). State lives in
# ~/.cache/modelplan-claude-code: hook-ran (every start: the plugin version), hook-result (how the
# run ended: ok, failed with exit code and error, or why the CLI was not asked), hook-ok (the last
# run where the CLI computed hints), announced-<version> (the fetched CLI was announced),
# asked-<kind> (the model was asked once), awaiting-<kind> (that ask awaits the user's next
# reply), notice-<kind> (last notice), statusline-declined (the user said not now).
here=${here:-$(dirname "$0")}
state="$HOME/.cache/modelplan-claude-code"
# The plugin's CLI: the release pinned in ../cli-pin.json, fetched by fetch-cli.sh.
min_cli=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../cli-pin.json" 2>/dev/null | head -1)
cli_root="$HOME/.cache/modelplan-cli"
pinned_cli="$cli_root/$min_cli/modelplan"

plugin_version() { sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../.claude-plugin/plugin.json" 2>/dev/null | head -1; }
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
recent() { [ -f "$state/$1" ] && [ -n "$(find "$state/$1" -mtime -"$2" 2>/dev/null)" ]; }
# Why the last fetch of the pinned CLI failed, if it did.
fetch_error() { sed -n "s/^$min_cli failed: //p" "$cli_root/fetch-result" 2>/dev/null | head -1; }

# The CLI's cache, as the CLI resolves it ($MODELPLAN_CACHE, else the OS user cache dir).
cli_cache() {
  if [ -n "$MODELPLAN_CACHE" ]; then printf '%s\n' "$MODELPLAN_CACHE"
  elif [ "$(uname)" = Darwin ]; then printf '%s\n' "$HOME/Library/Caches/modelplan"
  else printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/modelplan"; fi
}
snapshot() { printf '%s\n' "$(cli_cache)/observed/claude-code.json"; }
settings_file() { printf '%s\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; }
# The status line is set up when it has recorded a reading or the user settings call modelplan.
statusline_set() { [ -f "$(snapshot)" ] || grep -q 'modelplan statusline' "$(settings_file)" 2>/dev/null; }

# notice <kind> [detail]: sets $msg (for the user) and $ctx (for the model) and returns 0 when a
# notice is due, at most once a week per kind.
#   fetch       the plugin could not fetch its CLI (detail: why); told, never asked
#   statusline  no Claude Code quota recorded: the first time Claude offers /modelplan:statusline
#               once; a short "no" in the next message is recorded (reply), then 90 days quiet
notice() {
  kind=$1 detail=$2
  [ "$kind" = statusline ] && recent statusline-declined 90 && return 1
  recent "notice-$kind" 7 && return 1
  mkdir -p "$state" 2>/dev/null
  : > "$state/notice-$kind" 2>/dev/null
  case $kind in
    fetch)
      msg="ModelPlan：没能下载插件配套的 modelplan CLI $min_cli（$detail），额度提醒和任务开始简报暂不可用。运行 /modelplan:setup 重试。
ModelPlan: could not fetch the plugin's modelplan CLI $min_cli ($detail), so quota hints and the task-start brief are off. Run /modelplan:setup to retry."
      ctx="The ModelPlan plugin could not fetch its CLI ($detail), so its quota hints and task-start brief are off. Mention it only if the user asks about ModelPlan, quota hints or setup." ;;
    statusline)
      first=yes
      [ -f "$state/asked-statusline" ] && first=no
      : > "$state/asked-statusline" 2>/dev/null
      msg="ModelPlan：还没有记录到 Claude Code 的额度（要靠 Model Plan 状态栏记录），额度提醒暂不可用。运行 /modelplan:statusline 设置。
ModelPlan: no Claude Code quota recorded yet (the Model Plan status line records it), so quota hints are off. Run /modelplan:statusline to set it up."
      ctx="The ModelPlan status line is not set up, so Claude Code's 5-hour and weekly usage is not recorded and quota hints are off; the task-start brief still works without it."
      if [ "$first" = yes ]; then
        : > "$state/awaiting-statusline" 2>/dev/null
        ctx="$ctx After answering the user's request, add one or two sentences: the status line records the usage windows Claude Code passes to it (Pro/Max plans; nothing leaves the machine); suggest the user run /modelplan:statusline, which asks before changing settings and can keep an existing status line. Do not edit settings yourself in this turn. If they decline, acknowledge it in one sentence and do not raise it again; the plugin reads their answer from the next message itself, so run nothing for it. Never change the model, effort or fast mode."
      else
        ctx="$ctx Mention it only if the user asks about ModelPlan, quota hints or setup."
      fi ;;
  esac
  return 0
}

# A short "no" right after the ask: the hook records it, so declining needs no command (and no
# permission prompt). Anything else leaves the weekly notice as it is.
is_decline() {
  [ "${#1}" -le 60 ] && printf '%s\n' "$1" | grep -iqE '^[[:space:]]*(不用|不要|不装|不需要|不必|不了|暂不|暂时不|先不|算了|以后再说|下次再说|no([^a-z]|$)|nope|nah|not now|skip|later|don.?t)'
}

# reply <prompt>: consumes a pending status-line ask; on a decline records it and sets $declined.
reply() {
  declined=
  [ -f "$state/awaiting-statusline" ] || return 0
  fresh=$(find "$state/awaiting-statusline" -mmin -1440 2>/dev/null)
  rm -f "$state/awaiting-statusline"
  [ -n "$fresh" ] && is_decline "$1" && : > "$state/statusline-declined" 2>/dev/null && declined=statusline
  return 0
}

# The prompt from hook input on stdin, when it is a plain JSON string (enough for a short reply).
prompt_of() { printf '%s' "$1" | tr '\n' ' ' | sed -n 's/.*"prompt" *: *"\([^"\\]*\)".*/\1/p' | head -1; }

esc() { printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) print "\\n"; print }'; }
