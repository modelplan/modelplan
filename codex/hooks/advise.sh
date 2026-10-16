#!/bin/sh
# UserPromptSubmit: hand new Model Plan hints to Codex once each. Silent without the CLI.
cli=$(sh "$(dirname "$0")/find-cli.sh") || exit 0
"$cli" advise --hook codex 2>/dev/null
exit 0
