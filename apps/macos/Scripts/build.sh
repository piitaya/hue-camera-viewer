#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
BUILD_DIR="${GIRAFON_BUILD_DIR:-$PROJECT_DIR/build}"
APP_DIR="$BUILD_DIR/Girafon.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/tool-module-cache"

for BUILD_ARCH in arm64 x86_64; do
    mkdir -p "$BUILD_DIR/slices/$BUILD_ARCH" "$BUILD_DIR/module-cache/$BUILD_ARCH"
    xcrun swiftc -O -parse-as-library -swift-version 5 -target "$BUILD_ARCH-apple-macos13.0" \
        -module-cache-path "$BUILD_DIR/module-cache/$BUILD_ARCH" \
        "$PROJECT_DIR"/Sources/*.swift -o "$BUILD_DIR/slices/$BUILD_ARCH/Girafon"
done
lipo -create "$BUILD_DIR/slices/arm64/Girafon" "$BUILD_DIR/slices/x86_64/Girafon" \
    -output "$APP_DIR/Contents/MacOS/Girafon"
lipo "$APP_DIR/Contents/MacOS/Girafon" -verify_arch arm64 x86_64
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$REPOSITORY_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE.txt"
# Convert the shared icon into macOS sizes using a build-time tool for the host.
xcrun swiftc -O -module-cache-path "$BUILD_DIR/tool-module-cache" \
    "$PROJECT_DIR/Scripts/MakeIcon.swift" -o "$BUILD_DIR/make-icon"
"$BUILD_DIR/make-icon" "$BUILD_DIR/Girafon.iconset" "$REPOSITORY_DIR/assets/girafon.png"
iconutil -c icns "$BUILD_DIR/Girafon.iconset" -o "$APP_DIR/Contents/Resources/Girafon.icns"

# Native macOS 26 appearances; the classic ICNS remains available on macOS 13–15.
ICON_SOURCE="$BUILD_DIR/Girafon.icon"
ICON_COMPILED="$BUILD_DIR/icon-assets"
mkdir -p "$ICON_SOURCE/Assets" "$ICON_COMPILED"
cp "$PROJECT_DIR/Resources/Girafon.icon/icon.json" "$ICON_SOURCE/icon.json"
cp "$REPOSITORY_DIR/assets/girafon.svg" "$ICON_SOURCE/Assets/girafon.svg"
xcrun actool "$ICON_SOURCE" --compile "$ICON_COMPILED" --platform macosx \
    --minimum-deployment-target 13.0 --app-icon Girafon \
    --output-partial-info-plist "$ICON_COMPILED/Info.plist" --output-format human-readable-text
cp "$ICON_COMPILED/Assets.car" "$APP_DIR/Contents/Resources/Assets.car"
for localization in "$PROJECT_DIR"/Resources/*.lproj; do
    ditto "$localization" "$APP_DIR/Contents/Resources/$(basename "$localization")"
done

SIGNING_IDENTITY="${GIRAFON_SIGNING_IDENTITY:--}"
# Sign only after both architectures and all resources have been assembled.
codesign --force --options runtime --entitlements "$PROJECT_DIR/Resources/Girafon.entitlements" \
    --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built universal app (arm64 + x86_64, macOS 13+): $APP_DIR"
