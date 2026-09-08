#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${GIRAFON_BUILD_DIR:-$PROJECT_DIR/build}"
TEST_ARCH="${GIRAFON_TEST_ARCH:-$(uname -m)}"
case "$TEST_ARCH" in
    arm64|x86_64) ;;
    *) echo "Unsupported test architecture: $TEST_ARCH" >&2; exit 1 ;;
esac
if ! /usr/bin/arch "-$TEST_ARCH" /usr/bin/true >/dev/null 2>&1; then
    echo "Cannot run $TEST_ARCH on this Mac. Intel tests on Apple Silicon require Rosetta to be installed." >&2
    exit 1
fi
MINIMUM_MACOS="$(plutil -extract LSMinimumSystemVersion raw -o - "$PROJECT_DIR/Resources/Info.plist")"
MODULE_CACHE="$BUILD_DIR/module-cache/$TEST_ARCH"
mkdir -p "$MODULE_CACHE"

# Run localization checks from a real, isolated bundle so Foundation selects the
# same resources as the app. These tests never launch an app or access a camera.
plutil -lint "$PROJECT_DIR/Resources/Info.plist" "$PROJECT_DIR"/Resources/*.lproj/*.strings
LOCALIZATION_APP="$BUILD_DIR/tests/$TEST_ARCH/GirafonLocalizationTests.app"
mkdir -p "$LOCALIZATION_APP/Contents/MacOS" "$LOCALIZATION_APP/Contents/Resources"
cp "$PROJECT_DIR/Resources/Info.plist" "$LOCALIZATION_APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string GirafonLocalizationTests "$LOCALIZATION_APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string local.girafon.localization-tests "$LOCALIZATION_APP/Contents/Info.plist"
for localization in "$PROJECT_DIR"/Resources/*.lproj; do
    ditto "$localization" "$LOCALIZATION_APP/Contents/Resources/$(basename "$localization")"
done
xcrun swiftc -swift-version 5 -target "$TEST_ARCH-apple-macos$MINIMUM_MACOS" \
    -module-cache-path "$MODULE_CACHE" \
    "$PROJECT_DIR/Sources/ImagePipeline.swift" "$PROJECT_DIR/Tests/LocalizationTests.swift" \
    -o "$LOCALIZATION_APP/Contents/MacOS/GirafonLocalizationTests"
for language in en fr; do
    /usr/bin/arch "-$TEST_ARCH" "$LOCALIZATION_APP/Contents/MacOS/GirafonLocalizationTests" "$PROJECT_DIR/Resources" "$language" \
        -AppleLanguages "($language)"
done

# An unsupported language must load the English development localization.
/usr/bin/arch "-$TEST_ARCH" "$LOCALIZATION_APP/Contents/MacOS/GirafonLocalizationTests" "$PROJECT_DIR/Resources" en \
    -AppleLanguages '(de)'
echo "PASS: unsupported language (de) falls back to English."
