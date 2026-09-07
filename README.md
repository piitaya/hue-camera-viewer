# Hue Camera Viewer

A minimal viewer for HUE and USB document cameras: live preview, 90° rotation,
and PNG capture to the Desktop, with a movable, collapsible dock.

**English and French · Native apps for macOS and Windows**

| App | Requirements | Development |
| --- | --- | --- |
| macOS | macOS 13+, Intel or Apple Silicon | [macOS guide](apps/macos/README.md) |
| Windows preview | Windows 10 (2004)+ x64; Windows 11 x64 or ARM64 | [Windows guide](apps/windows/README.md) |

## Install

On macOS, open the DMG and drag Hue to Applications.
On Windows, run `Hue-Setup.exe`, then open Hue from the Start menu.
Connect your camera and allow camera access when prompted.

## Repository

- `apps/macos`: Swift app and DMG packaging.
- `apps/windows`: C# app, tests, and Windows packaging.
- `assets`: shared app icons.

Pull requests and pushes to `main` build and test the affected apps, skipping documentation-only
changes. Manual runs build both apps. Preview installers are available in the workflow's
artifacts for three days.
These CI builds are for testing; the macOS preview is not notarized.
