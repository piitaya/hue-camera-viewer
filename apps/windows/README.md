# Hue for Windows

A minimal camera viewer for Windows 10 (2004)+ and Windows 11, in English and French.

Open `Hue-Setup-x64.exe` (Intel/AMD) or `Hue-Setup-arm64.exe` (Windows 11 ARM),
then launch Hue from the Start menu and choose your camera.
Captures are saved as PNG files on your Desktop.
You can uninstall Hue from Windows Settings → Apps.

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

GitHub Actions builds installers for both architectures.
Download them from the workflow's artifacts to try the preview on a PC.
To package a local build, install Inno Setup 6.3+ and run `./Scripts/package.ps1`.
