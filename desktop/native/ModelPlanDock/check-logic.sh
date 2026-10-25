#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
logic_root=$(cd "$(dirname "$0")" && pwd)
logic_build=${1:?Pass your owned scratch directory}
mkdir -p "$logic_build/module-cache"
df -h "$HOME"
du -sh "$logic_build"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export CLANG_MODULE_CACHE_PATH="$logic_build/module-cache"
logic_arch=${2:-$(uname -m)}
case "$logic_arch" in arm64|x86_64) ;; *) exit 2 ;; esac
xcrun swiftc -O -target "$logic_arch-apple-macosx14.0" -module-cache-path "$logic_build/module-cache" \
  "$logic_root"/Logic/*.swift "$logic_root/LogicChecks/main.swift" -o "$logic_build/DockLogicChecks-$logic_arch"
if [ "$logic_arch" = "$(uname -m)" ]; then
  if [ -n "${3:-}" ]; then
    "$logic_build/DockLogicChecks-$logic_arch" --receipt "$3"
  else
    "$logic_build/DockLogicChecks-$logic_arch"
  fi
else
  echo "Compiled $logic_arch only; runtime untested"
fi
