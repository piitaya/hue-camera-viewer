# Hue Camera Viewer for macOS

A minimal macOS app for HUE and USB document cameras: live preview, 90° rotation,
and PNG capture to the Desktop, with a movable, collapsible dock.

**macOS 13+ · Intel and Apple Silicon · English and French**

## Install

Open the DMG, drag Hue to Applications, and launch it.
Allow camera access when prompted.

## Development

Requires Xcode with the macOS 26 SDK or later. Run these commands from `apps/macos`.

```sh
bash Scripts/build.sh
open build/Hue.app
```

Run tests with `bash Scripts/test.sh`.
Use `open -na build/Hue.app --args --demo` to develop without a camera.

## Create the DMG

Requires Python 3.10 or later.

```sh
python3 -m venv .venv-dmg
.venv-dmg/bin/python -m pip install -r Scripts/requirements-dmg.txt
bash Scripts/package.sh
```
