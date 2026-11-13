#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
native_root=$(cd "$(dirname "$0")/.." && pwd)
output_dir=${1:?Pass a new output directory}
probe_product=${2:-ModelPlanPrimitiveProbe}
case "$probe_product" in ModelPlanPrimitiveProbe|ModelPlanFieldProbe|ModelPlanWindowProbe|ModelPlanInputReceiver) ;; *) exit 2;; esac
if [ -e "$output_dir" ]; then echo 'Refusing to overwrite an existing output' >&2; exit 1; fi
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
export CLANG_MODULE_CACHE_PATH="$output_dir/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$output_dir/module-cache"
for probe_arch in arm64 x86_64; do
    swift build --package-path "$native_root" --scratch-path "$output_dir/build-$probe_arch" \
        --cache-path "$output_dir/spm-cache" --disable-sandbox --configuration release \
        --triple "$probe_arch-apple-macosx14.0" --jobs 2 --product "$probe_product"
done
app="$output_dir/$probe_product.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun lipo -create "$output_dir/build-arm64/arm64-apple-macosx/release/$probe_product" \
    "$output_dir/build-x86_64/x86_64-apple-macosx/release/$probe_product" -output "$app/Contents/MacOS/$probe_product"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$probe_product</string>
<key>CFBundleIdentifier</key><string>org.modelplan.native.$probe_product</string>
<key>CFBundleExecutable</key><string>$probe_product</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp "$native_root/../../LICENSE" "$app/Contents/Resources/LICENSE.txt"
codesign --force --sign - --options runtime "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
