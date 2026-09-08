#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
EXPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hue-icon.XXXXXX")"
trap 'rm -rf "$EXPORT_DIR"' EXIT

ICON_RENDERER="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$ICON_RENDERER" ]]; then
    echo "Icon Composer from Xcode 26 or newer is required to export the icon." >&2
    exit 1
fi

# Keep the shared SVG as the only copy of the artwork.
mkdir -p "$EXPORT_DIR/Hue.icon/Assets"
cp "$PROJECT_DIR/Resources/Hue.icon/icon.json" "$EXPORT_DIR/Hue.icon/icon.json"
cp "$REPOSITORY_DIR/assets/hue.svg" "$EXPORT_DIR/Hue.icon/Assets/hue.svg"
"$ICON_RENDERER" "$EXPORT_DIR/Hue.icon" --export-image \
    --output-file "$REPOSITORY_DIR/assets/hue.png" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1

mkdir -p "$EXPORT_DIR/module-cache"
xcrun swiftc -O -module-cache-path "$EXPORT_DIR/module-cache" \
    "$PROJECT_DIR/Scripts/MakeIcon.swift" -o "$EXPORT_DIR/make-icon"
"$EXPORT_DIR/make-icon" "$EXPORT_DIR/Hue.iconset" "$REPOSITORY_DIR/assets/hue.png" \
    "$REPOSITORY_DIR/assets/Hue.ico"
echo "Exported shared icons: $REPOSITORY_DIR/assets/hue.png and Hue.ico"
