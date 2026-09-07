# Hue

A native macOS viewer in French for HUE/USB cameras: live preview, 90° rotations,
and PNG capture to the Desktop.
The image fills the content of a standard macOS window. A collapsible dock contains
the controls and camera picker. It uses Liquid Glass on macOS 26+ and a classic
translucent material on macOS 13 through 15. Drag it to any of the four edges to
preview its position and animate it into place on release.
It is vertical at the sides and horizontal at the top or bottom. Use the standard
macOS green window button to enter full screen.
The app's commands do not define any custom keyboard shortcuts.

## Project status

This version targets **Intel and Apple Silicon Macs running macOS 13 or later**.
The same bundle contains both architectures, `x86_64` and `arm64`.
Automated tests use synthetic images. Testing on macOS 13, on a physical Intel Mac,
with a real HUE camera, and with the initial camera/Desktop permission prompts
remains outstanding. Running under Rosetta does not replace these hardware checks.

## Build

An Intel or Apple Silicon Mac with an Xcode version that provides the macOS 26+ SDK.
The recent SDK allows Liquid Glass to compile alongside a fallback for older systems;
the resulting app declares macOS 13 as its minimum version.
Building the app requires no third-party libraries or network access.

```sh
bash Scripts/build.sh
open build/Hue.app
```

The script compiles separately for `arm64-apple-macos13.0` and
`x86_64-apple-macos13.0`, combines the executables with `lipo`, verifies both
architectures, and then signs the complete bundle. The icon generation tool is
compiled only for the build machine.
The resulting bundle is signed locally (ad hoc), with Hardened Runtime and the
camera entitlement. It does not use App Sandbox; macOS controls camera and Desktop
access through its privacy permissions.
To sign with an existing Developer ID certificate, set
`HUE_SIGNING_IDENTITY="Developer ID Application: …"` before building.
Notarization requires your own Apple Developer credentials.

## Verify

```sh
bash Scripts/test.sh
open -na build/Hue.app --args --demo
```

The `--demo` mode is for testing and development. It displays a simple, fixed test
pattern with no text, without activating the camera.
Demo captures are saved in the temporary Hue-Demo folder, or in the directory passed
after `--capture-directory`, which is created if necessary.
This mode does not change the user's preferences.
The pipeline tests check the pixels for all four rotations, dimensions, shifted
origins, and PNG encoding without filename collisions.
The dock tests cover all four edges, snapping, and small windows.
A capture test checks that a request made immediately after a rotation waits for the
new image and saves exactly one PNG with the correct pixels and dimensions.
These tests use synthetic images; a real HUE camera still needs to be tested.
Core Image requires access to graphics rendering; a command sandbox may block its
execution even when the app works in a normal macOS session.

The tests target macOS 13 and run on the host process's architecture by default.
On Apple Silicon with Rosetta already installed, the following command also checks
the Intel executables; the script does not install Rosetta:

```sh
HUE_TEST_ARCH=x86_64 bash Scripts/test.sh
```

To inspect only the classic dock appearance on macOS 26+, run:

```sh
open -na build/Hue.app --args --demo --classic-dock
```

The `--classic-dock` option also works without `--demo`. It only forces the classic
material; it does not simulate macOS 13 or its APIs. Without `--demo`, the app uses
the real camera and saves captures to the Desktop.

## Create the DMG

Packaging uses Python 3.10+ and `dmgbuild`. Install its dependencies once in an
isolated environment (this installation requires a network connection):

```sh
python3 -m venv .venv-dmg
.venv-dmg/bin/python -m pip install -r Scripts/requirements-dmg.txt
bash Scripts/package.sh
```

The DMG opens an illustrated installation window: Hue on the left, an arrow, and
the Applications folder on the right. Only the app and the Applications link are
visible. The guide is provided separately.
The Retina background and Finder icon positions are generated without automating Finder.
To reuse an installed tool, set `HUE_DMGBUILD` to its path.
To rebuild only the DMG for an app that has already been built and signed,
set `HUE_APP_PATH` to that bundle's path.
The default output is `build/Hue-1.0-Universal.dmg`. Before and after creating the
DMG, the script verifies that both architectures are present, that each targets
macOS 13, and that the bundle's minimum version and signature are correct. It thus
rejects an older Apple Silicon bundle targeting macOS 26 passed through `HUE_APP_PATH`.

## Project structure

- Sources/CameraEngine.swift: permissions, USB discovery, video session, reconnection.
- Sources/ImagePipeline.swift: shared preview/capture transformation, atomic PNG writes.
- Sources/AppModel.swift: preferences and background capture saving.
- Sources/ContentView.swift: SwiftUI interface.
- Sources/DockGeometry.swift: dock placement and snapping.
- Sources/HueApp.swift: macOS window and menus.

The exported image uses the same rendered image as the preview. Letterboxing and
interface elements are not saved. No microphone is opened.
