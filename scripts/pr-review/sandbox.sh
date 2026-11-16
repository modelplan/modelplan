# SPDX-License-Identifier: MIT
# Sourced by preflight.sh and run-codex.sh: the one Codex permission profile the workflow reviewer uses.
# The whole file system is readable except the runner user's home, which holds the Codex login (CODEX_HOME) and the
# runner's own credentials; nothing is writable and model commands get no network. Do NOT add --sandbox: on
# codex-cli 0.164 an explicit --sandbox read-only replaces this profile and the login becomes readable again.
# Verified 2026-11-14 on codex-cli 0.164.0 / Linux arm64; preflight.sh proves it again before every review.
review_home=$(cd "$HOME" && pwd -P)
CODEX_PERMISSION_ARGS=(
  -c 'default_permissions="review"'
  -c "permissions.review.filesystem={\":root\"=\"read\",\"$review_home\"=\"none\"}"
)
