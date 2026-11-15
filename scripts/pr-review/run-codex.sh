#!/bin/bash
# SPDX-License-Identifier: MIT
# One Codex review of the prepared brief. Codex output goes to files under the runner temp, never to the public job
# log. The environment is rebuilt from scratch so no runner or job variable reaches Codex or its commands.
set -euo pipefail
dir="$RUNNER_TEMP/pr-review"
. "$GITHUB_WORKSPACE/scripts/pr-review/sandbox.sh"
start=$(date +%s)
cd "$dir/pr"
set +e
env -i HOME="$HOME" PATH="$PATH" CODEX_HOME="$CODEX_HOME" LANG=C.UTF-8 TERM=dumb \
  timeout 1500 codex exec --ephemeral --ignore-user-config --ignore-rules \
    -m "$MODEL" -c "model_reasoning_effort=\"$EFFORT\"" -c 'approval_policy="never"' -c 'web_search="disabled"' \
    "${CODEX_PERMISSION_ARGS[@]}" \
    --disable apps --disable plugins --disable hooks --disable browser_use --disable computer_use --disable in_app_browser \
    --output-schema "$GITHUB_WORKSPACE/scripts/pr-review/output-schema.json" \
    -o "$dir/result.json" --json - <"$dir/brief.md" >"$dir/events.jsonl" 2>"$dir/codex.err"
rc=$?
set -e
echo $(( $(date +%s) - start )) >"$dir/seconds"
echo "codex exit $rc after $(cat "$dir/seconds") s"
[ "$rc" = 0 ] && [ -s "$dir/result.json" ] || { echo "pr-review: no review result" >&2; exit 1; }
