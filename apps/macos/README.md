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

The dock groups the camera, rotation and zoom on one side of a divider, and the
capture and snowflake buttons on the other. The magnifier opens the zoom slider; the zoom
also follows the scroll wheel or a trackpad pinch and only magnifies the preview.
Freezing holds the current image while the camera keeps running: rotation, zoom and
capture still apply to the held image, and the pill in the top-left corner resumes the live view.

| Action | Shortcut |
| --- | --- |
| Capture to Desktop | ⌘S |
| Rotate left / right | ⌘← / ⌘→ |
| Zoom in / out / 100 % | ⌘+ / ⌘− / ⌘0 |
| Freeze or resume the image | ⌘F |
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

The DMG is written to `build/Hue-Camera-Viewer-macOS.dmg`. Set `HUE_SIGNING_IDENTITY` to a Developer ID identity to sign the app
with a secure timestamp; without it the app is signed ad hoc and cannot be notarized.

## Release signing

The [release workflow](../../.github/workflows/release.yml) signs the app and the DMG with a
Developer ID certificate, notarizes the DMG and staples the ticket. It needs these repository
secrets, all from an Apple Developer Program account:

| Secret | Content |
| --- | --- |
| `APPLE_CERTIFICATE_P12` | The "Developer ID Application" certificate with its private key, exported from Keychain Access as a `.p12`, encoded with `base64 -i certificate.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | The password chosen when exporting the `.p12` |
| `APPLE_NOTARY_KEY` | The content of the App Store Connect API key file (`AuthKey_XXXXXXXXXX.p8`), created under Users and Access → Integrations → Team Keys with the Developer role |
| `APPLE_NOTARY_KEY_ID` | The Key ID shown next to that key |
| `APPLE_NOTARY_ISSUER_ID` | The Issuer ID shown at the top of the same page |

The workflow imports the certificate into a temporary keychain that it deletes at the end, and
the Team ID is read from the certificate itself.
