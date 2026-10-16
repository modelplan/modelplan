#!/bin/sh
# Runs the plugin's modelplan CLI (its pinned copy, fetched now if missing), else one you installed.
here=$(dirname "$0")
cli=$(sh "$here/find-cli.sh") || { sh "$here/fetch-cli.sh" >/dev/null 2>&1; cli=$(sh "$here/find-cli.sh"); } || { echo "modelplan CLI not available. Run /modelplan:setup to see why."; exit 0; }
exec "$cli" "$@"
