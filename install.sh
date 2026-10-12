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
curl -fsSL "$base/$name.tar.gz" -o "$tmp/$name.tar.gz"
curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt"
(cd "$tmp" && grep " $name.tar.gz\$" checksums.txt | sha256sum -c - >/dev/null 2>&1 || grep " $name.tar.gz\$" checksums.txt | shasum -a 256 -c - >/dev/null)
tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
mkdir -p "$dest"
install -m 0755 "$tmp/$name/modelplan" "$dest/modelplan"
echo "Installed modelplan to $dest/modelplan"
case ":$PATH:" in *":$dest:"*) ;; *) echo "Add $dest to your PATH." ;; esac
