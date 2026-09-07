#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${HUE_BUILD_DIR:-$PROJECT_DIR/build}"
APP_DIR="$BUILD_DIR/Hue.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/module-cache"

xcrun swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos26.0 \
    -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR"/Sources/*.swift -o "$APP_DIR/Contents/MacOS/Hue"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
xcrun swiftc -O -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR/Scripts/MakeIcon.swift" -o "$BUILD_DIR/make-icon"
"$BUILD_DIR/make-icon" "$BUILD_DIR/Hue.iconset"
iconutil -c icns "$BUILD_DIR/Hue.iconset" -o "$APP_DIR/Contents/Resources/Hue.icns"

SIGNING_IDENTITY="${HUE_SIGNING_IDENTITY:--}"
codesign --force --options runtime --entitlements "$PROJECT_DIR/Resources/Hue.entitlements" \
    --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Application construite : $APP_DIR"
