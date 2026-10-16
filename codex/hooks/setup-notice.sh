#!/bin/sh
# Setup notice for the hook when the modelplan CLI is missing ($1=missing) or older than $3
# ($1=outdated, $2=its version). Exits 0 when it printed a notice, 1 when none is due.
#   first time: a short notice for the user and a request that the model ask once (the hook
#   records a short "no" in the next prompt itself);
#   afterwards: the notice alone, at most once a week;
#   after the user declined (cli-declined, from the dashboard or the model): nothing for 90 days.
# Asking the user about setup is never limited by this; the dashboard and doctor always show it.
state="$HOME/.cache/modelplan-codex"
kind=$1 version=$2 min=$3
recent() { [ -f "$state/$1" ] && [ -n "$(find "$state/$1" -mtime -"$2" 2>/dev/null)" ]; }
recent cli-declined 90 && exit 1
recent "notice-$kind" 7 && exit 1
mkdir -p "$state" 2>/dev/null
first=yes
[ -f "$state/asked-$kind" ] && first=no
: > "$state/notice-$kind" 2>/dev/null
: > "$state/asked-$kind" 2>/dev/null
[ "$first" = yes ] && : > "$state/awaiting-$kind" 2>/dev/null # the hook reads the user's reply
install='curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh'
if [ "$kind" = outdated ]; then
  msg="ModelPlan：modelplan CLI $version 低于插件需要的 $min，部分提醒（额度提前预警、换模型方案）和简报功能用不上。在 Model Plan 看板点“升级 CLI”，或运行 $install。\nModelPlan: modelplan CLI $version is older than the $min the plugin needs; upgrade from the dashboard or with the command above."
  ctx="The ModelPlan plugin found modelplan CLI $version, older than the $min it needs, so some quota hints (early warnings, cheaper-model options) and brief features are off."
else
  msg="ModelPlan：未检测到可选的 modelplan CLI，额度提醒（重置前升档或开 Fast、重置后切回 ★）和任务开始简报未启用。在 Model Plan 看板点“安装 CLI”，或运行 $install。\nModelPlan: the optional modelplan CLI is not installed, so quota hints and the task-start brief are off. Install it from the dashboard or with the command above."
  ctx="The ModelPlan plugin's optional modelplan CLI is not installed, so its quota hints and task-start brief are off."
fi
if [ "$first" = yes ]; then
  ctx="$ctx After answering the user's request, add one or two sentences: what the CLI adds (quota hints before resets and after them, a model and effort suggestion at the start of a task), and ask whether to install or upgrade it. Only if they say yes, run: $install (latest release, checksum-checked, into ~/.local/bin; nothing else changes), then run ~/.local/bin/modelplan version to confirm, and say hints start with their next message. If they decline, acknowledge it in one sentence and do not raise it again; the plugin reads their answer from the next message itself, so run nothing for it. Do not change hook trust or any setting."
else
  ctx="$ctx Mention it only if the user asks about ModelPlan, quota hints or setup."
fi
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(esc "$msg" | sed 's/\\\\n/\\n/g')" "$(esc "$ctx")"
exit 0
