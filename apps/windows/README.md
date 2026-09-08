# Hue Camera Viewer for Windows

> Independent project, not affiliated with HUE. This app is compatible with HUE cameras.

A minimal camera viewer for Windows 10 (2004)+ and Windows 11, in English and French.

Open the `Hue-Camera-Viewer-<version>-Windows.exe` installer, then launch Hue from the Start menu and choose your camera.
The installer automatically selects the native Intel/AMD or ARM version.
Captures are saved as PNG files on your Desktop.
The arrows rotate the image and the magnifier opens the zoom slider; the zoom also
follows the mouse wheel or a touchpad pinch and only magnifies the preview.
The snowflake button freezes the image while the camera keeps running; rotation, zoom and capture
still apply to the held image, and the pill in the top-left corner resumes the live view.
Shortcuts: Ctrl+S captures, Ctrl+← / Ctrl+→ rotate, Ctrl + / Ctrl − / Ctrl 0 zoom, Ctrl+F freezes, Ctrl+T hides the controls.
You can uninstall Hue from Windows Settings → Apps.

See the [camera compatibility list](../../README.md#cameras).

## Development

Run these commands from `apps/windows` on Windows with the .NET 8 SDK
and the Windows App SDK build tools installed.

```powershell
./Scripts/build.ps1
./build/win-x64/Hue.exe --demo
```

Use `-Runtime win-arm64` to build for ARM64.
The output folder includes the app's runtime dependencies.

Run the core tests on any platform with:

```sh
dotnet test Hue.Core.Tests
```

GitHub Actions builds one installer for both architectures.
Download it from the workflow's artifacts to try the preview on a PC; releases attach it as
`Hue-Camera-Viewer-<version>-Windows.exe`, named after the release tag.
To package locally, build both runtimes and install Inno Setup 6.3+, then run:

```powershell
./Scripts/package.ps1 -X64AppDirectory build/win-x64 -Arm64AppDirectory build/win-arm64
```
