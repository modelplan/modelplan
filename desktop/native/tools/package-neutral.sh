#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
native_root="$repo_root/desktop/native"
app_package="$native_root/ModelPlanAppIntegration"
archive_dir=${1:?Pass directory with pinned official CLI archives and checksums.txt}
output_dir=${2:?Pass a new local output directory}
identity_mode=release
configuration=release
case "${3:-}" in
    '') ;;
    --unverified) identity_mode=unverified ;;
    --e2e-journey) identity_mode=unverified; configuration=debug ;;
    *) echo 'Optional third argument must be --unverified or --e2e-journey (CI only)' >&2; exit 1 ;;
esac
if [ "$#" -gt 3 ]; then echo 'Too many packaging arguments' >&2; exit 1; fi
if [ -e "$output_dir" ]; then echo 'Output directory already exists; refusing overwrite' >&2; exit 1; fi
public_source=$(git -C "$repo_root" rev-parse HEAD)
if [ -n "$(git -C "$repo_root" status --porcelain)" ]; then echo "Source tree must be clean" >&2; exit 1; fi
mkdir -p "$output_dir"
archive_dir=$(cd "$archive_dir" && pwd)
output_dir=$(cd "$output_dir" && pwd)
export CLANG_MODULE_CACHE_PATH="$output_dir/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$output_dir/module-cache"
for architecture in arm64 x86_64; do
    if [ "$configuration" = debug ]; then
        swift build --package-path "$app_package" --scratch-path "$output_dir/build-$architecture" \
            --cache-path "$output_dir/spm-cache" --disable-sandbox --configuration debug \
            --triple "$architecture-apple-macosx14.0" --jobs 2 --product ModelPlanCommunityApp \
            -Xswiftc -DMODELPLAN_E2E_JOURNEY
    else
    swift build --package-path "$app_package" --scratch-path "$output_dir/build-$architecture" \
        --cache-path "$output_dir/spm-cache" --disable-sandbox --configuration release \
        --triple "$architecture-apple-macosx14.0" --jobs 2 --product ModelPlanCommunityApp
    fi
    archive_arch=$architecture
    if [ "$architecture" = x86_64 ]; then archive_arch=amd64; fi
    archive="modelplan_darwin_$archive_arch.tar.gz"
    expected=$(awk -v archive="$archive" '$2 == archive {print $1}' "$archive_dir/checksums.txt")
    actual=$(shasum -a 256 "$archive_dir/$archive" | awk '{print $1}')
    if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then echo 'Official CLI checksum mismatch' >&2; exit 1; fi
    mkdir "$output_dir/cli-$architecture"
    tar -xzf "$archive_dir/$archive" -C "$output_dir/cli-$architecture"
done
app="$output_dir/ModelPlan Community.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
# The native factory uses the unchanged MIT tray template from this SwiftPM resource bundle.
cp -R "$output_dir/build-arm64/arm64-apple-macosx/$configuration/ModelPlanAppIntegration_ModelPlanAppIntegration.bundle" "$app/Contents/Resources/"
xcrun lipo -create "$output_dir/build-arm64/arm64-apple-macosx/$configuration/ModelPlanCommunityApp" \
    "$output_dir/build-x86_64/x86_64-apple-macosx/$configuration/ModelPlanCommunityApp" -output "$app/Contents/MacOS/ModelPlanCommunity"
xcrun lipo -create "$output_dir/cli-arm64/modelplan_darwin_arm64/modelplan" "$output_dir/cli-x86_64/modelplan_darwin_amd64/modelplan" -output "$app/Contents/Helpers/modelplan"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>ModelPlan Community</string>
<key>CFBundleDisplayName</key><string>ModelPlan Community</string>
<key>CFBundleIdentifier</key><string>org.modelplan.community.swift.scaffold</string>
<key>CFBundleExecutable</key><string>ModelPlanCommunity</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>MIT community software. Intel untested; 3D may stutter.</string>
</dict></plist>
PLIST
cp "$repo_root/LICENSE" "$app/Contents/Resources/LICENSE.txt"
cp "$output_dir/cli-arm64/modelplan_darwin_arm64/THIRD-PARTY-NOTICES.md" "$app/Contents/Resources/CLI-THIRD-PARTY-NOTICES.md"
codesign --force --sign - --options runtime "$app/Contents/Helpers/modelplan"
shasum -a 256 "$app/Contents/Helpers/modelplan" | awk '{print $1}' > "$app/Contents/Resources/modelplan.sha256"
python3 "$native_root/tools/write-consent-bundle-identity.py" --mode "$identity_mode" --app "$app" --public-source "$public_source" \
    --arm64-input "$output_dir/cli-arm64/modelplan_darwin_arm64/modelplan" \
    --x86-64-input "$output_dir/cli-x86_64/modelplan_darwin_amd64/modelplan"
codesign --force --sign - --options runtime "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
