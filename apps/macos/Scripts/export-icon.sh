#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
EXPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/girafon-icon.XXXXXX")"
trap 'rm -rf "$EXPORT_DIR"' EXIT

ICON_RENDERER="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$ICON_RENDERER" ]]; then
    echo "Icon Composer from Xcode 26 or newer is required to export the icon." >&2
    exit 1
fi

# Keep the shared SVG as the only copy of the artwork.
mkdir -p "$EXPORT_DIR/Girafon.icon/Assets"
cp "$PROJECT_DIR/Resources/Girafon.icon/icon.json" "$EXPORT_DIR/Girafon.icon/icon.json"
cp "$REPOSITORY_DIR/assets/girafon.svg" "$EXPORT_DIR/Girafon.icon/Assets/girafon.svg"
"$ICON_RENDERER" "$EXPORT_DIR/Girafon.icon" --export-image \
    --output-file "$REPOSITORY_DIR/assets/girafon.png" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1

mkdir -p "$EXPORT_DIR/module-cache"
xcrun swiftc -O -module-cache-path "$EXPORT_DIR/module-cache" \
    "$PROJECT_DIR/Scripts/MakeIcon.swift" -o "$EXPORT_DIR/make-icon"
"$EXPORT_DIR/make-icon" "$EXPORT_DIR/Girafon.iconset" "$REPOSITORY_DIR/assets/girafon.png" \
    "$REPOSITORY_DIR/assets/Girafon.ico"
echo "Exported shared icons: $REPOSITORY_DIR/assets/girafon.png and Girafon.ico"
