#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${HUE_BUILD_DIR:-$PROJECT_DIR/build}"
DESTINATION="${1:-$BUILD_DIR/Hue-1.0-AppleSilicon.dmg}"
DMGBUILD="${HUE_DMGBUILD:-$PROJECT_DIR/.venv-dmg/bin/dmgbuild}"
if [[ ! -x "$DMGBUILD" ]]; then
    echo "Installez les outils de packaging indiqués dans README.md (section Créer le DMG)." >&2
    exit 1
fi
if [[ -z "${HUE_APP_PATH:-}" ]]; then
    "$PROJECT_DIR/Scripts/build.sh"
fi
APP_DIR="${HUE_APP_PATH:-$BUILD_DIR/Hue.app}"
codesign --verify --deep --strict "$APP_DIR"
mkdir -p "$BUILD_DIR/module-cache" "$(dirname "$DESTINATION")"
xcrun swiftc -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR/Scripts/MakeDMGBackground.swift" -o "$BUILD_DIR/make-dmg-background"
"$BUILD_DIR/make-dmg-background" "$BUILD_DIR/background.png" 1
"$BUILD_DIR/make-dmg-background" "$BUILD_DIR/background@2x.png" 2
tiffutil -cathidpicheck "$BUILD_DIR/background.png" "$BUILD_DIR/background@2x.png" \
    -out "$BUILD_DIR/background.tiff"

# Build to a temporary destination so a failed package cannot replace the previous DMG.
STAGING_DIR="$(mktemp -d "$BUILD_DIR/dmg.XXXXXX")"
MOUNT_DIR="$STAGING_DIR/mounted"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" == 1 ]]; then
        hdiutil detach "$MOUNT_DIR" >/dev/null || return
    fi
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT
"$DMGBUILD" -s "$PROJECT_DIR/Scripts/dmg-settings.py" \
    -D "app=$APP_DIR" -D "background=$BUILD_DIR/background.tiff" \
    "Hue" "$STAGING_DIR/Hue.dmg"
hdiutil verify "$STAGING_DIR/Hue.dmg"
mkdir "$MOUNT_DIR"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$STAGING_DIR/Hue.dmg" >/dev/null
MOUNTED=1
codesign --verify --deep --strict "$MOUNT_DIR/Hue.app"
[[ "$(readlink "$MOUNT_DIR/Applications")" == /Applications ]]
[[ ! -e "$MOUNT_DIR/LISEZ-MOI.txt" ]]
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNTED=0
mv -f "$STAGING_DIR/Hue.dmg" "$DESTINATION"
echo "Image disque créée : $DESTINATION"
