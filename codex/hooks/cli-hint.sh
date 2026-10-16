#!/bin/sh
# SessionStart: without the modelplan CLI, say how to turn hints on, at most once a week.
# Installs nothing; the dashboard's Install button or the command below does that.
sh "$(dirname "$0")/find-cli.sh" >/dev/null && exit 0
dir="${PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/modelplan}"
mark="$dir/cli-hint"
[ -n "$(find "$mark" -mtime -7 2>/dev/null)" ] && exit 0
mkdir -p "$dir" 2>/dev/null && : > "$mark" 2>/dev/null
cat <<'JSON'
{"systemMessage":"ModelPlan：未检测到 modelplan CLI，主动额度提醒（重置前升档或开 Fast、重置后切回 ★）未启用。在 Model Plan 看板点“安装 CLI”，或在终端运行 curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh。每周最多提示一次。\nModelPlan: the modelplan CLI is not installed, so proactive quota hints are off. Click Install CLI on the Model Plan dashboard, or run the command above.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"The ModelPlan plugin's optional modelplan CLI is not installed, so its proactive quota hints are off. Do not bring this up on your own. If the user asks about it, or asks to install it, the install command is: curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh (latest release, checksum-checked, into ~/.local/bin; nothing else changes)."}}
JSON
exit 0
