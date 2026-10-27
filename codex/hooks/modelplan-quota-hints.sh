#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). It runs the plugin's own modelplan CLI (the release
# pinned in ../cli-pin.json, which the plugin's server fetches in the background and checks
# against the pinned SHA-256), else one the user installed: new quota hints and, on a thread's
# first prompt, the task-start brief (`modelplan advise --hook codex`). Prints at most one JSON
# object and never blocks the prompt. Setup notices and quota hints are shown to the user only
# (systemMessage); only the task-start brief goes to the model. The hook itself downloads
# nothing; it writes only ~/.cache/modelplan-codex.
# Off silences the entire prompt hook, including setup notices and task briefs.
if [ "$(cat "$HOME/.config/modelplan/codex/automatic-hints" 2>/dev/null)" = off ]; then
  # Drain the host's input so a silent hook cannot cause a broken pipe.
  cat >/dev/null 2>&1
  exit 0
fi
here=$(dirname "$0")
state="$HOME/.cache/modelplan-codex"
# Records, for the dashboard (all on this machine, from whichever chat ran last):
#   hook-ran     every start: the plugin version and the hook definition's checksum (Codex asks
#                to review a changed definition again and skips it until then; a new plugin
#                version with the same definition needs nothing);
#   hook-result  how the run ended: ok, failed (exit code, first error line), or why the CLI
#                was not asked;
#   hook-ok      the last run where the CLI computed the hints without an error.
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../package.json" 2>/dev/null | head -1)
def=$(cksum < "$here/hooks.json" 2>/dev/null | awk '{print $1}')
mkdir -p "$state" 2>/dev/null && printf '%s def=%s\n' "$version" "$def" > "$state/hook-ran" 2>/dev/null
result() { printf '%s\n' "$1" > "$state/hook-result" 2>/dev/null; }
min=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../cli-pin.json" 2>/dev/null | head -1)
pinned="$HOME/.cache/modelplan-cli/$min/modelplan"
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
esc() { printf '%s' "$1" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); if (NR > 1) print "\\n"; print }'; }
out() { printf '{"systemMessage":"%s"}\n' "$(esc "$1")"; }
input=$(cat)
why=$(sed -n "s/^$min failed: //p" "$HOME/.cache/modelplan-cli/fetch-result" 2>/dev/null | head -1)
# A failed fetch is told, at most once a week; there is nothing to install or agree to by hand.
fetch_notice() {
  [ -n "$why" ] || return 1
  [ -f "$state/notice-fetch" ] && [ -n "$(find "$state/notice-fetch" -mtime -7 2>/dev/null)" ] && return 1
  : > "$state/notice-fetch" 2>/dev/null
  out "ModelPlan：没能下载插件配套的 modelplan CLI $min（$why），额度提醒和任务开始简报暂不可用。打开 ModelPlan 看板点“重试”。
ModelPlan: could not fetch the plugin's modelplan CLI $min ($why), so quota hints and the task-start brief are off. Open the ModelPlan dashboard and click Retry."
}
cli=$(sh "$here/find-cli.sh" "$min")
if [ -z "$cli" ]; then
  result "skipped: cli not ready${why:+ (fetch failed: $why)}"
  fetch_notice
  exit 0
fi
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min"; then
  # A user-installed older CLI gives its own hints until the pinned one is there.
  fetch_notice && result "skipped: cli ${cliv:-unknown} older than $min" && exit 0
  set --
elif [ "$cli" = "$pinned" ] && [ ! -f "$state/announced-$min" ]; then
  : > "$state/announced-$min" 2>/dev/null
  set -- --add-system "ModelPlan：已就绪插件配套的 modelplan CLI $min（按插件锁定的校验值核对），额度提醒和任务开始简报已启用。
ModelPlan: the plugin's modelplan CLI $min is ready (checked against the checksum pinned in the plugin); quota hints and the task-start brief are on."
else
  set --
fi
# The prompt never waits on a failure, but the dashboard hears about it.
hints=$(printf '%s' "$input" | "$cli" advise --hook codex "$@" 2>"$state/hook-stderr")
code=$?
if [ "$code" -eq 0 ]; then
  result ok
  : > "$state/hook-ok" 2>/dev/null
else
  result "failed: exit $code: $(head -1 "$state/hook-stderr" 2>/dev/null | cut -c1-160)"
fi
rm -f "$state/hook-stderr"
[ -n "$hints" ] && printf '%s\n' "$hints"
exit 0
