# Shared by the hook and /modelplan:setup (sourced, POSIX sh). State lives in
# ~/.cache/modelplan-claude-code: hook-ran (heartbeat, the plugin version), asked-<kind> (the model
# was asked to offer the fix once), notice-<kind> (last notice), <part>-declined (the user said
# not now: cli or statusline).
here=${here:-$(dirname "$0")}
state="$HOME/.cache/modelplan-claude-code"
min_cli=0.5.6 # the Claude Code task-start brief and session-aware status-line readings
install_cmd='curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh'

plugin_version() { sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../.claude-plugin/plugin.json" 2>/dev/null | head -1; }
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
recent() { [ -f "$state/$1" ] && [ -n "$(find "$state/$1" -mtime -"$2" 2>/dev/null)" ]; }

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

# notice <kind> <version>: sets $msg (for the user) and $ctx (for the model) and returns 0 when a
# notice is due for kind missing|outdated (the CLI) or statusline. The first time it asks the
# model to offer the fix once; afterwards it only tells the user, at most once a week; after
# "not now", nothing for 90 days. /modelplan:setup always reports everything.
notice() {
  kind=$1 version=$2 part=cli
  [ "$kind" = statusline ] && part=statusline
  recent "$part-declined" 90 && return 1
  recent "notice-$kind" 7 && return 1
  mkdir -p "$state" 2>/dev/null
  first=yes
  [ -f "$state/asked-$kind" ] && first=no
  : > "$state/notice-$kind" 2>/dev/null
  : > "$state/asked-$kind" 2>/dev/null
  decline="mkdir -p ~/.cache/modelplan-claude-code && touch ~/.cache/modelplan-claude-code/$part-declined"
  case $kind in
    missing)
      msg="ModelPlan：未检测到可选的 modelplan CLI，额度提醒（重置前升档、重置后切回 ★）和任务开始简报未启用。运行 /modelplan:setup 安装。
ModelPlan: the optional modelplan CLI is not installed, so quota hints and the task-start brief are off. Run /modelplan:setup to install it."
      ctx="The ModelPlan plugin's optional modelplan CLI is not installed, so its quota hints and task-start brief are off."
      ask="what the CLI adds (quota hints before resets and after them, a model and effort suggestion at the start of a task), and ask whether to install it. Only if they say yes, run: $install_cmd (latest release, checksum-checked, into ~/.local/bin; nothing else changes), then run ~/.local/bin/modelplan version to confirm and ~/.local/bin/modelplan sync to fetch the published data, and say hints start with their next message." ;;
    outdated)
      msg="ModelPlan：modelplan CLI $version 低于 $min_cli，Claude Code 的任务开始简报不可用。运行 /modelplan:setup 升级。
ModelPlan: modelplan CLI $version is older than $min_cli, so the Claude Code task-start brief is off. Run /modelplan:setup to upgrade."
      ctx="The ModelPlan plugin found modelplan CLI $version, older than $min_cli, so the Claude Code task-start brief is off."
      ask="that upgrading turns on the task-start brief, and ask whether to upgrade. Only if they say yes, run: $install_cmd (latest release, checksum-checked, into ~/.local/bin), then run ~/.local/bin/modelplan version to confirm; if an older copy elsewhere is still found first (command -v modelplan), say where." ;;
    statusline)
      msg="ModelPlan：还没有记录到 Claude Code 的额度（要靠 Model Plan 状态栏记录），额度提醒暂不可用。运行 /modelplan:statusline 设置。
ModelPlan: no Claude Code quota recorded yet (the Model Plan status line records it), so quota hints are off. Run /modelplan:statusline to set it up."
      ctx="The ModelPlan status line is not set up, so Claude Code's 5-hour and weekly usage is not recorded and quota hints are off; the task-start brief still works without it."
      ask="that the status line records the usage windows Claude Code passes to it (Pro/Max plans; nothing leaves the machine), and suggest the user run /modelplan:statusline, which asks before changing settings and can keep an existing status line. Do not edit settings yourself in this turn." ;;
  esac
  if [ "$first" = yes ]; then
    ctx="$ctx After answering the user's request, add one or two sentences: $ask If they decline, run: $decline, and do not raise it again. Never change the model, effort or fast mode."
  else
    ctx="$ctx Mention it only if the user asks about ModelPlan, quota hints or setup."
  fi
  return 0
}

esc() { printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) print "\\n"; print }'; }
