#!/bin/sh
# Run only after the user accepts the Skill's one-time CLI installation offer.
# Reuse the plugins' pinned, SHA-256 checked download; never edit PATH or profiles.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dest="$HOME/.local/bin"
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$here/../cli-pin.json" | head -1)
[ -n "$version" ] || { echo 'CLI pin unavailable' >&2; exit 1; }
# Compare numeric release components; an equal prerelease is below the stable pin.
at_least() {
  awk -v installed="$1" -v pinned="$2" 'BEGIN {
    if (installed !~ /^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/) exit 1
    sub(/\+.*/, "", installed)
    split(installed, a, /[.-]/); split(pinned, b, ".")
    for (i = 1; i <= 3; i++) {
      if (a[i] + 0 > b[i] + 0) exit 0
      if (a[i] + 0 < b[i] + 0) exit 1
    }
    exit installed ~ /-/ ? 1 : 0
  }'
}
keep_installed() {
  [ -x "$dest/modelplan" ] || return 1
  current=$("$dest/modelplan" version </dev/null 2>/dev/null | awk '$1 == "modelplan" { sub(/^v/, "", $2); print $2; exit }')
  if [ -n "$current" ] && at_least "$current" "$version"; then
    printf 'already installed (v%s)\n' "$current"
    return 0
  fi
  return 1
}
keep_installed && exit 0
cli=$(MODELPLAN_PLUGIN_CLI= sh "$here/fetch-cli.sh") || exit 1
mkdir -p "$dest"
tmp=$(mktemp "$dest/.modelplan-XXXXXX")
locked=
cleanup() {
  rm -f "$tmp"
  [ -z "$locked" ] || rmdir "$locked"
}
trap cleanup EXIT
install -m 0755 "$cli" "$tmp"
# Share the destination lock name with `modelplan update`. mkdir and O_EXCL
# both refuse an existing file or directory, so neither updater can overlap.
lock="$dest/modelplan.update.lock"
mkdir "$lock" 2>/dev/null || { echo 'another CLI update is running' >&2; exit 1; }
locked=$lock
# Another installer may have completed while the pinned archive downloaded.
keep_installed && exit 0
mv -f "$tmp" "$dest/modelplan"
printf 'Installed modelplan to %s/modelplan\n' "$dest"
case ":$PATH:" in *":$dest:"*) ;; *) printf 'Add %s to your PATH.\n' "$dest" ;; esac
