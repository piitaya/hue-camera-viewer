# Hue Camera Viewer for macOS

> Independent project, not affiliated with HUE. This app is compatible with HUE cameras.

A minimal macOS app for HUE and USB document cameras: live preview, rotation and zoom,
and PNG captures saved to the Desktop, with a movable, collapsible dock.

**macOS 13+ · Intel and Apple Silicon · English and French**

## Install

Open the DMG, drag Hue to Applications, and launch it.
Allow camera access when prompted.

See the [camera compatibility list](../../README.md#cameras).

## Development

Requires Xcode with the macOS 26 SDK or later. Run these commands from `apps/macos`.

```sh
bash Scripts/build.sh
open build/Hue.app
```

Run tests with `bash Scripts/test.sh`.
Use `open -na build/Hue.app --args --demo` to develop without a camera.

## Controls

The dock groups the camera, rotation and zoom on one side of a divider and the
capture button on the other. The magnifier opens the zoom slider; the zoom also
follows the scroll wheel or a trackpad pinch and only magnifies the preview.

| Action | Shortcut |
| --- | --- |
| Capture to Desktop | ⌘S |
| Rotate left / right | ⌘← / ⌘→ |
| Zoom in / out / 100 % | ⌘+ / ⌘− / ⌘0 |
| Hide or show controls | ⌥⌘T |

After editing `assets/hue.svg` or the Icon Composer settings, regenerate the shared
PNG and Windows ICO with `bash Scripts/export-icon.sh`.

## Create the DMG

Requires Python 3.10 or later.

```sh
python3 -m venv .venv-dmg
.venv-dmg/bin/python -m pip install -r Scripts/requirements-dmg.txt
bash Scripts/package.sh
```
