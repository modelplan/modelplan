# Shared by the hook and /modelplan:setup (sourced, POSIX sh). State lives in
# ~/.cache/modelplan-claude-code: hook-ran (every start: the plugin version), hook-result (how the
# run ended: ok, failed with exit code and error, or why the CLI was not asked), hook-ok (the last
# run where the CLI computed hints), announced-<version> (the fetched CLI was announced),
# notice-fetch (last fetch notice). Legacy status-line decline files may remain.
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

# notice <kind> [detail]: sets $msg, shown to the user only (the hook's systemMessage; the model
# never hears of setup), and returns 0 when a notice is due.
#   fetch       the plugin could not fetch its CLI (detail: why): at most once a week
notice() {
  kind=$1 detail=$2
  mkdir -p "$state" 2>/dev/null
  case $kind in
    fetch)
      recent "notice-$kind" 7 && return 1
      msg="ModelPlan：没能下载插件配套的 modelplan CLI $min_cli（$detail），额度提醒和任务开始简报暂不可用。运行 /modelplan:setup 重试。
ModelPlan: could not fetch the plugin's modelplan CLI $min_cli ($detail), so quota hints and the task-start brief are off. Run /modelplan:setup to retry." ;;
  esac
  : > "$state/notice-$kind" 2>/dev/null
  return 0
}

esc() { printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) print "\\n"; print }'; }
