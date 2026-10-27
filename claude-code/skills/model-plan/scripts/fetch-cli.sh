#!/bin/sh
# Fetches the modelplan CLI release this plugin is pinned to (../cli-pin.json) and prints its path.
# The archive for this OS and CPU comes from the pinned GitHub release and is used only if its
# SHA-256 equals the one written in the plugin, which is reviewed and installed with the plugin
# itself. It lands in ~/.cache/modelplan-cli/<version>/modelplan, and ~/.cache/modelplan-cli/modelplan
# links the newest one. Nothing else changes: no PATH, profile or sudo, and a modelplan in
# ~/.local/bin or Homebrew is left alone. Shared, identical, by the Claude Code and Codex plugins.
#   --background  return at once; a failed fetch is not retried for 10 minutes
#   MODELPLAN_PLUGIN_CLI=off  never fetch (the plugin then uses a modelplan you installed)
# The outcome is in ~/.cache/modelplan-cli/fetch-result: "<version> ok" or "<version> failed: why".
here=$(cd "$(dirname "$0")" && pwd)
pin="$here/../cli-pin.json"
root="$HOME/.cache/modelplan-cli"
[ "${MODELPLAN_PLUGIN_CLI:-}" = off ] && exit 1
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$pin" 2>/dev/null | head -1)
release=$(sed -n 's/^ *"release": *"\([^"]*\)".*/\1/p' "$pin" 2>/dev/null | head -1)
[ -n "$version" ] && [ -n "$release" ] || exit 1
dest="$root/$version/modelplan"
at_least() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }
# ~/.cache/modelplan-cli/modelplan: a stable path (for a status line) to the newest fetched
# version, whichever plugin fetched it.
link() {
  cur=$(readlink "$root/modelplan" 2>/dev/null | cut -d/ -f1)
  if [ -z "$cur" ] || [ ! -x "$root/$cur/modelplan" ] || at_least "$version" "$cur"; then ln -sf "$version/modelplan" "$root/modelplan" 2>/dev/null; fi
}
if [ -x "$dest" ]; then link; printf '%s\n' "$dest"; exit 0; fi
mkdir -p "$root" 2>/dev/null || exit 1
if [ "${1:-}" = --background ]; then
  if grep -q "^$version failed" "$root/fetch-result" 2>/dev/null && [ -n "$(find "$root/fetch-result" -mmin -10 2>/dev/null)" ]; then exit 1; fi
  nohup sh "$here/fetch-cli.sh" </dev/null >/dev/null 2>&1 &
  exit 0
fi
result() { printf '%s %s\n' "$version" "$1" > "$root/fetch-result"; }
fail() { result "failed: $1"; echo "modelplan CLI $version: $1" >&2; exit 1; }

case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) fail "unsupported system $(uname -s)" ;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) fail "unsupported CPU $(uname -m)" ;; esac
key="${os}_${arch}"
want=$(sed -n "s/^ *\"$key\": *\"\([0-9a-f]\{64\}\)\".*/\1/p" "$pin" | head -1)
[ -n "$want" ] || fail "no pinned checksum for $key"

# One fetch at a time per version; a lock older than 10 minutes is left over from a crash.
lock="$root/.lock-$version"
[ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
mkdir "$lock" 2>/dev/null || exit 1
tmp=$(mktemp -d "$root/.fetch-XXXXXX") || { rmdir "$lock"; exit 1; }
trap 'rm -rf "$tmp"; rmdir "$lock" 2>/dev/null' EXIT

curl -fsSL --max-time 120 "$release/modelplan_$key.tar.gz" -o "$tmp/a.tar.gz" 2>"$tmp/err" ||
  fail "download failed ($(head -1 "$tmp/err" | cut -c1-120); network, proxy or GitHub unreachable)"
got=$( (sha256sum "$tmp/a.tar.gz" 2>/dev/null || shasum -a 256 "$tmp/a.tar.gz" 2>/dev/null) | awk '{print $1}')
[ "$got" = "$want" ] || fail "checksum mismatch (got ${got:-none}); nothing installed"
tar -xzf "$tmp/a.tar.gz" -C "$tmp" 2>/dev/null && [ -f "$tmp/modelplan_$key/modelplan" ] || fail "archive unreadable"
mkdir -p "$root/$version" && cp "$tmp/modelplan_$key/modelplan" "$dest.new" && chmod 755 "$dest.new" || fail "cannot write $root/$version"
[ "$("$dest.new" version 2>/dev/null | awk '{print $2}')" = "$version" ] || { rm -f "$dest.new"; fail "the downloaded CLI does not run here"; }
mv -f "$dest.new" "$dest" || fail "cannot write $dest"
result ok
link
# Versions no plugin has pinned for a month are dropped, never the one the stable path names.
keep=$(readlink "$root/modelplan" 2>/dev/null | cut -d/ -f1)
find "$root" -mindepth 1 -maxdepth 1 -type d ! -name "$version" ! -name "${keep:-$version}" ! -name '.*' -mtime +30 -exec rm -rf {} + 2>/dev/null
printf '%s\n' "$dest"
