#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
BUILD_DIR="${HUE_BUILD_DIR:-$PROJECT_DIR/build}"
APP_DIR="$BUILD_DIR/Hue.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/tool-module-cache"

for BUILD_ARCH in arm64 x86_64; do
    mkdir -p "$BUILD_DIR/slices/$BUILD_ARCH" "$BUILD_DIR/module-cache/$BUILD_ARCH"
    xcrun swiftc -O -parse-as-library -swift-version 5 -target "$BUILD_ARCH-apple-macos13.0" \
        -module-cache-path "$BUILD_DIR/module-cache/$BUILD_ARCH" \
        "$PROJECT_DIR"/Sources/*.swift -o "$BUILD_DIR/slices/$BUILD_ARCH/Hue"
done
lipo -create "$BUILD_DIR/slices/arm64/Hue" "$BUILD_DIR/slices/x86_64/Hue" \
    -output "$APP_DIR/Contents/MacOS/Hue"
lipo "$APP_DIR/Contents/MacOS/Hue" -verify_arch arm64 x86_64
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$REPOSITORY_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE.txt"
# Convert the shared icon into macOS sizes using a build-time tool for the host.
xcrun swiftc -O -module-cache-path "$BUILD_DIR/tool-module-cache" \
    "$PROJECT_DIR/Scripts/MakeIcon.swift" -o "$BUILD_DIR/make-icon"
"$BUILD_DIR/make-icon" "$BUILD_DIR/Hue.iconset" "$REPOSITORY_DIR/assets/hue.png"
iconutil -c icns "$BUILD_DIR/Hue.iconset" -o "$APP_DIR/Contents/Resources/Hue.icns"
for localization in "$PROJECT_DIR"/Resources/*.lproj; do
    ditto "$localization" "$APP_DIR/Contents/Resources/$(basename "$localization")"
done

SIGNING_IDENTITY="${HUE_SIGNING_IDENTITY:--}"
# Sign only after both architectures and all resources have been assembled.
codesign --force --options runtime --entitlements "$PROJECT_DIR/Resources/Hue.entitlements" \
    --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built universal app (arm64 + x86_64, macOS 13+): $APP_DIR"
