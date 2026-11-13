#!/bin/sh
# Install the modelplan CLI from the latest GitHub release into ~/.local/bin (or $MODELPLAN_BIN).
set -eu
os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in darwin|linux) ;; *) echo "Unsupported OS: $os (download from https://github.com/modelplan/modelplan/releases)" >&2; exit 1 ;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;; esac
name="modelplan_${os}_${arch}"
base="https://github.com/modelplan/modelplan/releases/latest/download"
dest="${MODELPLAN_BIN:-$HOME/.local/bin}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Each failure names its kind on stderr (download, checksum, permission), so callers can say what to do.
curl -fsSL "$base/$name.tar.gz" -o "$tmp/$name.tar.gz" || { echo "download failed: $base/$name.tar.gz (network, proxy or GitHub unreachable)" >&2; exit 1; }
curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt" || { echo "download failed: $base/checksums.txt (network, proxy or GitHub unreachable)" >&2; exit 1; }
(cd "$tmp" && grep " $name.tar.gz\$" checksums.txt | sha256sum -c - >/dev/null 2>&1 || grep " $name.tar.gz\$" checksums.txt | shasum -a 256 -c - >/dev/null 2>&1) || { echo "checksum mismatch for $name.tar.gz: not installed (retry later; if it persists, report it)" >&2; exit 1; }
tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
mkdir -p "$dest" 2>/dev/null && install -m 0755 "$tmp/$name/modelplan" "$dest/modelplan" 2>/dev/null || { echo "permission denied: cannot write $dest/modelplan (set MODELPLAN_BIN to a writable directory)" >&2; exit 1; }
echo "Installed modelplan to $dest/modelplan"
case ":$PATH:" in *":$dest:"*) ;; *) echo "Add $dest to your PATH." ;; esac
