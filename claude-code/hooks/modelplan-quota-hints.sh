#!/bin/sh
# ModelPlan's only hook (UserPromptSubmit). With the modelplan CLI: new quota hints and, on a
# session's first prompt, the task-start brief (`modelplan advise --hook claude-code`, which also
# refreshes the published data in the background when it is old). Without it, or with one too
# old: a setup notice instead, when one is due (setup-lib.sh). Prints at most one JSON object.
# Writes only ~/.cache/modelplan-claude-code (and, through the CLI, its own cache). Never
# installs anything or changes a setting.
here=$(dirname "$0")
. "$here/setup-lib.sh"
mkdir -p "$state" 2>/dev/null && plugin_version > "$state/hook-ran" 2>/dev/null
cli=$(sh "$here/find-cli.sh")
if [ -z "$cli" ]; then
  notice missing "" && printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(esc "$msg")" "$(esc "$ctx")"
  exit 0
fi
cliv=$("$cli" version </dev/null 2>/dev/null | awk '{print $2}')
if [ -z "$cliv" ] || ! at_least "$cliv" "$min_cli"; then
  # Older CLIs still give hints; the upgrade notice takes their place when it is due.
  notice outdated "${cliv:-unknown}" && printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$(esc "$msg")" "$(esc "$ctx")" && exit 0
  "$cli" advise --hook claude-code 2>/dev/null
  exit 0
fi
if ! statusline_set && notice statusline ""; then
  "$cli" advise --hook claude-code --add-system "$msg" --add-context "$ctx" 2>/dev/null
  exit 0
fi
"$cli" advise --hook claude-code 2>/dev/null
exit 0
