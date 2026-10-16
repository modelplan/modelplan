#!/bin/sh
# Runs the modelplan CLI wherever it is installed, for the plugin's commands.
cli=$(sh "$(dirname "$0")/find-cli.sh") || { echo "modelplan CLI not found. Run /modelplan:setup to install it."; exit 0; }
exec "$cli" "$@"
