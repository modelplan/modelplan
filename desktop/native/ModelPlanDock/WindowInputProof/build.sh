#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
proof_root=$(cd "$(dirname "$0")" && pwd)
proof_build=${1:?Pass an owned lane build directory}
mkdir -p "$proof_build/module-cache"
df -h "$HOME"
du -sh "$proof_build"
export CLANG_MODULE_CACHE_PATH="$proof_build/module-cache"
# Select only for this invocation; never change the machine's xcode-select setting.
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
xcodebuild -version
xcrun swiftc --version
for proof_arch in arm64 x86_64; do
  xcrun swiftc -O -target "$proof_arch-apple-macosx14.0" -module-cache-path "$proof_build/module-cache" \
    "$proof_root/Geometry.swift" "$proof_root/main.swift" -o "$proof_build/window-proof-$proof_arch"
done
for proof_product in ModelPlanWindowProbe ModelPlanInputReceiver; do
  proof_app="$proof_build/$proof_product.app"
  mkdir -p "$proof_app/Contents/MacOS"
  xcrun lipo -create "$proof_build/window-proof-arm64" "$proof_build/window-proof-x86_64" -output "$proof_app/Contents/MacOS/$proof_product"
  cat > "$proof_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleName</key><string>$proof_product</string><key>CFBundleIdentifier</key><string>org.modelplan.proof.$proof_product</string>
<key>CFBundleExecutable</key><string>$proof_product</string><key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string><key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
  codesign --force --sign - --options runtime "$proof_app"
  codesign --verify --deep --strict "$proof_app"
done
