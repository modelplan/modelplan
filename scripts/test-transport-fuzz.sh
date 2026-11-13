#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
duration="${1:-30s}"
if [[ ! "$duration" =~ ^[1-9][0-9]*(s|m)$ ]]; then
  echo 'Expected a positive duration in seconds or minutes.' >&2
  exit 2
fi
output="$root/.tmp/transport-fuzz"
mkdir -p "$output" "$root/.tmp/go-tmp" "$root/.tmp/go-cache"
printf '*\n' > "$root/.tmp/.gitignore"
export TMPDIR="$root/.tmp"
export GOTMPDIR="$root/.tmp/go-tmp"
export GOCACHE="$root/.tmp/go-cache"
export GOMAXPROCS=2
{
  git -C "$root" rev-parse HEAD
  go version
  uname -srm
  printf 'duration per target: %s\n' "$duration"
} > "$output/source.txt"
cd "$root/cli"
while read -r package target; do
  go test "$package" -run '^$' -fuzz "^${target}$" -fuzztime "$duration" -parallel 2 2>&1 | tee "$output/$target.log"
done <<'TARGETS'
./internal/appserver FuzzReadFrame
./internal/appserver FuzzDecodeRequest
./internal/appserver FuzzEnvelopeSession
./internal/appserver/queries FuzzHistoryCursor
TARGETS
