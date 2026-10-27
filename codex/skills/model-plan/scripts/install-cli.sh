#!/bin/sh
# Run only after the user accepts the Skill's one-time CLI installation offer.
# Reuse the plugins' pinned, SHA-256 checked download; never edit PATH or profiles.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cli=$(MODELPLAN_PLUGIN_CLI= sh "$here/fetch-cli.sh") || exit 1
dest="$HOME/.local/bin"
mkdir -p "$dest"
tmp=$(mktemp "$dest/.modelplan-XXXXXX")
trap 'rm -f "$tmp"' EXIT
install -m 0755 "$cli" "$tmp"
mv -f "$tmp" "$dest/modelplan"
printf 'Installed modelplan to %s/modelplan\n' "$dest"
case ":$PATH:" in *":$dest:"*) ;; *) printf 'Add %s to your PATH.\n' "$dest" ;; esac
